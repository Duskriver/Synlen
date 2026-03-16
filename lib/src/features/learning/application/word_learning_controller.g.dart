// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_learning_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$wordLearningControllerHash() =>
    r'39e23e03151699e3533e773570ec17151abb8a6c';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$WordLearningController
    extends BuildlessAutoDisposeNotifier<WordLearningState> {
  late final WordLearningRequest request;

  WordLearningState build(
    WordLearningRequest request,
  );
}

/// See also [WordLearningController].
@ProviderFor(WordLearningController)
const wordLearningControllerProvider = WordLearningControllerFamily();

/// See also [WordLearningController].
class WordLearningControllerFamily extends Family<WordLearningState> {
  /// See also [WordLearningController].
  const WordLearningControllerFamily();

  /// See also [WordLearningController].
  WordLearningControllerProvider call(
    WordLearningRequest request,
  ) {
    return WordLearningControllerProvider(
      request,
    );
  }

  @override
  WordLearningControllerProvider getProviderOverride(
    covariant WordLearningControllerProvider provider,
  ) {
    return call(
      provider.request,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'wordLearningControllerProvider';
}

/// See also [WordLearningController].
class WordLearningControllerProvider extends AutoDisposeNotifierProviderImpl<
    WordLearningController, WordLearningState> {
  /// See also [WordLearningController].
  WordLearningControllerProvider(
    WordLearningRequest request,
  ) : this._internal(
          () => WordLearningController()..request = request,
          from: wordLearningControllerProvider,
          name: r'wordLearningControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$wordLearningControllerHash,
          dependencies: WordLearningControllerFamily._dependencies,
          allTransitiveDependencies:
              WordLearningControllerFamily._allTransitiveDependencies,
          request: request,
        );

  WordLearningControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.request,
  }) : super.internal();

  final WordLearningRequest request;

  @override
  WordLearningState runNotifierBuild(
    covariant WordLearningController notifier,
  ) {
    return notifier.build(
      request,
    );
  }

  @override
  Override overrideWith(WordLearningController Function() create) {
    return ProviderOverride(
      origin: this,
      override: WordLearningControllerProvider._internal(
        () => create()..request = request,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        request: request,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<WordLearningController, WordLearningState>
      createElement() {
    return _WordLearningControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WordLearningControllerProvider && other.request == request;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, request.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin WordLearningControllerRef
    on AutoDisposeNotifierProviderRef<WordLearningState> {
  /// The parameter `request` of this provider.
  WordLearningRequest get request;
}

class _WordLearningControllerProviderElement
    extends AutoDisposeNotifierProviderElement<WordLearningController,
        WordLearningState> with WordLearningControllerRef {
  _WordLearningControllerProviderElement(super.provider);

  @override
  WordLearningRequest get request =>
      (origin as WordLearningControllerProvider).request;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
