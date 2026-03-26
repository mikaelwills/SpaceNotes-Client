import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' show Int64;
import '../screens/call_screen.dart';
import '../screens/incoming_call_screen.dart';
import '../screens/connect_screen.dart';
import '../screens/online_users_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/provider_list_screen.dart';
import '../screens/home_screen.dart';
import '../screens/folder_list_view.dart';
import '../screens/notes_home_view.dart';
import '../screens/note_screen.dart';
import '../screens/chat_view.dart';
import '../screens/session_dashboard.dart';
import '../screens/session_chat.dart';
import '../widgets/adaptive/adaptive_app_shell.dart';
import '../providers/call_providers.dart';
import '../providers/notes_providers.dart';
import '../services/debug_logger.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

GoRouter createAppRouter(ProviderContainer container) {
  bool navigatedToIncoming = false;

  container.listen(incomingCallProvider, (prev, next) {
    next.whenData((session) {
      if (session != null && !navigatedToIncoming) {
        navigatedToIncoming = true;
        debugLogger.info('INCOMING_CALL', 'Navigating to incoming call screen');
        _router?.go('/incoming-call');
      } else if (session == null) {
        navigatedToIncoming = false;
      }
    });
  });

  _router = GoRouter(
    initialLocation: '/notes',
    observers: [routeObserver],
    redirect: (context, state) {
      final repo = container.read(notesRepositoryProvider);
      final host = repo.host;
      final isDefault = host == null ||
          host.isEmpty ||
          host.startsWith('0.0.0.0') ||
          host.startsWith('localhost');
      final isConnectRoute = state.matchedLocation == '/connect';
      final isSettingsRoute = state.matchedLocation == '/settings';

      if (isDefault && !isConnectRoute && !isSettingsRoute) {
        return '/connect';
      }
      return null;
    },
    routes: [
    GoRoute(
      path: '/incoming-call',
      name: 'incoming-call',
      pageBuilder: (context, state) => _buildFadeTransitionPage(
        key: state.pageKey,
        child: const IncomingCallScreen(),
      ),
    ),
    GoRoute(
      path: '/call/:sessionId',
      name: 'call',
      pageBuilder: (context, state) {
        final sessionId = Int64(int.parse(state.pathParameters['sessionId']!));
        return _buildFadeTransitionPage(
          key: state.pageKey,
          child: CallScreen(sessionId: sessionId),
        );
      },
    ),
    // Adaptive shell (mobile: nav bar + bottom bar, desktop: sidebar + content)
    ShellRoute(
      builder: (context, state, child) => AdaptiveAppShell(child: child),
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
        // Home shell (shared bottom input area)
        ShellRoute(
          pageBuilder: (context, state, child) => _buildFadeTransitionPage(
            key: state.pageKey,
            child: HomeScreen(child: child),
          ),
          routes: [
            GoRoute(
              path: '/notes',
              name: 'notes',
              pageBuilder: (context, state) => _buildFadeTransitionPage(
                key: state.pageKey,
                child: const NotesHomeView(),
              ),
            ),
            GoRoute(
              path: '/notes/chat',
              name: 'chat',
              pageBuilder: (context, state) => _buildFadeTransitionPage(
                key: state.pageKey,
                child: const ChatView(),
              ),
            ),
            GoRoute(
              path: '/notes/folder/:folderPath(.*)',
              name: 'folder-contents',
              pageBuilder: (context, state) {
                final encodedFolderPath = state.pathParameters['folderPath']!;
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
                  child: FolderListView(folderPath: folderPath),
                );
              },
            ),
            GoRoute(
              path: '/notes/note/:id',
              name: 'note',
              pageBuilder: (context, state) {
                final noteId = state.pathParameters['id']!;
                return _buildFadeTransitionPage(
                  key: state.pageKey,
                  child: NoteScreen(noteId: noteId),
                );
              },
            ),
            GoRoute(
              path: '/notes/users',
              name: 'online-users',
              pageBuilder: (context, state) => _buildFadeTransitionPage(
                key: state.pageKey,
                child: const OnlineUsersScreen(),
              ),
            ),
            GoRoute(
              path: '/notes/sessions',
              name: 'sessions',
              pageBuilder: (context, state) => _buildFadeTransitionPage(
                key: state.pageKey,
                child: const SessionDashboard(),
              ),
            ),
            GoRoute(
              path: '/notes/sessions/:sessionId',
              name: 'session-chat',
              pageBuilder: (context, state) {
                final sessionId = Uri.decodeComponent(state.pathParameters['sessionId']!);
                return _buildFadeTransitionPage(
                  key: state.pageKey,
                  child: SessionChatScreen(sessionId: sessionId),
                );
              },
            ),
          ],
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

  return _router!;
}

GoRouter? _router;

CustomTransitionPage<void> _buildFadeTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 50),
    reverseTransitionDuration: const Duration(milliseconds: 50),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}


