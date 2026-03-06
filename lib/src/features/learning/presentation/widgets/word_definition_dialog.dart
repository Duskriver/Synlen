import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lumina/src/features/learning/data/repositories/learning_repository_provider.dart';

/// 一个简单的流式音频源，用于播放边下载边缓存的音频字节
class _StreamingAudioSource extends StreamAudioSource {
  final Stream<List<int>> byteStream;
  final List<int> _buffer = [];
  final _controller = StreamController<List<int>>.broadcast();
  bool _isFinished = false;

  _StreamingAudioSource(this.byteStream) {
    _init();
  }

  void _init() async {
    await for (final chunk in byteStream) {
      _buffer.addAll(chunk);
      _controller.add(chunk);
    }
    _isFinished = true;
    _controller.close();
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
      contentType: 'audio/mpeg',
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

  const WordDefinitionDialog({
    super.key,
    required this.word,
    required this.context,
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

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setVolume(1.0);
    _loadData();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
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
            final byteStream = repository.getPronunciationStream(widget.word);
            _streamingSource = _StreamingAudioSource(byteStream);

            // 立即设置播放源，实现流式播放准备
            await _audioPlayer.setAudioSource(_streamingSource!);

            if (mounted) {
              setState(() {
                // 在流式加载中，暂时不显示播放按钮，直到有数据或播放器准备好
              });
            }

            // 等待流结束并保存文件
            while (!_streamingSource!.isFinished) {
              await Future.delayed(const Duration(milliseconds: 100));
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
          } catch (e) {
            debugPrint('Audio stream error: $e');
            audioCompleter.complete(null);
          }
        });
      }

      // 并行启动 AI 解释流
      await for (final chunk in repository.getWordExplanationStream(
        widget.word,
        widget.context,
        audioFilePathFuture: audioCompleter.future,
      )) {
        if (mounted) {
          setState(() {
            _explanation += chunk;
          });
        }
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
    try {
      if (_pronunciationUrl != null) {
        final file = File(_pronunciationUrl!);
        if (await file.exists()) {
          await _audioPlayer.setFilePath(_pronunciationUrl!);
        }
      } else if (_streamingSource != null) {
        // 如果还在流式加载中，直接播放当前源
        await _audioPlayer.play();
        return;
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.word),
      content: SizedBox(width: double.maxFinite, child: _buildContent()),
      actions: [
        if (_isStreaming)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
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
