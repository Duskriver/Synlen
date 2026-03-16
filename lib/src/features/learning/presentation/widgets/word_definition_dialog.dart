// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:synlen/src/features/learning/data/repositories/word_repository.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';

import 'package:synlen/src/core/utils/wav_header_util.dart';

/// 一个简单的流式音频源，用于播放边下载边缓存的音频字节
class _StreamingAudioSource extends StreamAudioSource {
  final Stream<List<int>> byteStream;
  final AudioFormat format;
  final List<int> _buffer = [];
  final _controller = StreamController<List<int>>.broadcast();
  StreamSubscription<List<int>>? _subscription;
  bool _isFinished = false;

  _StreamingAudioSource(this.byteStream, this.format) {
    if (format == AudioFormat.pcm) {
      // 阿里云 PCM 为 24kHz, 16bit, Mono
      // 在流开始前添加 WAV 头部以便播放器识别
      _buffer.addAll(WavHeaderUtil.generateWavHeader(0, 24000, 1, 16));
    }
    _init();
  }

  void _init() async {
    _subscription = byteStream.listen(
      (chunk) {
        _buffer.addAll(chunk);
        if (!_controller.isClosed) {
          _controller.add(chunk);
        }
      },
      onDone: () {
        _isFinished = true;
        if (!_controller.isClosed) {
          _controller.close();
        }
      },
      onError: (e) {
        debugPrint('StreamingAudioSource error: $e');
        _isFinished = true;
        if (!_controller.isClosed) {
          _controller.addError(e);
          _controller.close();
        }
      },
      cancelOnError: true,
    );
  }

  void dispose() {
    _subscription?.cancel();
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  List<int> get bytes => _buffer;

  /// 获取原始 PCM 字节（去除流式占位的 WAV 头部）
  List<int> get pcmBytes {
    if (format == AudioFormat.pcm && _buffer.length >= 44) {
      return _buffer.sublist(44);
    }
    return _buffer;
  }

  bool get isFinished => _isFinished;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _buffer.length;

    return StreamAudioResponse(
      sourceLength: _isFinished ? _buffer.length : null,
      contentLength: _isFinished ? _buffer.length - start : null,
      offset: start,
      stream: _getStream(start),
      contentType: format == AudioFormat.mp3 ? 'audio/mpeg' : 'audio/wav',
    );
  }

  Stream<List<int>> _getStream(int start) async* {
    // 首先发送缓冲区中已有的、从 start 开始的数据
    if (start < _buffer.length) {
      yield _buffer.sublist(start);
    }

    // 然后发送后续到来的数据
    if (!_isFinished) {
      await for (final chunk in _controller.stream) {
        // 这里的 chunk 是新到来的，不需要 sublist
        yield chunk;
      }
    }
  }
}

class WordDefinitionDialog extends ConsumerStatefulWidget {
  final String word;
  final String context;
  final ScrollController? scrollController;

  const WordDefinitionDialog({
    super.key,
    required this.word,
    required this.context,
    this.scrollController,
  });

  @override
  ConsumerState<WordDefinitionDialog> createState() =>
      _WordDefinitionDialogState();
}

class _WordDefinitionDialogState extends ConsumerState<WordDefinitionDialog> {
  late AudioPlayer _audioPlayer;
  bool _isLoading = true;
  bool _isFetchingExplanation = false;
  bool _isFetchingAudio = false;
  String _explanation = '';
  String? _pronunciationUrl; // 本地路径或 null
  String? _explanationError;
  String? _audioError;
  _StreamingAudioSource? _streamingSource;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    // 显式释放关联的流资源和播放器
    _streamingSource?.dispose();
    // 立即释放播放器资源，防止 native 回调到已关闭的资源
    // 同时也解决了 MediaCodec 资源耗尽导致的报错 (required system resources: 6)
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (!mounted) return;

      // 设置音量
      try {
        await _audioPlayer.setVolume(1.0);
      } catch (e) {
        debugPrint('Error setting volume: $e');
      }

      final repository = ref.read(wordRepositoryProvider);

      final result = await repository.getWordInfo(widget.word, widget.context);
      if (!mounted) return;

      setState(() {
        _explanation = result.explanation ?? '';
        _pronunciationUrl = result.audioUrl;
        _isLoading = false;
        _isFetchingExplanation = !result.hasCachedExplanation;
        _isFetchingAudio = !result.hasCachedAudio;
        _explanationError = null;
        _audioError = null;
      });

      await _prepareLocalAudioSource();

      if (!result.hasCachedAudio) {
        unawaited(_fetchAndCacheAudio(repository));
      }

