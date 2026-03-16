// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentence_learning_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sentenceLearningControllerHash() =>
    r'3cbb4a2318ff633db9ad0277c14beeb919c13311';

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

abstract class _$SentenceLearningController
    extends BuildlessAutoDisposeNotifier<SentenceLearningState> {
  late final String sentence;

  SentenceLearningState build(
    String sentence,
  );
}

/// See also [SentenceLearningController].
@ProviderFor(SentenceLearningController)
const sentenceLearningControllerProvider = SentenceLearningControllerFamily();

/// See also [SentenceLearningController].
class SentenceLearningControllerFamily extends Family<SentenceLearningState> {
  /// See also [SentenceLearningController].
  const SentenceLearningControllerFamily();

  /// See also [SentenceLearningController].
  SentenceLearningControllerProvider call(
    String sentence,
  ) {
    return SentenceLearningControllerProvider(
      sentence,
    );
  }

  @override
  SentenceLearningControllerProvider getProviderOverride(
    covariant SentenceLearningControllerProvider provider,
  ) {
    return call(
      provider.sentence,
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
  String? get name => r'sentenceLearningControllerProvider';
}

/// See also [SentenceLearningController].
class SentenceLearningControllerProvider
    extends AutoDisposeNotifierProviderImpl<SentenceLearningController,
        SentenceLearningState> {
  /// See also [SentenceLearningController].
  SentenceLearningControllerProvider(
    String sentence,
  ) : this._internal(
          () => SentenceLearningController()..sentence = sentence,
          from: sentenceLearningControllerProvider,
          name: r'sentenceLearningControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$sentenceLearningControllerHash,
          dependencies: SentenceLearningControllerFamily._dependencies,
          allTransitiveDependencies:
              SentenceLearningControllerFamily._allTransitiveDependencies,
          sentence: sentence,
        );

  SentenceLearningControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sentence,
  }) : super.internal();

  final String sentence;

  @override
  SentenceLearningState runNotifierBuild(
    covariant SentenceLearningController notifier,
  ) {
    return notifier.build(
      sentence,
    );
  }

  @override
  Override overrideWith(SentenceLearningController Function() create) {
    return ProviderOverride(
      origin: this,
      override: SentenceLearningControllerProvider._internal(
        () => create()..sentence = sentence,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sentence: sentence,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<SentenceLearningController,
      SentenceLearningState> createElement() {
    return _SentenceLearningControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SentenceLearningControllerProvider &&
        other.sentence == sentence;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sentence.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SentenceLearningControllerRef
    on AutoDisposeNotifierProviderRef<SentenceLearningState> {
  /// The parameter `sentence` of this provider.
  String get sentence;
}

class _SentenceLearningControllerProviderElement
    extends AutoDisposeNotifierProviderElement<SentenceLearningController,
        SentenceLearningState> with SentenceLearningControllerRef {
  _SentenceLearningControllerProviderElement(super.provider);

  @override
  String get sentence =>
      (origin as SentenceLearningControllerProvider).sentence;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
