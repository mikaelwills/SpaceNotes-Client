import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../file_types/file_type_registry.dart';

class EditableNoteName extends ConsumerStatefulWidget {
  final String notePath;
  final String currentName;
  final bool isRenameable;

  const EditableNoteName({
    super.key,
    required this.notePath,
    required this.currentName,
    required this.isRenameable,
  });

  @override
  ConsumerState<EditableNoteName> createState() => EditableNoteNameState();
}

class EditableNoteNameState extends ConsumerState<EditableNoteName> {
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
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 10,
          color: SpaceNotesTheme.fg,
          letterSpacing: 0.5,
        ),
        cursorColor: SpaceNotesTheme.accent,
        cursorWidth: 1.5,
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
      onTap: widget.isRenameable ? _startEditing : null,
      child: Text(
        widget.currentName,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 10,
          color: SpaceNotesTheme.fg,
          letterSpacing: 0.5,
        ),
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
    if (!widget.isRenameable) return;
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

    final notes = ref.read(fileListProvider);
    final note = notes.firstWhereOrNull((n) => n.path == widget.notePath);

    if (note == null) return;
    if (!FileTypeRegistry.forFile(note).isRenameable) return;

    final folderPath = widget.notePath.contains('/')
        ? widget.notePath.substring(0, widget.notePath.lastIndexOf('/') + 1)
        : '';

    final newPath =
        '$folderPath${FileTypeRegistry.forFile(note).applyExtension(newName)}';

    if (newPath == widget.notePath) return;

    final repo = ref.read(notesRepositoryProvider);
    debugPrint('🏷️  RENAME: $newPath');
    final success = await repo.renameNote(note.id, newPath);

    if (success) {
      _lastRenamedTo = newName;
    }
  }

}

class EditableFolderName extends ConsumerStatefulWidget {
  final String folderPath;
  final String currentName;

  const EditableFolderName({
    super.key,
    required this.folderPath,
    required this.currentName,
  });

  @override
  ConsumerState<EditableFolderName> createState() =>
      EditableFolderNameState();
}

class EditableFolderNameState extends ConsumerState<EditableFolderName> {
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
    if (_isEditing) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 10,
          color: SpaceNotesTheme.fg,
          letterSpacing: 0.5,
        ),
        cursorColor: SpaceNotesTheme.accent,
        cursorWidth: 1.5,
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
      onTap: FileTypeRegistry.isProtectedPath(widget.folderPath)
          ? null
          : _startEditing,
      child: Text(
        widget.currentName,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 10,
          color: SpaceNotesTheme.fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _isEditing) {
      _performRename();
    }
  }

  void _startEditing() {
    if (FileTypeRegistry.isProtectedPath(widget.folderPath)) return;
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

    if (FileTypeRegistry.isProtectedPath(widget.folderPath)) return;

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

}
