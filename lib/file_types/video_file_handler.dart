import 'package:flutter/material.dart';
import '../screens/video_viewer_screen.dart';
import 'file_type_handler.dart';

class VideoFileHandler extends FileTypeHandler {
  const VideoFileHandler(this.extensionValue);

  final String extensionValue;

  @override
  String get extension => extensionValue;

  @override
  IconData get icon => Icons.videocam_outlined;

  @override
  Color get color => const Color(0xFFE8A2C4);

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
  bool get hasTextRepresentation => false;

  @override
  NewFileTemplate? get newFileTemplate => null;

  @override
  Widget buildScreen(String fileId) => VideoViewerScreen(fileId: fileId);
}
