class LearningException implements Exception {
  final String message;

  const LearningException(this.message);

  @override
  String toString() => message;
}
