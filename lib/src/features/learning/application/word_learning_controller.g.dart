// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_learning_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WordLearningController)
final wordLearningControllerProvider = WordLearningControllerFamily._();

final class WordLearningControllerProvider
    extends $NotifierProvider<WordLearningController, WordLearningState> {
  WordLearningControllerProvider._({
    required WordLearningControllerFamily super.from,
    required WordLearningRequest super.argument,
  }) : super(
         retry: null,
         name: r'wordLearningControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$wordLearningControllerHash();

  @override
  String toString() {
    return r'wordLearningControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WordLearningController create() => WordLearningController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WordLearningState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WordLearningState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WordLearningControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$wordLearningControllerHash() =>
    r'8a351e2f5aa3ccfaefb8b125c63d8253ccc4a482';

final class WordLearningControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          WordLearningController,
          WordLearningState,
          WordLearningState,
          WordLearningState,
          WordLearningRequest
        > {
  WordLearningControllerFamily._()
    : super(
        retry: null,
        name: r'wordLearningControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WordLearningControllerProvider call(WordLearningRequest request) =>
      WordLearningControllerProvider._(argument: request, from: this);

  @override
  String toString() => r'wordLearningControllerProvider';
}

abstract class _$WordLearningController extends $Notifier<WordLearningState> {
  late final _$args = ref.$arg as WordLearningRequest;
  WordLearningRequest get request => _$args;

  WordLearningState build(WordLearningRequest request);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WordLearningState, WordLearningState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WordLearningState, WordLearningState>,
              WordLearningState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
