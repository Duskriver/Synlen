// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_entry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 学习能力的对外入口：宿主提供词锚点并在重排时关闭词卡。

@ProviderFor(LearningEntry)
final learningEntryProvider = LearningEntryProvider._();

/// 学习能力的对外入口：宿主提供词锚点并在重排时关闭词卡。
final class LearningEntryProvider
    extends $NotifierProvider<LearningEntry, void> {
  /// 学习能力的对外入口：宿主提供词锚点并在重排时关闭词卡。
  LearningEntryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'learningEntryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$learningEntryHash();

  @$internal
  @override
  LearningEntry create() => LearningEntry();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$learningEntryHash() => r'967d83bdd73f1962b1bb35ff0dde3c5b985f6a12';

/// 学习能力的对外入口：宿主提供词锚点并在重排时关闭词卡。

abstract class _$LearningEntry extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
