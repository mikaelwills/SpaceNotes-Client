import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/notes_providers.dart';
import '../../theme/spacenotes_theme.dart';
import '../sync_state_indicator.dart';
import 'desktop_note_view.dart';
import 'note_tabs.dart';
import 'sidebar.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);
final sidebarWidthProvider = StateProvider<double>((ref) => 450.0);

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
  static const double _collapsedWidth = 48.0;
  static const double _dividerWidth = 1.0;

  bool _isResizing = false;

  @override
  Widget build(BuildContext context) {
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
}

class _DesktopContentArea extends StatelessWidget {
  final Widget child;

  const _DesktopContentArea({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final isChat = location.startsWith('/notes/chat');
    final isSettings = location.startsWith('/settings');
    final isConnect = location.startsWith('/connect');
    final isSessions = location.startsWith('/notes/sessions');

    return Column(
      children: [
        _DesktopTopBar(
            showTabs: !isChat && !isSettings && !isConnect && !isSessions),
        Expanded(
          child:
              _buildContent(context, isChat, isSettings, isConnect, isSessions),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isChat, bool isSettings,
      bool isConnect, bool isSessions) {
    if (isChat || isSettings || isConnect || isSessions) {
      return child;
    }
    return const DesktopNoteView();
  }
}

class _DesktopTopBar extends ConsumerWidget {
  final bool showTabs;

  const _DesktopTopBar({this.showTabs = false});

  String _getBreadcrumb(String location, WidgetRef ref) {
    if (location.startsWith('/notes/note/')) {
      final noteId = location.substring('/notes/note/'.length);
      final note = ref.watch(noteByIdProvider(noteId));
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
    if (location == '/notes/chat') {
      return 'chat';
    }
    if (location.startsWith('/notes/sessions')) {
      return 'sessions';
    }
    if (location == '/settings') {
      return 'settings';
    }
    return '';
  }

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
}
