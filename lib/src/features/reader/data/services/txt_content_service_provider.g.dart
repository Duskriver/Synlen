// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'txt_content_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for TxtContentService
/// TXT 章节内容供给：按 manifest 中的字节范围随机读取并包装为 XHTML

@ProviderFor(txtContentService)
final txtContentServiceProvider = TxtContentServiceProvider._();

/// Provider for TxtContentService
/// TXT 章节内容供给：按 manifest 中的字节范围随机读取并包装为 XHTML

final class TxtContentServiceProvider
    extends
        $FunctionalProvider<
          TxtContentService,
          TxtContentService,
          TxtContentService
        >
    with $Provider<TxtContentService> {
  /// Provider for TxtContentService
  /// TXT 章节内容供给：按 manifest 中的字节范围随机读取并包装为 XHTML
  TxtContentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'txtContentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$txtContentServiceHash();

  @$internal
  @override
  $ProviderElement<TxtContentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TxtContentService create(Ref ref) {
    return txtContentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TxtContentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TxtContentService>(value),
    );
  }
}

String _$txtContentServiceHash() => r'69a3b0c475608ade649ffa1f509ca7469ae4a974';
