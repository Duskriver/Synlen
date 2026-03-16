import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract class AudioFileStore {
  Future<String?> resolveWordAudioPath(String word, {String? preferredPath});

  Future<String> saveWordAudioFile(String word, List<int> bytes);

  Future<String?> resolveSentenceAudioPath(
    String sentence, {
    String? preferredPath,
  });

  Future<String> saveSentenceAudioFile(String sentence, List<int> bytes);
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
        _audioFile('word_${_sanitizeWord(word)}.wav'),
      ],
    );
  }

  @override
  Future<String> saveWordAudioFile(String word, List<int> bytes) async {
    final existingPath = await resolveWordAudioPath(word);
    if (existingPath != null) {
      return existingPath;
    }

    final isWav = _isWav(bytes);
    final file = await _audioFile(
      'word_${_sanitizeWord(word)}${isWav ? '.wav' : '.mp3'}',
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
        _audioFile('sentence_$stableHash.wav'),
        _audioFile('sentence_$stableHash.mp3'),
        _audioFile('sentence_$legacyHash.wav'),
        _audioFile('sentence_$legacyHash.mp3'),
      ],
    );
  }

  @override
  Future<String> saveSentenceAudioFile(String sentence, List<int> bytes) async {
    final existingPath = await resolveSentenceAudioPath(sentence);
    if (existingPath != null) {
      return existingPath;
    }

    final file = await _audioFile(
      'sentence_${_stableSentenceHash(sentence)}.wav',
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

  bool _isWav(List<int> bytes) {
    return bytes.length > 4 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46;
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
