// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing library operations with dependency injection

@ProviderFor(LibraryNotifier)
final libraryProvider = LibraryNotifierProvider._();

/// Notifier for managing library operations with dependency injection
final class LibraryNotifierProvider
    extends $AsyncNotifierProvider<LibraryNotifier, LibraryState> {
  /// Notifier for managing library operations with dependency injection
  LibraryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryNotifierHash();

  @$internal
  @override
  LibraryNotifier create() => LibraryNotifier();
}

String _$libraryNotifierHash() => r'f1d9aa7e2b72cb833373d066db68194ad98fd5e6';

/// Notifier for managing library operations with dependency injection

abstract class _$LibraryNotifier extends $AsyncNotifier<LibraryState> {
  FutureOr<LibraryState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<LibraryState>, LibraryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<LibraryState>, LibraryState>,
              AsyncValue<LibraryState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
