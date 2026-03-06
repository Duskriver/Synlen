import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
  bool _isStreaming = false;
  String _explanation = '';
  String? _pronunciationUrl; // 本地路径或 null
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

      final repository = ref.read(wordRepositoryProvider);

      // 1. 获取基础信息（主要检查缓存）
      final result = await repository.getWordInfo(widget.word, widget.context);

      if (result.isFromCache) {
        if (mounted) {
          setState(() {
            _explanation = result.explanation ?? '';
            _pronunciationUrl = result.audioUrl;
            _isLoading = false;
          });
          // 如果有缓存音频，立即设置源
          if (_pronunciationUrl != null && !_isDisposed) {
            final file = File(_pronunciationUrl!);
            if (await file.exists()) {
              await _audioPlayer.setFilePath(_pronunciationUrl!);
            }
          }
        }
        return;
      }

      // 2. 无缓存：同时启动音频和 AI
      if (mounted) {
        setState(() {
          _pronunciationUrl = result.audioUrl; // 如果本地已有音频，直接设置
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
              widget.word,
            );

            // 获取流中的第一个（也是唯一一个）AudioStreamResult
            await for (final result in audioResultStream) {
              if (_isDisposed) break;

              _streamingSource = _StreamingAudioSource(
                result.stream,
                result.format,
              );

              // 立即设置播放源，实现流式播放准备
              if (!_isDisposed) {
                await _audioPlayer.setAudioSource(_streamingSource!);
              }

              // 等待流结束并保存文件
              while (mounted && !_streamingSource!.isFinished) {
                await Future.delayed(const Duration(milliseconds: 100));
              }

              if (!mounted) {
                audioCompleter.complete(null);
                return;
              }

              final filePath = await repository.saveAudioFile(
                widget.word,
                _streamingSource!.bytes,
              );
              audioCompleter.complete(filePath);

              if (mounted) {
                setState(() {
                  _pronunciationUrl = filePath;
                });
              }
              break; // 只处理第一个结果
            }
          } catch (e) {
            debugPrint('Audio stream error: $e');
            if (!audioCompleter.isCompleted) {
              audioCompleter.complete(null);
            }
          }
        });
      }

      // 并行启动 AI 解释流
      final stream = repository.getWordExplanationStream(
        widget.word,
        widget.context,
        audioFilePathFuture: audioCompleter.future,
      );

      await for (final chunk in stream) {
        if (!mounted) break;
        setState(() {
          _explanation += chunk;
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
    if (_isLoading && _explanation.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _explanation.isEmpty) {
      return Text('加载失败: $_error');
    }

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((_pronunciationUrl != null && _pronunciationUrl!.isNotEmpty) ||
              _streamingSource != null)
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
          if (_explanation.isNotEmpty)
            MarkdownBody(
              data: _explanation,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (_isStreaming && _explanation.isEmpty)
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
