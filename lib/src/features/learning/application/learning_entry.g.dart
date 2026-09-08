// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_entry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 学习能力的对外入口：宿主（阅读器）只依赖这两个方法，
/// 弹窗形状、滚动与生命周期留在学习模块内部。

@ProviderFor(LearningEntry)
final learningEntryProvider = LearningEntryProvider._();

/// 学习能力的对外入口：宿主（阅读器）只依赖这两个方法，
/// 弹窗形状、滚动与生命周期留在学习模块内部。
final class LearningEntryProvider
    extends $NotifierProvider<LearningEntry, void> {
  /// 学习能力的对外入口：宿主（阅读器）只依赖这两个方法，
  /// 弹窗形状、滚动与生命周期留在学习模块内部。
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

String _$learningEntryHash() => r'971ddc7a64207d1c50b61d9ba12febcb9786d2ae';

/// 学习能力的对外入口：宿主（阅读器）只依赖这两个方法，
/// 弹窗形状、滚动与生命周期留在学习模块内部。

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
