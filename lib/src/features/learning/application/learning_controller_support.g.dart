// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_controller_support.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 每个查询创建独立播放器；测试可替换工厂而不触及平台通道。

@ProviderFor(learningAudioPlayerFactory)
final learningAudioPlayerFactoryProvider =
    LearningAudioPlayerFactoryProvider._();

/// 每个查询创建独立播放器；测试可替换工厂而不触及平台通道。

final class LearningAudioPlayerFactoryProvider
    extends
        $FunctionalProvider<
          LearningAudioPlayer Function(),
          LearningAudioPlayer Function(),
          LearningAudioPlayer Function()
        >
    with $Provider<LearningAudioPlayer Function()> {
  /// 每个查询创建独立播放器；测试可替换工厂而不触及平台通道。
  LearningAudioPlayerFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'learningAudioPlayerFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$learningAudioPlayerFactoryHash();

  @$internal
  @override
  $ProviderElement<LearningAudioPlayer Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LearningAudioPlayer Function() create(Ref ref) {
    return learningAudioPlayerFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearningAudioPlayer Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearningAudioPlayer Function()>(
        value,
      ),
    );
  }
}

String _$learningAudioPlayerFactoryHash() =>
    r'9e259ca371357ff0753aa9288d1fa6a33c0c8a4a';
