import 'package:flutter/material.dart';
import '../screens/credential_screen.dart';
import '../theme/spacenotes_theme.dart';
import 'file_type_handler.dart';

class CredentialFileHandler extends FileTypeHandler {
  const CredentialFileHandler();

  @override
  String get extension => 'gpg';

  @override
  IconData get icon => Icons.key_outlined;

  @override
  Color get color => SpaceNotesTheme.warning;

  @override
  bool get isMovable => false;

  @override
  bool get isRenameable => false;

  @override
  bool get isEditable => false;

  @override
  bool get isDeletable => false;

  @override
  bool get hasTextRepresentation => false;

  @override
  NewFileTemplate? get newFileTemplate => null;

  @override
  Widget buildScreen(String fileId) => CredentialScreen(fileId: fileId);
}
