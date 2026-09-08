// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_session_factory.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 阅读会话的装配入口：data 层依赖的注入集中在这里，
/// presentation 只取装配好的会话与 WebView 处理器。

@ProviderFor(ReaderSessionFactory)
final readerSessionFactoryProvider = ReaderSessionFactoryProvider._();

/// 阅读会话的装配入口：data 层依赖的注入集中在这里，
/// presentation 只取装配好的会话与 WebView 处理器。
final class ReaderSessionFactoryProvider
    extends $NotifierProvider<ReaderSessionFactory, void> {
  /// 阅读会话的装配入口：data 层依赖的注入集中在这里，
  /// presentation 只取装配好的会话与 WebView 处理器。
  ReaderSessionFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerSessionFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerSessionFactoryHash();

  @$internal
  @override
  ReaderSessionFactory create() => ReaderSessionFactory();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$readerSessionFactoryHash() =>
    r'8ac98ae2ccefa0437605a949bda05f4402bf952a';

/// 阅读会话的装配入口：data 层依赖的注入集中在这里，
/// presentation 只取装配好的会话与 WebView 处理器。

abstract class _$ReaderSessionFactory extends $Notifier<void> {
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
