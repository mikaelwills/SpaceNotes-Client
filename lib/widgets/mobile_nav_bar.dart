import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import '../theme/spacenotes_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_event.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_state.dart' as connection_states;
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../providers/notes_providers.dart';
import 'connection_indicator.dart';

class MobileNavBar extends ConsumerWidget {
  const MobileNavBar({super.key});

  void _onNewSessionPressed(BuildContext context) {
    context.read<ChatBloc>().add(ClearChat());
    final configState = context.read<ConfigCubit>().state;
    final defaultAgent =
        configState is ConfigLoaded ? configState.defaultAgent : null;
    context.read<SessionBloc>().add(CreateSession(agent: defaultAgent));
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

  String _extractNotePathFromLocation(String location) {
    // Route is /notes/note/:path(.*) - path spans from index 2 onwards
    final uri = Uri.parse(location);
    final pathSegments = uri.pathSegments;
    if (pathSegments.length >= 3 && pathSegments[1] == 'note') {
      // Join all segments after "note" to reconstruct the full path
      final notePathSegments = pathSegments.sublist(2);
      return notePathSegments.map(_safeDecodeUri).join('/');
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    final isOnNote = _isOnNoteScreen(currentLocation);

    return BlocBuilder<ConnectionBloc, connection_states.ConnectionState>(
      builder: (context, connectionState) {
        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                Expanded(
                  child: _EditableNoteName(
                    notePath: _extractNotePathFromLocation(currentLocation),
                    currentName: _extractNoteName(currentLocation),
                  ),
                ),
                const SizedBox(width: 16),
              ],

              if (currentLocation.startsWith('/notes/chat')) ...[
                GestureDetector(
                  onTap: () => context.go("/notes"),
                  child: const Icon(Icons.arrow_back,
                      color: SpaceNotesTheme.text),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _onNewSessionPressed(context),
                  child: const Icon(Icons.create_outlined,
                      color: SpaceNotesTheme.text),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => context.go("/notes/sessions"),
                  child: const Icon(Icons.list_outlined,
                      color: SpaceNotesTheme.text),
                ),
                const SizedBox(width: 20),
              ],

              if (currentLocation == '/notes/sessions') ...[
                GestureDetector(
                  onTap: () => context.go("/notes/chat"),
                  child: const Icon(Icons.arrow_back,
                      color: SpaceNotesTheme.text),
                ),
                const Spacer(),
              ],

              if (!isOnNote && !currentLocation.startsWith('/notes/chat') && currentLocation != '/notes/sessions' && currentLocation != '/settings') ...[
                GestureDetector(
                  onTap: () => context.go("/notes/chat"),
                  child: const Icon(Icons.chat_bubble_outline, color: SpaceNotesTheme.text),
                ),
                const SizedBox(width: 16),
              ],

              if (!currentLocation.startsWith('/notes/folder/') &&
                  !isOnNote &&
                  !currentLocation.startsWith('/notes/chat') &&
                  currentLocation != '/notes/sessions')
                const Spacer(),
              GestureDetector(
                onTap: () => context.go("/settings"),
                child: const Icon(Icons.settings, color: SpaceNotesTheme.text),
              ),
              const SizedBox(width: 16),
              const ConnectionIndicator(),
            ],
          ),
        );
      },
    );
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
      final folderPath = _safeDecodeUri(pathSegments[2]);
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
      final folderPath = _safeDecodeUri(pathSegments[2]);
      final folderName = folderPath.endsWith('/')
          ? folderPath.substring(0, folderPath.length - 1).split('/').last
          : folderPath.split('/').last;
      return folderName;
    }

    return 'Folder';
  }

  String _extractNoteName(String location) {
    final uri = Uri.parse(location);
    final pathSegments = uri.pathSegments;

    if (pathSegments.length >= 3 && pathSegments[1] == 'note') {
      final notePathSegments = pathSegments.sublist(2);
      final fileName = _safeDecodeUri(notePathSegments.last);
      final noteName = fileName.replaceAll('.md', '');
      return noteName;
    }

    return 'Note';
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
    if (_isEditing) {
      return TextField(
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
      );
    }

    return GestureDetector(
      onTap: _startEditing,
      child: Text(
        widget.currentName,
        style: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 16,
          color: SpaceNotesTheme.text,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
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
      if (mounted) {
        final encodedNewPath =
            newPath.split('/').map(Uri.encodeComponent).join('/');
        context.go('/notes/note/$encodedNewPath');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return TextField(
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
      );
    }

    return GestureDetector(
      onLongPress: _startEditing,
      child: Text(
        widget.currentName,
        style: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 16,
          color: SpaceNotesTheme.text,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

