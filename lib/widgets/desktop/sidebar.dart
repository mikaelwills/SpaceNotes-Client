import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../../blocs/desktop_notes/desktop_notes_event.dart';
import '../../providers/notes_providers.dart';
import '../../providers/connection_providers.dart';
import '../../providers/favourite_folders_provider.dart';
import '../../providers/file_transfer_providers.dart';
import '../../providers/middle_pane_mode_provider.dart';
import '../../providers/upload_progress_providers.dart';
import '../../providers/window_state_provider.dart';
import '../folder_picker_field.dart';
import '../../services/debug_logger.dart';
import '../../services/file_transfer_service.dart';
import '../upload_progress_bar.dart';
import '../../theme/spacenotes_theme.dart';
import '../../version.dart';
import '../primitives/primitives.dart';
import 'desktop_shell.dart';
import '../../file_types/file_type_registry.dart';

final searchFocusRequestProvider = StateProvider<int>((ref) => 0);

void _ensureNotesView(BuildContext context) {
  final location = GoRouterState.of(context).uri.toString();
  if (location.startsWith('/agents') ||
      location.startsWith('/settings') ||
      location.startsWith('/connect')) {
    context.go('/notes');
  }
}

void _openNoteInDesktop(
  BuildContext context,
  WidgetRef ref,
  String noteId, {
  required String parentFolderPath,
}) {
  context
      .read<DesktopNotesBloc>()
      .add(OpenNote(noteId, parentFolderPath: parentFolderPath));
  ref.read(middlePaneModeProvider.notifier).state =
      MiddlePaneMode.fileViewer(noteId);
  _ensureNotesView(context);
}

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
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: SpaceNotesTheme.bgAlt,
            borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
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
      _ensureNotesView(context);
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
          _ensureNotesView(context);
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
          _CollapsedIconButton(
            icon: Icons.search,
            tooltip: 'Search',
            onTap: () {
              ref.read(sidebarCollapsedProvider.notifier).state = false;
              ref.read(searchFocusRequestProvider.notifier).state++;
            },
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
                icon: const Icon(Icons.post_add_outlined),
                onPressed: () => _createNote(context, ref),
                tooltip: 'new note',
              ),
              const SizedBox(width: 4),
              SnIconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: () => _createFolder(context, ref),
                tooltip: 'new folder',
              ),
              const SizedBox(width: 4),
              SnIconButton(
                icon: const Icon(Icons.cloud_upload_outlined),
                onPressed: () => _uploadFiles(context, ref),
                tooltip: 'upload files',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SnIconButton(
                icon: const Icon(Icons.notes_outlined),
                onPressed: onNotes ? null : () => context.go('/notes'),
                active: onNotes,
                tooltip: 'notes',
              ),
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

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(notesRepositoryProvider);
    final notePath = 'All Notes/${FileTypeRegistry.defaultNewFileName()}';
    final noteId = await repo.createNote(notePath, '');
    if (noteId != null && context.mounted) {
      _openNoteInDesktop(context, ref, noteId, parentFolderPath: 'All Notes');
    }
  }

  Future<void> _uploadFiles(BuildContext context, WidgetRef ref) async {
    final target = await pickUploadTarget(
      context,
      ref,
      currentFolder: 'All Notes',
      showFolderOption: true,
    );
    if (target == null || !context.mounted) return;

    final repo = ref.read(notesRepositoryProvider);
    await repo.createFolder(target.folder);
    if (!context.mounted) return;
    final targetFolder = target.folder;

    if (target.kind == UploadSourceKind.folder) {
      await _uploadFolder(context, ref, targetFolder);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: target.source!,
    );
    if (result == null || result.files.isEmpty) {
      debugLogger.info('UPLOAD', 'File picker cancelled or empty selection');
      return;
    }
    debugLogger.info(
      'UPLOAD',
      'Files selected',
      'count=${result.files.length} folder=$targetFolder',
    );

    if (!context.mounted) return;
    final service = ref.read(fileTransferServiceProvider);
    final batch = ref.read(uploadBatchProvider.notifier);
    final uploadable = result.files.where((f) => f.path != null).toList();

    if (uploadable.length == 1) {
      await _uploadSingleWithCollisionDialog(
        context,
        service,
        batch,
        targetFolder,
        uploadable.first,
      );
      return;
    }

    final jobIds = {
      for (final picked in uploadable)
        picked: '${DateTime.now().microsecondsSinceEpoch}_${picked.name}',
    };
    batch.startBatch([
      for (final picked in uploadable)
        (id: jobIds[picked]!, fileName: picked.name)
    ]);

    final skipped = <String>[];
    for (final picked in uploadable) {
      final path = picked.path!;
      final jobId = jobIds[picked]!;
      try {
        await service.uploadFile(
          targetFolder,
          File(path),
          onProgress: (sent, total) {
            if (total > 0) {
              batch.progress(jobId, sent / total,
                  sentBytes: sent, totalBytes: total);
            }
          },
        );
        batch.complete(jobId);
      } on FileAlreadyExistsException {
        skipped.add(picked.name);
        batch.fail(jobId, 'already exists');
      } catch (e) {
        debugLogger.error(
            'UPLOAD', 'Error uploading ${picked.name}', e.toString());
        batch.fail(jobId, e.toString());
      }
    }
    batch.finishBatch();
    if (skipped.isNotEmpty && context.mounted) {
      _showSkippedDialog(context, skipped);
    }
  }

  Future<void> _uploadSingleWithCollisionDialog(
    BuildContext context,
    FileTransferService service,
    UploadBatchNotifier batch,
    String targetFolder,
    PlatformFile picked,
  ) async {
    final path = picked.path!;
    final jobId = '${DateTime.now().microsecondsSinceEpoch}_${picked.name}';

    batch.startBatch([(id: jobId, fileName: picked.name)]);
    try {
      await service.uploadFile(
        targetFolder,
        File(path),
        onProgress: (sent, total) {
          if (total > 0) {
            batch.progress(jobId, sent / total,
                sentBytes: sent, totalBytes: total);
          }
        },
      );
      batch.complete(jobId);
      batch.finishBatch();
    } on FileAlreadyExistsException {
      batch.finishBatch();
      if (!context.mounted) return;
      await _showAlreadyExistsDialog(context, picked.name, targetFolder);
    } catch (e) {
      debugLogger.error(
          'UPLOAD', 'Error uploading ${picked.name}', e.toString());
      batch.fail(jobId, e.toString());
      batch.finishBatch();
    }
  }

  Future<void> _showAlreadyExistsDialog(
    BuildContext context,
    String fileName,
    String folderName,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => SnDialog(
        title: 'File already exists',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 15,
                color: SpaceNotesTheme.fg,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'already exists in $folderName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 13,
                color: SpaceNotesTheme.muted,
              ),
            ),
          ],
        ),
        actions: [
          SnDialogAction(
            label: 'OK',
            variant: SnButtonVariant.outline,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadFolder(
    BuildContext context,
    WidgetRef ref,
    String targetFolder,
  ) async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null || !context.mounted) {
      debugLogger.info('UPLOAD', 'Folder picker cancelled');
      return;
    }

    final rootDir = Directory(dirPath);
    final rootName = rootDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final entries =
        rootDir.listSync(recursive: true).whereType<File>().toList();
    debugLogger.info(
      'UPLOAD',
      'Folder selected',
      'root=$rootName files=${entries.length} target=$targetFolder',
    );

    final repo = ref.read(notesRepositoryProvider);
    final service = ref.read(fileTransferServiceProvider);
    final batch = ref.read(uploadBatchProvider.notifier);
    final createdFolders = <String>{};
    final skipped = <String>[];

    final jobIds = {
      for (final file in entries)
        file:
            '${DateTime.now().microsecondsSinceEpoch}_${file.uri.pathSegments.last}',
    };
    batch.startBatch([
      for (final file in entries)
        (id: jobIds[file]!, fileName: file.uri.pathSegments.last)
    ]);

    for (final file in entries) {
      final relative = file.path.substring(rootDir.path.length + 1);
      final relativeDir = relative.contains('/')
          ? relative.substring(0, relative.lastIndexOf('/'))
          : '';
      final vaultFolder = relativeDir.isEmpty
          ? '$targetFolder/$rootName'
          : '$targetFolder/$rootName/$relativeDir';

      if (createdFolders.add(vaultFolder)) {
        await repo.createFolder(vaultFolder);
      }

      final jobId = jobIds[file]!;
      try {
        await service.uploadFile(
          vaultFolder,
          file,
          onProgress: (sent, total) {
            if (total > 0) {
              batch.progress(jobId, sent / total,
                  sentBytes: sent, totalBytes: total);
            }
          },
        );
        batch.complete(jobId);
      } on FileAlreadyExistsException {
        skipped.add('$vaultFolder/${file.uri.pathSegments.last}');
        batch.fail(jobId, 'already exists');
      } catch (e) {
        debugLogger.error(
            'UPLOAD', 'Error uploading ${file.path}', e.toString());
        batch.fail(jobId, e.toString());
      }
    }
    batch.finishBatch();

    if (skipped.isNotEmpty && context.mounted) {
      _showSkippedDialog(context, skipped);
    }
  }

  void _showSkippedDialog(BuildContext context, List<String> skipped) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SnDialog(
        title: 'Some files already existed',
        content: Text(
          '${skipped.length} file(s) were skipped because they already exist:\n\n${skipped.join('\n')}',
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontSans,
            fontSize: 13,
            color: SpaceNotesTheme.fg,
          ),
        ),
        actions: [
          SnDialogAction(
            label: 'OK',
            variant: SnButtonVariant.outline,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: SpaceNotesTextStyles.terminal,
          decoration: const InputDecoration(
            hintText: 'Folder name',
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: SpaceNotesTextStyles.terminal
                    .copyWith(color: SpaceNotesTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text('Create',
                style: SpaceNotesTextStyles.terminal
                    .copyWith(color: SpaceNotesTheme.primary)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      final folders = ref.read(foldersListProvider);
      final existingFolder = folders.any((f) => f.path == result);
      if (existingFolder) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Folder Exists'),
              content: Text(
                'A folder named "$result" already exists.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('OK',
                      style: SpaceNotesTextStyles.terminal
                          .copyWith(color: SpaceNotesTheme.primary)),
                ),
              ],
            ),
          );
        }
      } else {
        final repo = ref.read(notesRepositoryProvider);
        await repo.createFolder(result);
      }
    }
  }
}
