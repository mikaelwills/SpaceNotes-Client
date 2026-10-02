import 'package:flutter/material.dart';
import '../screens/audio_viewer_screen.dart';
import '../theme/spacenotes_theme.dart';
import 'file_type_handler.dart';

class AudioFileHandler extends FileTypeHandler {
  const AudioFileHandler(this.extensionValue);

  final String extensionValue;

  @override
  String get extension => extensionValue;

  @override
  IconData get icon => Icons.music_note_outlined;

  @override
  Color get color => SpaceNotesTheme.accent;

  @override
  bool get isOffloadable => true;

  @override
  bool get isMovable => true;

  @override
  bool get isRenameable => true;

  @override
  bool get isEditable => false;

  @override
  bool get isDeletable => true;

  @override
  bool get hostsMobileDock => true;

  @override
  bool get hasTextRepresentation => false;

  @override
  NewFileTemplate? get newFileTemplate => null;

  @override
  Widget buildViewer(String fileId) => AudioViewerScreen(fileId: fileId);
}
