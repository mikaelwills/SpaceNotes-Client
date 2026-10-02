import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart' show Int64;
import '../platform/capabilities.dart';
import '../screens/call_screen.dart';
import '../screens/incoming_call_screen.dart';
import '../screens/connect_screen.dart';
import '../screens/online_users_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/home_screen.dart';
import '../screens/folder_list_view.dart';
import '../screens/notes_home_view.dart';
import '../screens/passwords_screen.dart';
import '../file_types/file_type_registry.dart';
import '../screens/chat_view.dart';
import '../screens/agent_dashboard.dart';
import '../screens/agent_chat.dart';
import '../widgets/adaptive/adaptive_app_shell.dart';
import '../providers/call_providers.dart';
import '../providers/connection_providers.dart';
import '../providers/notes_providers.dart';
import '../providers/preferences_provider.dart';
import '../services/debug_logger.dart';
import '../widgets/records_view_after_dwell.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class ModalTracker extends NavigatorObserver {
  static int _depth = 0;

  static bool get isModalOpen => _depth > 0;

  bool _isModal(Route<void> route) =>
      route is PopupRoute || route is ModalBottomSheetRoute;

  @override
  void didPush(Route<void> route, Route<void>? previousRoute) {
    if (_isModal(route)) _depth++;
  }

  @override
  void didPop(Route<void> route, Route<void>? previousRoute) {
    if (_isModal(route) && _depth > 0) _depth--;
  }

  @override
  void didRemove(Route<void> route, Route<void>? previousRoute) {
    if (_isModal(route) && _depth > 0) _depth--;
  }
}

final ModalTracker modalTracker = ModalTracker();

GoRouter createAppRouter(ProviderContainer container) {
  bool navigatedToIncoming = false;

  container.listen(incomingCallProvider, (prev, session) {
    if (session != null && !navigatedToIncoming) {
      navigatedToIncoming = true;
      debugLogger.info('INCOMING_CALL', 'Navigating to incoming call screen');
      _router?.go('/calling/incoming');
    } else if (session == null) {
      navigatedToIncoming = false;
    }
  });

  _router = GoRouter(
    initialLocation: '/notes',
    observers: [routeObserver, modalTracker],
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (location.startsWith('/agents') &&
          !container.read(agentsEnabledProvider)) {
        return '/notes';
      }
      if (location.startsWith('/notes/passwords') &&
          (!container.read(passwordsEnabledProvider) ||
              !Capabilities.canManagePasswords)) {
        return '/notes';
      }

      final lane = connectionLaneForLocation(location);
      final laneController =
          container.read(activeConnectionLaneProvider.notifier);
      if (laneController.state != lane) {
        Future(() => laneController.state = lane);
      }

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
        path: '/calling/incoming',
        name: 'incoming-call',
        pageBuilder: (context, state) => _buildFadeTransitionPage(
          key: state.pageKey,
          child: const IncomingCallScreen(),
        ),
      ),
      GoRoute(
        path: '/calling/:sessionId',
        name: 'call',
        pageBuilder: (context, state) {
          final sessionId =
              Int64(int.parse(state.pathParameters['sessionId']!));
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
                path: '/agents/chat',
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
                    child: _FileScreen(key: ValueKey(noteId), fileId: noteId),
                  );
                },
              ),
              GoRoute(
                path: '/notes/passwords',
                name: 'passwords',
                pageBuilder: (context, state) => _buildFadeTransitionPage(
                  key: state.pageKey,
                  child: const PasswordsScreen(),
                ),
              ),
              GoRoute(
                path: '/calling',
                name: 'online-users',
                pageBuilder: (context, state) => _buildFadeTransitionPage(
                  key: state.pageKey,
                  child: const OnlineUsersScreen(),
                ),
              ),
              GoRoute(
                path: '/agents',
                name: 'agents',
                pageBuilder: (context, state) => _buildFadeTransitionPage(
                  key: state.pageKey,
                  child: const AgentDashboard(),
                ),
              ),
              GoRoute(
                path: '/agents/:agentId',
                name: 'agent-chat',
                pageBuilder: (context, state) {
                  final agentId =
                      Uri.decodeComponent(state.pathParameters['agentId']!);
                  return _buildFadeTransitionPage(
                    key: state.pageKey,
                    child: AgentChatScreen(agentId: agentId),
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

GoRouter? get appRouter => _router;

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

class _FileScreen extends ConsumerWidget {
  const _FileScreen({super.key, required this.fileId});

  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(fileByIdProvider(fileId));

    if (file == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Every mobile route into a file lands here, so recording the view once at
    // this point covers all of them and any added later.
    return RecordsViewAfterDwell(
      fileId: fileId,
      child: FileTypeRegistry.forFile(file).buildScreen(fileId),
    );
  }
}
