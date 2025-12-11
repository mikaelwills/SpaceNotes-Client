import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/spacenotes_theme.dart';
import '../connection_indicator.dart';
import 'desktop_note_view.dart';
import 'note_tabs.dart';
import 'sidebar.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);
final sidebarWidthProvider = StateProvider<double>((ref) => 310.0);

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
  static const double _maxSidebarWidth = 400.0;
  static const double _collapsedWidth = 48.0;
  static const double _dividerWidth = 1.0;

  bool _isResizing = false;

  @override
  Widget build(BuildContext context) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final sidebarWidth = ref.watch(sidebarWidthProvider);

    return Scaffold(
      backgroundColor: SpaceNotesTheme.background,
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
              onHorizontalDragStart: isCollapsed ? null : (_) {
                setState(() => _isResizing = true);
              },
              onHorizontalDragUpdate: isCollapsed ? null : (details) {
                final newWidth = sidebarWidth + details.delta.dx;
                ref.read(sidebarWidthProvider.notifier).state =
                    newWidth.clamp(_minSidebarWidth, _maxSidebarWidth);
              },
              onHorizontalDragEnd: isCollapsed ? null : (_) {
                setState(() => _isResizing = false);
              },
              child: Container(
                width: _dividerWidth,
                color: _isResizing
                    ? SpaceNotesTheme.primary
                    : SpaceNotesTheme.surface,
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
    final isChat = location == '/notes/chat';
    final isSettings = location == '/settings';

    return Column(
      children: [
        _DesktopTopBar(showTabs: !isChat && !isSettings),
        Expanded(
          child: _buildContent(context, isChat, isSettings),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isChat, bool isSettings) {
    if (isChat || isSettings) {
      return child;
    }
    return const DesktopNoteView();
  }
}

class _DesktopTopBar extends ConsumerWidget {
  final bool showTabs;

  const _DesktopTopBar({this.showTabs = false});

  String _getBreadcrumb(String location) {
    if (location.startsWith('/notes/note/')) {
      final encodedPath = location.substring('/notes/note/'.length);
      final decodedPath = Uri.decodeComponent(encodedPath);
      return '/$decodedPath';
    }
    if (location.startsWith('/notes/folder/')) {
      final encodedPath = location.substring('/notes/folder/'.length);
      final decodedPath = Uri.decodeComponent(encodedPath);
      return '/$decodedPath';
    }
    if (location == '/notes' || location == '/notes/') {
      return '/';
    }
    if (location == '/notes/chat') {
      return '/Chat';
    }
    return 'SpaceNotes';
  }

  bool _shouldShowBackButton(String location) {
    return location == '/notes/chat' || location == '/settings';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final breadcrumb = _getBreadcrumb(location);
    final showBack = _shouldShowBackButton(location);

    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.surface,
        border: Border(
          bottom: BorderSide(color: SpaceNotesTheme.inputSurface, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              color: SpaceNotesTheme.textSecondary,
              onPressed: () => context.go('/notes'),
              tooltip: 'Back to notes',
            )
          else if (showTabs)
            const Expanded(child: NoteTabs())
          else
            const SizedBox(width: 16),
          if (!showTabs)
            Expanded(
              child: Text(
                breadcrumb,
                style: SpaceNotesTextStyles.terminal.copyWith(
                  color: SpaceNotesTheme.textSecondary,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 18),
            color: SpaceNotesTheme.textSecondary,
            onPressed: () => context.go('/settings'),
            tooltip: 'Settings',
          ),
          const ConnectionIndicator(),
        ],
      ),
    );
  }
}

