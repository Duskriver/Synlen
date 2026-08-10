// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentence_learning_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SentenceLearningController)
final sentenceLearningControllerProvider = SentenceLearningControllerFamily._();

final class SentenceLearningControllerProvider
    extends
        $NotifierProvider<SentenceLearningController, SentenceLearningState> {
  SentenceLearningControllerProvider._({
    required SentenceLearningControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sentenceLearningControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sentenceLearningControllerHash();

  @override
  String toString() {
    return r'sentenceLearningControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SentenceLearningController create() => SentenceLearningController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SentenceLearningState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SentenceLearningState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SentenceLearningControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sentenceLearningControllerHash() =>
    r'e33be34bcdfa54d8de682c63f97d03b492246e83';

final class SentenceLearningControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SentenceLearningController,
          SentenceLearningState,
          SentenceLearningState,
          SentenceLearningState,
          String
        > {
  SentenceLearningControllerFamily._()
    : super(
        retry: null,
        name: r'sentenceLearningControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SentenceLearningControllerProvider call(String sentence) =>
      SentenceLearningControllerProvider._(argument: sentence, from: this);

  @override
  String toString() => r'sentenceLearningControllerProvider';
}

abstract class _$SentenceLearningController
    extends $Notifier<SentenceLearningState> {
  late final _$args = ref.$arg as String;
  String get sentence => _$args;

  SentenceLearningState build(String sentence);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SentenceLearningState, SentenceLearningState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SentenceLearningState, SentenceLearningState>,
              SentenceLearningState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
