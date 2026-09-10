import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../actions/note_actions.dart';
import '../../providers/notes_providers.dart';
import '../../providers/connection_providers.dart';
import '../../providers/favourite_folders_provider.dart';
import '../../providers/middle_pane_mode_provider.dart';
import '../../providers/window_state_provider.dart';
import '../upload_progress_bar.dart';
import '../../theme/spacenotes_theme.dart';
import '../../version.dart';
import '../primitives/primitives.dart';
import 'desktop_shell.dart';
import '../../providers/preferences_provider.dart';

final searchFocusRequestProvider = StateProvider<int>((ref) => 0);

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final isFullScreen = ref.watch(isFullScreenProvider);
    final needsTrafficLightClearance =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS && !isFullScreen;

    return Container(
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.bgAlt,
        border: Border(
          right: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (needsTrafficLightClearance) const SizedBox(height: 26),
          _SidebarHeader(isCollapsed: isCollapsed),
          if (!isCollapsed) ...[
            const Expanded(child: _FavouritesList()),
            const _SidebarSearch(),
            const UploadProgressBar(),
            const _SidebarFooter(),
          ] else
            Expanded(child: _CollapsedSidebar()),
        ],
      ),
    );
  }
}

class _SidebarHeader extends ConsumerWidget {
  final bool isCollapsed;

  const _SidebarHeader({required this.isCollapsed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isCollapsed) {
      return Container(
        height: 52,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
          ),
        ),
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref.read(sidebarCollapsedProvider.notifier).state = false;
            },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                '›',
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

