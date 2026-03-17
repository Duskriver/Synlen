import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';

abstract class AudioFileStore {
  Future<String?> resolveWordAudioPath(String word, {String? preferredPath});

  Future<String> saveWordAudioFile(
    String word,
    List<int> bytes,
    AudioFormat format,
  );

  Future<String?> resolveSentenceAudioPath(
    String sentence, {
    String? preferredPath,
  });

  Future<String> saveSentenceAudioFile(
    String sentence,
    List<int> bytes,
    AudioFormat format,
  );
}

class LearningAudioFileStore implements AudioFileStore {
  const LearningAudioFileStore();

  @override
  Future<String?> resolveWordAudioPath(
    String word, {
    String? preferredPath,
  }) async {
    return _resolveAudioPath(
      preferredPath: preferredPath,
      candidates: [
        _audioFile('word_${_sanitizeWord(word)}.mp3'),
        _audioFile('word_${_sanitizeWord(word)}.pcm'),
        _audioFile('word_${_sanitizeWord(word)}.wav'),
      ],
    );
  }

  @override
  Future<String> saveWordAudioFile(
    String word,
    List<int> bytes,
    AudioFormat format,
  ) async {
    final existingPath = await resolveWordAudioPath(word);
    if (existingPath != null) {
      return existingPath;
    }

    final file = await _audioFile(
      'word_${_sanitizeWord(word)}${_extensionForFormat(format)}',
      ensureDirectory: true,
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  Future<String?> resolveSentenceAudioPath(
    String sentence, {
    String? preferredPath,
  }) async {
    final stableHash = _stableSentenceHash(sentence);
    final legacyHash = sentence.hashCode.toString();

    return _resolveAudioPath(
      preferredPath: preferredPath,
      candidates: [
        _audioFile('sentence_$stableHash.pcm'),
        _audioFile('sentence_$stableHash.wav'),
        _audioFile('sentence_$stableHash.mp3'),
        _audioFile('sentence_$legacyHash.pcm'),
        _audioFile('sentence_$legacyHash.wav'),
        _audioFile('sentence_$legacyHash.mp3'),
      ],
    );
  }

  @override
  Future<String> saveSentenceAudioFile(
    String sentence,
    List<int> bytes,
    AudioFormat format,
  ) async {
    final existingPath = await resolveSentenceAudioPath(sentence);
    if (existingPath != null) {
      return existingPath;
    }

    final file = await _audioFile(
      'sentence_${_stableSentenceHash(sentence)}${_extensionForFormat(format)}',
      ensureDirectory: true,
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<String?> _resolveAudioPath({
    required String? preferredPath,
    required List<Future<File>> candidates,
  }) async {
    if (preferredPath != null && preferredPath.isNotEmpty) {
      final preferredFile = File(preferredPath);
      if (await preferredFile.exists()) {
        return preferredFile.path;
      }
    }

    for (final candidateFuture in candidates) {
      final file = await candidateFuture;
      if (await file.exists()) {
        return file.path;
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
