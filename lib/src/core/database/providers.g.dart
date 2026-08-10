// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// AppDatabase provider（keepAlive：数据库生命周期与 App 一致）。
/// 用 [AppDatabase] 的 QueryExecutor 注入点，测试时可通过
/// `appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory()))` 替换。

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// AppDatabase provider（keepAlive：数据库生命周期与 App 一致）。
/// 用 [AppDatabase] 的 QueryExecutor 注入点，测试时可通过
/// `appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory()))` 替换。

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// AppDatabase provider（keepAlive：数据库生命周期与 App 一致）。
  /// 用 [AppDatabase] 的 QueryExecutor 注入点，测试时可通过
  /// `appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory()))` 替换。
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'3d3a397d2ea952fc020fce0506793a5564e93530';
