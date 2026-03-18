import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:synlen/src/features/learning/domain/aliyun_tts_voice.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';

abstract class AudioFileStore {
  Future<String?> resolveWordAudioPath(
    String word, {
    String? preferredPath,
    String? voice,
  });

  Future<String> saveWordAudioFile(
    String word,
    List<int> bytes,
    AudioFormat format, {
    String? voice,
    bool cacheByVoice = false,
  });

  Future<String?> resolveSentenceAudioPath(
    String sentence, {
    String? preferredPath,
    required String voice,
  });

  Future<String> saveSentenceAudioFile(
    String sentence,
    List<int> bytes,
    AudioFormat format, {
    required String voice,
  });
}

class LearningAudioFileStore implements AudioFileStore {
  const LearningAudioFileStore();

  @override
  Future<String?> resolveWordAudioPath(
    String word, {
    String? preferredPath,
    String? voice,
  }) async {
    final wordKey = _sanitizeWord(word);
    final requestedVoice = voice ?? AliyunTtsVoice.defaultVoice.voiceParam;
    final voiceKey = _sanitizeCacheKey(requestedVoice);

    return _resolveAudioPath(
      preferredPath: preferredPath,
      candidates: [
        _audioFile('word_$wordKey.mp3'),
        _audioFile('word_${wordKey}__$voiceKey.mp3'),
        _audioFile('word_${wordKey}__$voiceKey.pcm'),
        _audioFile('word_${wordKey}__$voiceKey.wav'),
        if (_isDefaultVoice(requestedVoice)) _audioFile('word_$wordKey.pcm'),
        if (_isDefaultVoice(requestedVoice)) _audioFile('word_$wordKey.wav'),
      ],
      preferredPathValidator: (path) =>
          _isWordPathCompatible(path, wordKey: wordKey, voice: requestedVoice),
    );
  }

