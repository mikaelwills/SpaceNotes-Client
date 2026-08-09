import 'package:flutter/material.dart';
import '../screens/note_screen.dart';
import 'file_type_handler.dart';

class MarkdownFileHandler extends FileTypeHandler {
  const MarkdownFileHandler();

  @override
  String get extension => 'md';

  @override
  IconData get icon => Icons.description_outlined;

  @override
  bool get isMovable => true;

  @override
  bool get isRenameable => true;

  @override
  bool get isEditable => true;

  @override
  bool get isDeletable => true;

  @override
  bool get hasTextRepresentation => true;

  @override
  NewFileTemplate? get newFileTemplate =>
      const NewFileTemplate(label: 'Note', extension: 'md');

  @override
  Widget buildScreen(String fileId) => NoteScreen(noteId: fileId);
}