    final isConnected = ref.watch(spacetimeConnectedProvider);
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: SpaceNotesTheme.fontSans,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: SpaceNotesTheme.fg,
                    letterSpacing: -0.3,
                    height: 1,
                  ),
                  children: [
                    TextSpan(text: 'Space'),
                    TextSpan(
                      text: 'Notes',
                      style: TextStyle(color: SpaceNotesTheme.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 1),
                child: Text(
                  appVersion == 'latest' ? appVersion : 'v$appVersion',
                  style: TextStyle(
                    fontFamily: SpaceNotesTheme.fontMono,
                    fontSize: 10,
                    color: SpaceNotesTheme.dim,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SnSyncDot(
                state: isConnected ? SnSyncState.synced : SnSyncState.offline,
                label: isConnected ? 'synced' : 'offline',
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.read(sidebarCollapsedProvider.notifier).state = true;
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
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
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarSearch extends ConsumerStatefulWidget {
  const _SidebarSearch();

  @override
  ConsumerState<_SidebarSearch> createState() => _SidebarSearchState();
}

class _SidebarSearchState extends ConsumerState<_SidebarSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _previousFolderPath = '';

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(folderSearchQueryProvider);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(folderSearchQueryProvider);
    final hasQuery = searchQuery.isNotEmpty;

    ref.listen<int>(searchFocusRequestProvider, (previous, next) {
      if (previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
      }
    });

    ref.listen<String>(folderSearchQueryProvider, (previous, next) {
      if (next.isEmpty && _controller.text.isNotEmpty) {
        _controller.clear();
      }
    });

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: SpaceNotesTheme.bgAlt,
            borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.search,
                size: 18,
                color:
                    hasQuery ? SpaceNotesTheme.accent : SpaceNotesTheme.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Center(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontSans,
                      fontSize: 15,
                      color: SpaceNotesTheme.fg,
                      height: 1.0,
                    ),
                    cursorColor: SpaceNotesTheme.accent,
                    cursorWidth: 1.5,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'search…',
                      hintStyle: TextStyle(
                        fontFamily: SpaceNotesTheme.fontMono,
                        fontSize: 13,
                        color: SpaceNotesTheme.dim,
                        letterSpacing: 0.3,
                        height: 1.0,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
              ),
              if (hasQuery) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearSearch,
                  behavior: HitTestBehavior.opaque,
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: SpaceNotesTheme.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    final wasEmpty = ref.read(folderSearchQueryProvider).isEmpty;

    if (wasEmpty && value.isNotEmpty) {
      final mode = ref.read(middlePaneModeProvider);
      _previousFolderPath = mode is BrowseMode ? mode.folderPath : '';
      ref.read(middlePaneModeProvider.notifier).state =
          MiddlePaneMode.searchResults(_previousFolderPath);
      ensureNotesView(context);
    } else if (value.isEmpty) {
      _restoreBrowseAfterSearch();
    }

    ref.read(folderSearchQueryProvider.notifier).state = value;
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(folderSearchQueryProvider.notifier).state = '';
    _focusNode.unfocus();
    _restoreBrowseAfterSearch();
  }

  void _restoreBrowseAfterSearch() {
    if (ref.read(middlePaneModeProvider) is SearchResultsMode) {
      ref.read(middlePaneModeProvider.notifier).state =
          MiddlePaneMode.browse(_previousFolderPath);
    }
  }
}

class _FavouritesList extends ConsumerWidget {
  const _FavouritesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(favouriteFoldersProvider);

    ref.listen(foldersListProvider, (previous, next) {
      final existingPaths = next.map((f) => f.path).toSet();
      ref
          .read(favouriteFoldersProvider.notifier)
          .syncWithExistingPaths(existingPaths);
    });

    if (favourites.isEmpty) {
      return const SizedBox.shrink();
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      buildDefaultDragHandles: false,
      itemCount: favourites.length,
      onReorderItem: (oldIndex, newIndex) {
        ref.read(favouriteFoldersProvider.notifier).reorder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final path = favourites[index];
        return ReorderableDragStartListener(
          key: ValueKey(path),
          index: index,
          child: _FavouriteTreeItem(path: path),
        );
      },
    );
  }
}

class _FavouriteTreeItem extends ConsumerStatefulWidget {
  final String path;

  const _FavouriteTreeItem({required this.path});

  @override
  ConsumerState<_FavouriteTreeItem> createState() => _FavouriteTreeItemState();
}

class _FavouriteTreeItemState extends ConsumerState<_FavouriteTreeItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final name =
        widget.path.contains('/') ? widget.path.split('/').last : widget.path;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(middlePaneModeProvider.notifier).state =
              MiddlePaneMode.browse(widget.path);
          ensureNotesView(context);
        },
        child: Container(
          height: 32,
          color: _isHovered
              ? SpaceNotesTheme.fg.withValues(alpha: 0.03)
              : Colors.transparent,
          padding: const EdgeInsets.only(left: 12, right: 12),
          child: Row(
            children: [
              const Icon(
                Icons.folder_outlined,
                size: 14,
                color: SpaceNotesTheme.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: SpaceNotesTheme.fontSans,
                    fontSize: 13,
                    color: SpaceNotesTheme.muted,
                    letterSpacing: -0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsedSidebar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _CollapsedIconButton(
            icon: Icons.folder,
            tooltip: 'Notes',
            onTap: () => context.go('/notes'),
          ),
          if (ref.watch(agentsEnabledProvider)) ...[
            _CollapsedIconButton(
              icon: Icons.chat_bubble_outline,
              tooltip: 'Chat',
              onTap: () => context.go('/agents/chat'),
            ),
            _CollapsedIconButton(
              icon: Icons.terminal_outlined,
              tooltip: 'Agents',
              onTap: () => context.go('/agents'),
            ),
          ],
          _CollapsedIconButton(
            icon: Icons.search,
            tooltip: 'Search',
            onTap: () {
              ref.read(sidebarCollapsedProvider.notifier).state = false;
              ref.read(searchFocusRequestProvider.notifier).state++;
            },
          ),
          _CollapsedIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }
}

class _CollapsedIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CollapsedIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_CollapsedIconButton> createState() => _CollapsedIconButtonState();
}

class _CollapsedIconButtonState extends State<_CollapsedIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: _isHovered
                  ? SpaceNotesTheme.inputSurface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: SpaceNotesTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends ConsumerWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final onChat = location.startsWith('/agents/chat');
    final onAgents = location.startsWith('/agents') && !onChat;
    final onPasswords = location.startsWith('/notes/passwords');
    final onSettings = location == '/settings';
    final onNotes = !onChat && !onAgents && !onSettings;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SnIconButton(
                icon: const Icon(Icons.notes_outlined),
                onPressed: onNotes ? null : () => context.go('/notes'),
                active: onNotes,
                tooltip: 'notes',
              ),
              if (ref.watch(agentsEnabledProvider)) ...[
                const SizedBox(width: 4),
                SnIconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: onChat ? null : () => context.go('/agents/chat'),
                  active: onChat,
                  tooltip: 'chat',
                ),
                const SizedBox(width: 4),
                SnIconButton(
                  icon: const Icon(Icons.terminal_outlined),
                  onPressed: onAgents ? null : () => context.go('/agents'),
                  active: onAgents,
                  tooltip: 'agents',
                ),
              ],
              const SizedBox(width: 4),
              SnIconButton(
                icon: const Icon(Icons.key_outlined),
                onPressed:
                    onPasswords ? null : () => context.go('/notes/passwords'),
                active: onPasswords,
                tooltip: 'passwords',
              ),
              const Spacer(),
              SnIconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: onSettings ? null : () => context.go('/settings'),
                active: onSettings,
                tooltip: 'settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
