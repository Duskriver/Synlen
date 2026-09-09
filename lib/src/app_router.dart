import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/toast_service.dart';
import 'features/library/presentation/book_detail_screen.dart';
import 'features/library/presentation/library_screen.dart';
import 'features/reader/presentation/reader_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'global_share_handler.dart';

/// App Router Configuration
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: ToastService.navigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final location = state.uri.toString();
      if (location.startsWith('content://') || location.startsWith('file://')) {
        Future.microtask(() {
          ref.read(pendingRouteFileProvider.notifier).set(location);
        });
        return '/';
      } else if (location.startsWith('/-')) {
        return '/';
      }
      return null;
    },
    routes: [
      // Library Screen (Home)
      GoRoute(
        path: '/',
        name: 'library',
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const LibraryScreen()),
      ),

      // Book Detail Screen
      GoRoute(
        path: '/book/:id',
        name: 'book-detail',
        pageBuilder: (context, state) {
          final fileHash = state.pathParameters['id']!;
          return MaterialPage(
            key: state.pageKey,
            child: BookDetailScreen(bookId: fileHash),
          );
        },
      ),

      // Reader Screen (Stream-from-Zip)
      GoRoute(
        path: '/read/:id',
        name: 'reader',
        pageBuilder: (context, state) {
          final fileHash = state.pathParameters['id']!;
          return MaterialPage(
            key: state.pageKey,
            child: ReaderScreen(fileHash: fileHash),
          );
        },
      ),

      // Settings Screen
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) {
          return MaterialPage(
            key: state.pageKey,
            child: const SettingsScreen(),
          );
        },
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Route not found: ${state.uri}'))),
  );
});
