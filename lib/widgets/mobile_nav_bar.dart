import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import '../theme/spacenotes_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../providers/notes_providers.dart';
import 'connection_indicator.dart';
import 'sync_state_indicator.dart';

class MobileNavBar extends ConsumerWidget {
  const MobileNavBar({super.key});

  void _onNewSessionPressed(BuildContext context) {
    context.read<ChatBloc>().add(ClearChat());
  }

  bool _isOnNoteScreen(String location) {
    return location.startsWith('/notes/note/');
  }

  String _safeDecodeUri(String encoded) {
    try {
      return Uri.decodeComponent(encoded);
    } catch (e) {
      return encoded;
    }
  }

  String _extractNoteIdFromLocation(String location) {
    final uri = Uri.parse(location);
    final pathSegments = uri.pathSegments;
    if (pathSegments.length >= 3 && pathSegments[1] == 'note') {
      return pathSegments[2];
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    final isOnNote = _isOnNoteScreen(currentLocation);

    return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: SpaceNotesTheme.background,
          ),
          child: Row(
            children: [
              if (currentLocation == '/settings') ...[
                GestureDetector(
                  onTap: () => context.go("/notes"),
                  child:
                      const Icon(Icons.arrow_back, color: SpaceNotesTheme.text),
                ),
              ],

              if (currentLocation.startsWith('/notes/folder/')) ...[
                GestureDetector(
                  onTap: () => _navigateToParentFolder(context, _extractFullFolderPath(currentLocation)),
                  child: const Icon(Icons.arrow_back, color: SpaceNotesTheme.text),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _EditableFolderName(
                    folderPath: _extractFullFolderPath(currentLocation),
                    currentName: _extractFolderName(currentLocation),
                  ),
                ),
                const SizedBox(width: 16),
              ],

              if (isOnNote) ...[
                Builder(builder: (context) {
                  final noteId = _extractNoteIdFromLocation(currentLocation);
                  final note = ref.watch(notesListProvider).valueOrNull
                      ?.firstWhereOrNull((n) => n.id == noteId);
                  final notePath = note?.path ?? '';
                  return GestureDetector(
                    onTap: () => _navigateBackFromNote(context, notePath),
                    child: const Icon(Icons.arrow_back, color: SpaceNotesTheme.text),
                  );
                }),
                const SizedBox(width: 16),
                Expanded(
                  child: Builder(builder: (context) {
                    final noteId = _extractNoteIdFromLocation(currentLocation);
                    final note = ref.watch(notesListProvider).valueOrNull
                        ?.firstWhereOrNull((n) => n.id == noteId);
                    final notePath = note?.path ?? '';
                    final noteName = notePath.split('/').last.replaceAll('.md', '');
                    return _EditableNoteName(
                      notePath: notePath,
                      currentName: noteName,
                    );
                  }),
                ),
                const SizedBox(width: 16),
              ],

              if (!isOnNote && !currentLocation.startsWith('/notes/folder/') && currentLocation != '/settings')
                ..._buildNavIcons(context, currentLocation),

              if (!isOnNote && !currentLocation.startsWith('/notes/folder/') && !currentLocation.startsWith('/notes/chat'))
                const Expanded(
                  child: Center(
                    child: SyncStateIndicator(),
                  ),
                ),
              GestureDetector(
                onTap: () => context.go("/settings"),
                child: const Icon(Icons.settings, color: SpaceNotesTheme.text),
              ),
              const SizedBox(width: 16),
              const ConnectionIndicator(),
            ],
          ),
        );
  }

  static const _mainScreens = [
    ('/notes', Icons.notes, 'notes'),
    ('/notes/chat', Icons.chat_bubble_outline, 'chat'),
    ('/notes/sessions', Icons.terminal_outlined, 'sessions'),
    ('/notes/users', Icons.people_outline, 'calling'),
  ];

  String _currentScreen(String location) {
    if (location.startsWith('/notes/chat')) return '/notes/chat';
    if (location == '/notes/sessions') return '/notes/sessions';
    if (location == '/notes/users') return '/notes/users';
    return '/notes';
  }

  List<Widget> _buildNavIcons(BuildContext context, String location) {
    final current = _currentScreen(location);
    final icons = <Widget>[];
    for (final (route, icon, _) in _mainScreens) {
      final isActive = route == current;
      if (icons.isNotEmpty) icons.add(const SizedBox(width: 16));
      icons.add(
        GestureDetector(
          onTap: isActive ? null : () => context.go(route),
          child: Icon(icon, color: isActive ? SpaceNotesTheme.primary : SpaceNotesTheme.text),
        ),
      );
    }
    if (current == '/notes/chat') {
      icons.add(const Spacer());
      icons.add(
        GestureDetector(
          onTap: () => _onNewSessionPressed(context),
          child: const Icon(Icons.create_outlined, color: SpaceNotesTheme.text),
        ),
      );
      icons.add(const SizedBox(width: 4));
    }
    return icons;
  }

  void _navigateBackFromNote(BuildContext context, String notePath) {
    if (notePath.isEmpty) {
      context.go('/notes');
      return;
    }

    final lastSlash = notePath.lastIndexOf('/');
    if (lastSlash == -1) {
      context.go('/notes');
    } else {
      final folderPath = notePath.substring(0, lastSlash);
      final encodedPath = folderPath.split('/').map(Uri.encodeComponent).join('/');
      context.go('/notes/folder/$encodedPath');
    }
  }

  void _navigateToParentFolder(BuildContext context, String currentPath) {
    if (currentPath.isEmpty) {
      context.go('/notes');
      return;
    }

    final lastSlash = currentPath.lastIndexOf('/');
    if (lastSlash == -1) {
      context.go('/notes');
    } else {
      final parentPath = currentPath.substring(0, lastSlash);
      final encodedPath = parentPath.split('/').map(Uri.encodeComponent).join('/');
      context.go('/notes/folder/$encodedPath');
    }
  }

  String _extractFullFolderPath(String location) {
    final uri = Uri.parse(location);
    final pathSegments = uri.pathSegments;

    if (pathSegments.length >= 3 && pathSegments[1] == 'folder') {
      final folderPathSegments = pathSegments.sublist(2);
      final folderPath = folderPathSegments.map(_safeDecodeUri).join('/');
      return folderPath.endsWith('/')
          ? folderPath.substring(0, folderPath.length - 1)
          : folderPath;
    }

    return '';
  }

  String _extractFolderName(String location) {
    final uri = Uri.parse(location);
    final pathSegments = uri.pathSegments;

    if (pathSegments.length >= 3 && pathSegments[1] == 'folder') {
      final lastSegment = pathSegments.last;
      return _safeDecodeUri(lastSegment);
    }

    return 'Folder';
  }

}