  @override
  Future<String> saveWordAudioFile(
    String word,
    List<int> bytes,
    AudioFormat format, {
    String? voice,
    bool cacheByVoice = false,
  }) async {
    final existingPath = await resolveWordAudioPath(word, voice: voice);
    if (existingPath != null) {
      return existingPath;
    }

    final wordKey = _sanitizeWord(word);
    final requestedVoice = voice ?? AliyunTtsVoice.defaultVoice.voiceParam;
    final voiceSuffix = cacheByVoice
        ? '__${_sanitizeCacheKey(requestedVoice)}'
        : '';
    final file = await _audioFile(
      'word_$wordKey$voiceSuffix${_extensionForFormat(format)}',
      ensureDirectory: true,
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  Future<String?> resolveSentenceAudioPath(
    String sentence, {
    String? preferredPath,
    required String voice,
  }) async {
    final stableHash = _stableSentenceHash(sentence);
    final legacyHash = sentence.hashCode.toString();
    final voiceKey = _sanitizeCacheKey(voice);

    return _resolveAudioPath(
      preferredPath: preferredPath,
      candidates: [
        _audioFile('sentence_${stableHash}__$voiceKey.pcm'),
        _audioFile('sentence_${stableHash}__$voiceKey.wav'),
        _audioFile('sentence_${stableHash}__$voiceKey.mp3'),
        if (_isDefaultVoice(voice)) _audioFile('sentence_$stableHash.pcm'),
        if (_isDefaultVoice(voice)) _audioFile('sentence_$stableHash.wav'),
        if (_isDefaultVoice(voice)) _audioFile('sentence_$stableHash.mp3'),
        if (_isDefaultVoice(voice)) _audioFile('sentence_$legacyHash.pcm'),
        if (_isDefaultVoice(voice)) _audioFile('sentence_$legacyHash.wav'),
        if (_isDefaultVoice(voice)) _audioFile('sentence_$legacyHash.mp3'),
      ],
      preferredPathValidator: (path) => _isSentencePathCompatible(
        path,
        stableHash: stableHash,
        legacyHash: legacyHash,
        voice: voice,
      ),
    );
  }

  @override
  Future<String> saveSentenceAudioFile(
    String sentence,
    List<int> bytes,
    AudioFormat format, {
    required String voice,
  }) async {
    final existingPath = await resolveSentenceAudioPath(sentence, voice: voice);
    if (existingPath != null) {
      return existingPath;
    }

    final voiceKey = _sanitizeCacheKey(voice);
    final file = await _audioFile(
      'sentence_${_stableSentenceHash(sentence)}__$voiceKey${_extensionForFormat(format)}',
      ensureDirectory: true,
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<String?> _resolveAudioPath({
    required String? preferredPath,
    required List<Future<File>> candidates,
    required bool Function(String path) preferredPathValidator,
  }) async {
    for (final candidateFuture in candidates) {
      final file = await candidateFuture;
      if (await file.exists()) {
        return file.path;
      }
    }

    if (preferredPath != null &&
        preferredPath.isNotEmpty &&
        preferredPathValidator(preferredPath)) {
      final preferredFile = File(preferredPath);
      if (await preferredFile.exists()) {
        return preferredFile.path;
      }
    }

    return null;
  }

  Future<File> _audioFile(String name, {bool ensureDirectory = false}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/audio');
    if (ensureDirectory && !await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return File('${audioDir.path}/$name');
  }

  String _extensionForFormat(AudioFormat format) {
    switch (format) {
      case AudioFormat.mp3:
        return '.mp3';
      case AudioFormat.pcm:
        return '.pcm';
      case AudioFormat.wav:
        return '.wav';
    }
  }

  String _sanitizeWord(String word) {
    return word.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }

  String _sanitizeCacheKey(String value) {
    final sanitized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return sanitized.isEmpty ? 'default' : sanitized;
  }

  bool _isDefaultVoice(String voice) {
    return voice == AliyunTtsVoice.defaultVoice.voiceParam;
  }

  bool _isWordPathCompatible(
    String path, {
    required String wordKey,
    required String voice,
  }) {
    final fileName = _fileName(path);
    final voiceKey = _sanitizeCacheKey(voice);
    final defaultVoice = _isDefaultVoice(voice);

    return fileName == 'word_$wordKey.mp3' ||
        fileName == 'word_${wordKey}__$voiceKey.mp3' ||
        fileName == 'word_${wordKey}__$voiceKey.pcm' ||
        fileName == 'word_${wordKey}__$voiceKey.wav' ||
        (defaultVoice && fileName == 'word_$wordKey.pcm') ||
        (defaultVoice && fileName == 'word_$wordKey.wav');
  }

  bool _isSentencePathCompatible(
    String path, {
    required String stableHash,
    required String legacyHash,
    required String voice,
  }) {
    final fileName = _fileName(path);
    final voiceKey = _sanitizeCacheKey(voice);
    final defaultVoice = _isDefaultVoice(voice);

    return fileName == 'sentence_${stableHash}__$voiceKey.pcm' ||
        fileName == 'sentence_${stableHash}__$voiceKey.wav' ||
        fileName == 'sentence_${stableHash}__$voiceKey.mp3' ||
        (defaultVoice && fileName == 'sentence_$stableHash.pcm') ||
        (defaultVoice && fileName == 'sentence_$stableHash.wav') ||
        (defaultVoice && fileName == 'sentence_$stableHash.mp3') ||
        (defaultVoice && fileName == 'sentence_$legacyHash.pcm') ||
        (defaultVoice && fileName == 'sentence_$legacyHash.wav') ||
        (defaultVoice && fileName == 'sentence_$legacyHash.mp3');
  }

  String _fileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  String _stableSentenceHash(String sentence) {
    var hash = 0xcbf29ce484222325;

    for (var i = 0; i < sentence.length; i++) {
      final codeUnit = sentence.codeUnitAt(i);
      hash ^= codeUnit >> 8;
      hash *= 0x100000001b3;
      hash ^= codeUnit & 0xFF;
      hash *= 0x100000001b3;
    }

    return hash.toUnsigned(64).toRadixString(16);
  }
}
