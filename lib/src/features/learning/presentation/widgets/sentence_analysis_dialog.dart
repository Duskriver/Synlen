import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lumina/src/features/learning/domain/audio_stream_result.dart';
import 'package:lumina/src/features/learning/data/repositories/learning_repository_provider.dart';

import 'package:lumina/src/core/utils/wav_header_util.dart';

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
    if (start < _buffer.length) {
      yield _buffer.sublist(start);
    }

    if (!_isFinished) {
      await for (final chunk in _controller.stream) {
        yield chunk;
      }
    }
  }
}

class SentenceAnalysisDialog extends ConsumerStatefulWidget {
  final String sentence;
  final ScrollController? scrollController;

  const SentenceAnalysisDialog({
    super.key,
    required this.sentence,
    this.scrollController,
  });

  @override
  ConsumerState<SentenceAnalysisDialog> createState() =>
      _SentenceAnalysisDialogState();
}

class _SentenceAnalysisDialogState
    extends ConsumerState<SentenceAnalysisDialog> {
  late AudioPlayer _audioPlayer;
  bool _isLoading = true;
  bool _isStreaming = false;
  String _analysis = '';
  String? _audioUrl; // 本地路径或 null
  String? _error;
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

      final repository = ref.read(sentenceRepositoryProvider);

      // 1. 获取基础信息（主要检查缓存）
      final result = await repository.getSentenceInfo(widget.sentence);

      if (result.isFromCache) {
        if (mounted) {
          setState(() {
            _analysis = result.analysis ?? '';
            _audioUrl = result.audioUrl;
            _isLoading = false;
          });
          // 如果有缓存音频，立即设置源
          if (_audioUrl != null && !_isDisposed) {
            final file = File(_audioUrl!);
            if (await file.exists()) {
              await _audioPlayer.setFilePath(_audioUrl!);
            }
          }
        }
        return;
      }

      // 2. 无缓存：同时启动音频和 AI
      if (mounted) {
        setState(() {
          _audioUrl = result.audioUrl; // 如果本地已有音频，直接设置
          _isLoading = false;
          _isStreaming = true;
        });
      }

      final audioCompleter = Completer<String?>();

      // 如果已有音频，直接完成 Completer，不再下载
      if (result.audioUrl != null) {
        audioCompleter.complete(result.audioUrl);
      } else {
        // 只有在没有音频时，才并行启动音频获取
        Future.microtask(() async {
          try {
            if (!mounted) {
              audioCompleter.complete(null);
              return;
            }
            final audioResultStream = repository.getPronunciationStream(
              widget.sentence,
            );

            await for (final result in audioResultStream) {
              if (_isDisposed) break;

              _streamingSource = _StreamingAudioSource(
                result.stream,
                result.format,
              );

              if (!_isDisposed) {
                await _audioPlayer.setAudioSource(_streamingSource!);
              }

              while (mounted && !_streamingSource!.isFinished) {
                await Future.delayed(const Duration(milliseconds: 100));
              }

              if (!mounted) {
                audioCompleter.complete(null);
                return;
              }

              final filePath = await repository.saveAudioFile(
                widget.sentence,
                _streamingSource!.bytes,
              );
              audioCompleter.complete(filePath);

              if (mounted) {
                setState(() {
                  _audioUrl = filePath;
                });
              }
              break;
            }
          } catch (e) {
            debugPrint('Sentence audio stream error: $e');
            if (!audioCompleter.isCompleted) {
              audioCompleter.complete(null);
            }
          }
        });
      }

      // 并行启动 AI 分析流
      final stream = repository.getSentenceAnalysisStream(
        widget.sentence,
        audioFilePathFuture: audioCompleter.future,
      );

      // 优化：增加缓冲和节流，避免高频 setState 导致的 UI 卡顿
      String buffer = '';
      DateTime lastUpdateTime = DateTime.now();
      const updateInterval = Duration(milliseconds: 100);

      await for (final chunk in stream) {
        if (!mounted) break;
        buffer += chunk;

        final now = DateTime.now();
        if (now.difference(lastUpdateTime) >= updateInterval) {
          setState(() {
            _analysis += buffer;
            buffer = '';
          });
          lastUpdateTime = now;
        }
      }

      // 处理剩余的缓冲内容
      if (buffer.isNotEmpty && mounted) {
        setState(() {
          _analysis += buffer;
        });
      }

      if (mounted) {
        setState(() {
          _isStreaming = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isStreaming = false;
        });
      }
    }
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
        if (_audioUrl != null) {
          final file = File(_audioUrl!);
          if (await file.exists()) {
            await _audioPlayer.setFilePath(_audioUrl!);
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
              Text('句子分析', style: Theme.of(context).textTheme.headlineSmall),
              if (_isStreaming)
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
    if (_isLoading && _analysis.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _analysis.isEmpty) {
      return Text('加载失败: $_error');
    }

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((_audioUrl != null && _audioUrl!.isNotEmpty) ||
              _streamingSource != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: _playAudio,
                    tooltip: '播放音频',
                  ),
                  const Text('朗读句子'),
                ],
              ),
            ),
          if (_analysis.isNotEmpty)
            RepaintBoundary(
              child: MarkdownBody(
                data: _analysis,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          if (_isStreaming && _analysis.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('正在分析...'),
              ),
            ),
        ],
      ),
    );
  }
}
