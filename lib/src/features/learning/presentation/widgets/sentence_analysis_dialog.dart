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

  const SentenceAnalysisDialog({super.key, required this.sentence});

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
            final byteStream = repository.getPronunciationStream(widget.sentence);
            _streamingSource = _StreamingAudioSource(byteStream);

            await _audioPlayer.setAudioSource(_streamingSource!);

            while (!_streamingSource!.isFinished) {
              await Future.delayed(const Duration(milliseconds: 100));
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
          } catch (e) {
            debugPrint('Sentence audio stream error: $e');
            audioCompleter.complete(null);
          }
        });
      }

      // 并行启动 AI 分析流
      await for (final chunk in repository.getSentenceAnalysisStream(
        widget.sentence,
        audioFilePathFuture: audioCompleter.future,
      )) {
        if (mounted) {
          setState(() {
            _analysis += chunk;
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
      if (_audioUrl != null) {
        final file = File(_audioUrl!);
        if (await file.exists()) {
          await _audioPlayer.setFilePath(_audioUrl!);
        }
      } else if (_streamingSource != null) {
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
      title: const Text('句子分析'),
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
            MarkdownBody(
              data: _analysis,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: Theme.of(context).textTheme.bodyMedium,
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
