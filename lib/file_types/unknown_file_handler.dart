import 'package:flutter/material.dart';
import '../generated/space_file.dart';
import '../screens/unsupported_file_screen.dart';
import '../theme/spacenotes_theme.dart';
import 'file_type_handler.dart';

class UnknownFileHandler extends FileTypeHandler {
  const UnknownFileHandler();

  @override
  String get extension => '';

  @override
  IconData get icon => Icons.insert_drive_file_outlined;

  @override
  Color get color => SpaceNotesTheme.dim;

  @override
  bool get isOffloadable => true;

  @override
  bool get isMovable => true;

  @override
  bool get isRenameable => false;

  @override
  bool get isEditable => false;

  @override
  bool get isDeletable => true;

  @override
  bool get hasTextRepresentation => false;

  @override
  NewFileTemplate? get newFileTemplate => null;

  @override
  String displayName(SpaceFile file) => file.name;

  @override
  Widget buildScreen(String fileId) => UnsupportedFileScreen(fileId: fileId);
}