      if (result.hasCachedExplanation) {
        if (mounted) {
          setState(() {
            _isFetchingExplanation = false;
          });
        }
      } else {
        await _fetchExplanation(repository);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _explanationError = _formatError(e);
          _isLoading = false;
          _isFetchingExplanation = false;
          _isFetchingAudio = false;
        });
      }
    }
  }

  Future<void> _prepareLocalAudioSource() async {
    if (_pronunciationUrl == null || _isDisposed) {
      return;
    }

    final file = File(_pronunciationUrl!);
    if (await file.exists()) {
      await _audioPlayer.setFilePath(_pronunciationUrl!);
    }
  }

  Future<String?> _fetchAndCacheAudio(WordRepository repository) async {
    try {
      final audioResultStream = repository.getPronunciationStream(widget.word);

      await for (final result in audioResultStream) {
        if (_isDisposed) {
          return null;
        }

        _streamingSource?.dispose();
        _streamingSource = _StreamingAudioSource(result.stream, result.format);

        if (!_isDisposed) {
          await _audioPlayer.setAudioSource(_streamingSource!);
        }

        if (mounted) {
          setState(() {
            _audioError = null;
          });
        }

        while (!_isDisposed && !_streamingSource!.isFinished) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (_isDisposed) {
          return null;
        }

        List<int> bytesToSave = _streamingSource!.bytes;
        if (result.format == AudioFormat.pcm) {
          final pcmBytes = _streamingSource!.pcmBytes;
          final correctHeader = WavHeaderUtil.generateWavHeader(
            pcmBytes.length,
            24000,
            1,
            16,
          );
          bytesToSave = [...correctHeader, ...pcmBytes];
        }

        final filePath = await repository.saveAudioFile(
          widget.word,
          bytesToSave,
        );
        await repository.persistAudioPath(widget.word, filePath);

        if (mounted) {
          setState(() {
            _pronunciationUrl = filePath;
          });
        }
        return filePath;
      }

      throw StateError('音频服务没有返回可播放的音频');
    } catch (e) {
      if (mounted) {
        setState(() {
          _audioError = _formatError(e);
        });
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingAudio = false;
        });
      }
    }
  }

  Future<void> _fetchExplanation(WordRepository repository) async {
    try {
      final stream = repository.getWordExplanationStream(
        widget.word,
        widget.context,
      );

      String buffer = '';
      DateTime lastUpdateTime = DateTime.now();
      const updateInterval = Duration(milliseconds: 100);

      await for (final chunk in stream) {
        if (!mounted) break;
        buffer += chunk;

        final now = DateTime.now();
        if (now.difference(lastUpdateTime) >= updateInterval) {
          setState(() {
            _explanation += buffer;
            buffer = '';
            _explanationError = null;
          });
          lastUpdateTime = now;
        }
      }

      if (buffer.isNotEmpty && mounted) {
        setState(() {
          _explanation += buffer;
          _explanationError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _explanationError = _formatError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingExplanation = false;
        });
      }
    }
  }

  String _formatError(Object error) {
    final text = error.toString().trim();
    return text.isEmpty ? '请求失败，请稍后重试' : text;
  }

  Future<void> _playAudio() async {
    if (_isDisposed) return;
    try {
      // 如果正在播放，重置到开始位置
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
        await _audioPlayer.seek(Duration.zero);
      }

      // 检查源是否已设置，如果没有（例如流式加载尚未完成时用户点击），
      // 尝试在播放前设置一次。
      if (_audioPlayer.audioSource == null) {
        if (_pronunciationUrl != null) {
          final file = File(_pronunciationUrl!);
          if (await file.exists()) {
            await _audioPlayer.setFilePath(_pronunciationUrl!);
          }
        } else if (_streamingSource != null) {
          await _audioPlayer.setAudioSource(_streamingSource!);
        }
      }

      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.word,
                  style: Theme.of(context).textTheme.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isFetchingExplanation || _isFetchingAudio)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content
          Flexible(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final hasAudio =
        (_pronunciationUrl != null && _pronunciationUrl!.isNotEmpty) ||
        _streamingSource != null;
    final primaryError = _explanationError ?? _audioError;

    if (_isLoading && _explanation.isEmpty && !hasAudio) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (primaryError != null && _explanation.isEmpty && !hasAudio) {
      return Text('加载失败: $primaryError');
    }

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasAudio)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: _playAudio,
                    tooltip: '播放发音',
                  ),
                  const Text('播放发音'),
                ],
              ),
            ),
          if (_audioError != null && !hasAudio)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '音频暂不可用：$_audioError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_explanation.isNotEmpty)
            RepaintBoundary(
              child: MarkdownBody(
                data: _explanation,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          if (_explanationError != null && _explanation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '释义更新失败：$_explanationError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_isFetchingExplanation && _explanation.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('正在思考...'),
              ),
            ),
        ],
      ),
    );
  }
}