class _EditableNoteName extends ConsumerStatefulWidget {
  final String notePath;
  final String currentName;

  const _EditableNoteName({
    required this.notePath,
    required this.currentName,
  });

  @override
  ConsumerState<_EditableNoteName> createState() => _EditableNoteNameState();
}

class _EditableNoteNameState extends ConsumerState<_EditableNoteName> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;
  Timer? _debounceTimer;
  String _lastRenamedTo = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _lastRenamedTo = widget.currentName;
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folderPath = _extractFolderPath();

    if (_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 16,
              color: SpaceNotesTheme.text,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onSubmitted: (_) => _performRename(),
          ),
          if (folderPath.isNotEmpty)
            Text(
              folderPath,
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 11,
                color: SpaceNotesTheme.text.withValues(alpha: 0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    }

    return GestureDetector(
      onTap: _startEditing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.currentName,
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 16,
              color: SpaceNotesTheme.text,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (folderPath.isNotEmpty)
            Text(
              folderPath,
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 11,
                color: SpaceNotesTheme.text.withValues(alpha: 0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  void _onTextChanged() {
    if (!_isEditing) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performRename();
    });
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _isEditing) {
      _debounceTimer?.cancel();
      _performRename();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = widget.currentName;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.currentName.length,
      );
    });
    _focusNode.requestFocus();
  }

  Future<void> _performRename() async {
    final newName = _controller.text.trim();

    if (newName.isEmpty || newName == _lastRenamedTo) {
      return;
    }

    final notesAsync = ref.read(notesListProvider);
    final note = notesAsync.valueOrNull
        ?.firstWhereOrNull((n) => n.path == widget.notePath);

    if (note == null) return;

    final folderPath = widget.notePath.contains('/')
        ? widget.notePath.substring(0, widget.notePath.lastIndexOf('/') + 1)
        : '';

    final newPath = '$folderPath$newName.md';

    if (newPath == widget.notePath) return;

    final repo = ref.read(notesRepositoryProvider);
    debugPrint('🏷️  RENAME: $newPath');
    final success = await repo.renameNote(note.id, newPath);

    if (success) {
      _lastRenamedTo = newName;
    }
  }

  String _extractFolderPath() {
    final lastSlash = widget.notePath.lastIndexOf('/');
    if (lastSlash == -1) return '';
    return widget.notePath.substring(0, lastSlash);
  }
}

class _EditableFolderName extends ConsumerStatefulWidget {
  final String folderPath;
  final String currentName;

  const _EditableFolderName({
    required this.folderPath,
    required this.currentName,
  });

  @override
  ConsumerState<_EditableFolderName> createState() =>
      _EditableFolderNameState();
}

class _EditableFolderNameState extends ConsumerState<_EditableFolderName> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentPath = _extractParentPath();

    if (_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 16,
              color: SpaceNotesTheme.text,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onSubmitted: (_) => _performRename(),
          ),
          if (parentPath.isNotEmpty)
            Text(
              parentPath,
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 11,
                color: SpaceNotesTheme.text.withValues(alpha: 0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    }

    return GestureDetector(
      onLongPress: _startEditing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.currentName,
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 16,
              color: SpaceNotesTheme.text,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (parentPath.isNotEmpty)
            Text(
              parentPath,
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 11,
                color: SpaceNotesTheme.text.withValues(alpha: 0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _isEditing) {
      _performRename();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = widget.currentName;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.currentName.length,
      );
    });
    _focusNode.requestFocus();
  }

  Future<void> _performRename() async {
    final newName = _controller.text.trim();

    setState(() {
      _isEditing = false;
    });

    if (newName.isEmpty || newName == widget.currentName) {
      return;
    }

    final parentPath = widget.folderPath.contains('/')
        ? widget.folderPath.substring(0, widget.folderPath.lastIndexOf('/') + 1)
        : '';
    final newFolderPath = '$parentPath$newName';

    final repo = ref.read(notesRepositoryProvider);
    debugPrint('🏷️  RENAME FOLDER: ${widget.folderPath} -> $newFolderPath');

    final success = await repo.moveFolder(widget.folderPath, newFolderPath);

    if (mounted && success) {
      final encodedNewPath = Uri.encodeComponent(newFolderPath);
      context.go('/notes/folder/$encodedNewPath');
    }
  }

  String _extractParentPath() {
    final lastSlash = widget.folderPath.lastIndexOf('/');
    if (lastSlash == -1) return '';
    return widget.folderPath.substring(0, lastSlash);
  }
}

