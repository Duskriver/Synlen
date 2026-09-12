// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LearningController)
final learningControllerProvider = LearningControllerFamily._();

final class LearningControllerProvider
    extends $NotifierProvider<LearningController, LearningDetailState> {
  LearningControllerProvider._({
    required LearningControllerFamily super.from,
    required LearningQuery super.argument,
  }) : super(
         retry: null,
         name: r'learningControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$learningControllerHash();

  @override
  String toString() {
    return r'learningControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LearningController create() => LearningController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearningDetailState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearningDetailState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LearningControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$learningControllerHash() =>
    r'f17d691fd13cb00fa180131b25b1a24b8b7930b1';

final class LearningControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          LearningController,
          LearningDetailState,
          LearningDetailState,
          LearningDetailState,
          LearningQuery
        > {
  LearningControllerFamily._()
    : super(
        retry: null,
        name: r'learningControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LearningControllerProvider call(LearningQuery query) =>
      LearningControllerProvider._(argument: query, from: this);

  @override
  String toString() => r'learningControllerProvider';
}

abstract class _$LearningController extends $Notifier<LearningDetailState> {
  late final _$args = ref.$arg as LearningQuery;
  LearningQuery get query => _$args;

  LearningDetailState build(LearningQuery query);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LearningDetailState, LearningDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LearningDetailState, LearningDetailState>,
              LearningDetailState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
