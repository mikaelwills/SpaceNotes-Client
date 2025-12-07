import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/connect_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/sessions_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/provider_list_screen.dart';
import '../screens/top_folder_screen.dart';
import '../screens/note_screen.dart';
import '../widgets/main_scaffold.dart';

// Global RouteObserver for detecting navigation back to screens
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

final GoRouter appRouter = GoRouter(
  initialLocation: '/notes',
  observers: [routeObserver],
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/connect',
          name: 'connect',
          pageBuilder: (context, state) => _buildFadeTransitionPage(
            key: state.pageKey,
            child: const ConnectScreen(),
          ),
        ),
        GoRoute(
          path: '/chat',
          name: 'chat',
          pageBuilder: (context, state) => _buildFadeTransitionPage(
            key: state.pageKey,
            child: const ChatScreen(),
          ),
        ),
        GoRoute(
          path: '/sessions',
          name: 'sessions',
          pageBuilder: (context, state) => _buildFadeTransitionPage(
            key: state.pageKey,
            child: const SessionsScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) => _buildFadeTransitionPage(
            key: state.pageKey,
            child: const SettingsScreen(),
          ),
        ),
        GoRoute(
          path: '/provider-list',
          name: 'provider-list',
          pageBuilder: (context, state) => _buildFadeTransitionPage(
            key: state.pageKey,
            child: const ProviderListScreen(),
          ),
        ),
        GoRoute(
          path: '/notes',
          name: 'notes',
          pageBuilder: (context, state) => _buildFadeTransitionPage(
            key: state.pageKey,
            child: const TopFolderListScreen(folderPath: ''), // Root level
          ),
        ),
        GoRoute(
          path: '/notes/folder/:folderPath(.*)',
          name: 'folder-contents',
          pageBuilder: (context, state) {
            final encodedFolderPath = state.pathParameters['folderPath']!;
            // Decode each segment separately to handle paths with slashes
            final segments = encodedFolderPath.split('/');
            final decodedSegments = segments.map((segment) {
              try {
                return Uri.decodeComponent(segment);
              } catch (e) {
                return segment;
              }
            }).toList();
            final folderPath = decodedSegments.join('/');
            return _buildFadeTransitionPage(
              key: state.pageKey,
              child: TopFolderListScreen(folderPath: folderPath),
            );
          },
        ),
        GoRoute(
          path: '/notes/:path',
          name: 'note',
          pageBuilder: (context, state) {
            final encodedPath = state.pathParameters['path']!;
            // Try to decode, but if it fails (already decoded or invalid), use as-is
            String path;
            try {
              path = Uri.decodeComponent(encodedPath);
            } catch (e) {
              print('⚠️ URI decode failed for: $encodedPath, using as-is');
              path = encodedPath;
            }
            final isNewNote = state.uri.queryParameters['new'] == 'true';
            return _buildFadeTransitionPage(
              key: state.pageKey,
              child: NoteScreen(
                notePath: path,
                isNewNote: isNewNote,
              ),
            );
          },
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.error}'),
    ),
  ),
);

CustomTransitionPage<void> _buildFadeTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 50),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOutCirc).animate(animation),
        child: child,
      );
    },
  );
}


