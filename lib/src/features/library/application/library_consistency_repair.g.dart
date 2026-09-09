// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_consistency_repair.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 启动时的一次性书架一致性修复。
///
/// 清理两个方向的 DB 孤儿（见 [LibraryBookStore.repairOrphanRecords]）。
/// fire-and-forget：失败只记日志，不阻塞首屏。

@ProviderFor(libraryConsistencyRepair)
final libraryConsistencyRepairProvider = LibraryConsistencyRepairProvider._();

/// 启动时的一次性书架一致性修复。
///
/// 清理两个方向的 DB 孤儿（见 [LibraryBookStore.repairOrphanRecords]）。
/// fire-and-forget：失败只记日志，不阻塞首屏。

final class LibraryConsistencyRepairProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// 启动时的一次性书架一致性修复。
  ///
  /// 清理两个方向的 DB 孤儿（见 [LibraryBookStore.repairOrphanRecords]）。
  /// fire-and-forget：失败只记日志，不阻塞首屏。
  LibraryConsistencyRepairProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryConsistencyRepairProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryConsistencyRepairHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return libraryConsistencyRepair(ref);
  }
}

String _$libraryConsistencyRepairHash() =>
    r'4ebb64aad4b3e9c88565835b5694bc00bad3b98f';
