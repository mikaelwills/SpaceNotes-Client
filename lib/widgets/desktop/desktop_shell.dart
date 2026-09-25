import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/middle_pane_mode_provider.dart';
import '../../providers/notes_providers.dart';
import '../../screens/folder_list_view.dart';
import '../../theme/spacenotes_theme.dart';
import '../adaptive/nav_cycle.dart';
import '../note_chat_panel.dart';
import '../sync_state_indicator.dart';
import 'desktop_note_view.dart';
import 'desktop_agents_layout.dart';
import 'note_tabs.dart';
import 'sidebar.dart';
import '../../providers/preferences_provider.dart';
import '../records_view_after_dwell.dart';

final sidebarCollapsedProvider = StateProvider<bool>(
  (ref) => ref.read(preferencesProvider).sidebarStartsCollapsed,
);
final sidebarWidthProvider = StateProvider<double>((ref) => 245.0);
final chatPanelCollapsedProvider = StateProvider<bool>(
  (ref) => ref.read(preferencesProvider).chatPanelStartsCollapsed,
);

const double kCollapsedPaneWidth = 48.0;

class DesktopShell extends ConsumerStatefulWidget {
  final Widget child;

  const DesktopShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  static const double _minSidebarWidth = 200.0;
  static const double _maxSidebarWidth = 500.0;
  static const double _collapsedWidth = kCollapsedPaneWidth;
  static const double _dividerWidth = 1.0;

  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): _focusSearch,
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>
            cycleNav(
              context,
              agentsEnabled: ref.read(agentsEnabledProvider),
              passwordsEnabled: ref.read(passwordsEnabledProvider),
            ),
      },
      child: Focus(autofocus: true, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/agents') && !location.startsWith('/agents/chat')) {
      String? activeAgentId;
      if (location.startsWith('/agents/')) {
        final encoded = location.substring('/agents/'.length);
        activeAgentId = Uri.decodeComponent(encoded);
      }
      return Scaffold(
        backgroundColor: SpaceNotesTheme.bg,
        // ignore: prefer_const_constructors
        body: DesktopAgentsLayout(activeAgentId: activeAgentId),
      );
    }

    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final sidebarWidth = ref.watch(sidebarWidthProvider);

    return Scaffold(
      backgroundColor: SpaceNotesTheme.bg,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: isCollapsed ? _collapsedWidth : sidebarWidth,
            child: const Sidebar(),
          ),
          MouseRegion(
            cursor: isCollapsed
                ? SystemMouseCursors.basic
                : SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragStart: isCollapsed
                  ? null
                  : (_) {
                      setState(() => _isResizing = true);
                    },
              onHorizontalDragUpdate: isCollapsed
                  ? null
                  : (details) {
                      final newWidth = sidebarWidth + details.delta.dx;
                      ref.read(sidebarWidthProvider.notifier).state =
                          newWidth.clamp(_minSidebarWidth, _maxSidebarWidth);
                    },
              onHorizontalDragEnd: isCollapsed
                  ? null
                  : (_) {
                      setState(() => _isResizing = false);
                    },
              child: Container(
                width: _dividerWidth,
                color: _isResizing
                    ? SpaceNotesTheme.accent
                    : SpaceNotesTheme.hairline,
              ),
            ),
          ),
          Expanded(
            child: _DesktopContentArea(child: widget.child),
          ),
        ],
      ),
    );
  }

  void _focusSearch() {
    ref.read(searchFocusRequestProvider.notifier).state++;
  }
}

class _DesktopContentArea extends ConsumerWidget {
  final Widget child;

  const _DesktopContentArea({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final isChat = location.startsWith('/agents/chat');
    final isSettings = location.startsWith('/settings');
    final isConnect = location.startsWith('/connect');
    final isAgents = location.startsWith('/agents') && !isChat;
    final isNotesView =
        !isChat && !isSettings && !isConnect && !isAgents;

    if (!isNotesView) {
      return Column(
        children: [
          const _DesktopTopBar(showTabs: false),
          Expanded(child: child),
        ],
      );
    }

    final openNoteId = ref.watch(currentNotePathProvider);
    final chatPanelCollapsed = ref.watch(chatPanelCollapsedProvider);
    final mode = ref.watch(middlePaneModeProvider);

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              const _DesktopTopBar(showTabs: true),
              Expanded(child: _MiddlePaneContent(mode: mode)),
            ],
          ),
        ),
        if (!chatPanelCollapsed)
          NoteChatPanel(
            notePath: openNoteId ?? '',
            isDesktop: true,
          )
        else
          _ChatPanelReopenTab(
            onTap: () =>
                ref.read(chatPanelCollapsedProvider.notifier).state = false,
          ),
      ],
    );
  }
}

class _ChatPanelReopenTab extends StatelessWidget {
  const _ChatPanelReopenTab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('chat-panel-expand'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: kCollapsedPaneWidth,
        decoration: const BoxDecoration(
          color: SpaceNotesTheme.bg,
          border: Border(
            left: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
          ),
        ),
        child: const Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              '‹',
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 14,
                color: SpaceNotesTheme.dim,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiddlePaneContent extends StatelessWidget {
  final MiddlePaneMode mode;

  const _MiddlePaneContent({required this.mode});

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      BrowseMode(:final folderPath) =>
        FolderListView(key: ValueKey('browse:$folderPath'), folderPath: folderPath),
      // Desktop bypasses the router, so the view is recorded here instead.
      // Six places set this mode; this is the one place that renders it.
      FileViewerMode(:final noteId) => RecordsViewAfterDwell(
          fileId: noteId,
          child: const DesktopNoteView(),
        ),
      SearchResultsMode() =>
        const FolderListView(key: ValueKey('search'), folderPath: ''),
    };
  }
}

class _DesktopTopBar extends ConsumerWidget {
  final bool showTabs;

  const _DesktopTopBar({this.showTabs = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final breadcrumb = _getBreadcrumb(location, ref);

    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.bg,
        border: Border(
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (showTabs)
            const Expanded(child: NoteTabs())
          else ...[
            const SizedBox(width: 20),
            Expanded(
              child: Row(
                children: [
                  const Text(
                    '◆',
                    style: TextStyle(
                      color: SpaceNotesTheme.accent,
                      fontSize: 10,
                      fontFamily: SpaceNotesTheme.fontMono,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      breadcrumb,
                      style: const TextStyle(
                        fontFamily: SpaceNotesTheme.fontMono,
                        fontSize: 11,
                        color: SpaceNotesTheme.muted,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: SyncStateIndicator(),
          ),
        ],
      ),
    );
  }

  String _getBreadcrumb(String location, WidgetRef ref) {
    if (location.startsWith('/notes/note/')) {
      final noteId = location.substring('/notes/note/'.length);
      final note = ref.watch(fileByIdProvider(noteId));
      if (note != null) {
        return note.path;
      }
      return '';
    }
    if (location.startsWith('/notes/folder/')) {
      final encodedPath = location.substring('/notes/folder/'.length);
      final decodedPath = Uri.decodeComponent(encodedPath);
      return decodedPath;
    }
    if (location == '/notes' || location == '/notes/') {
      return 'all notes';
    }
    if (location == '/agents/chat') {
      return 'chat';
    }
    if (location.startsWith('/agents')) {
      return 'agents';
    }
    if (location == '/settings') {
      return 'settings';
    }
    return '';
  }
}
