import 'package:flutter/material.dart';
import '../screens/image_viewer_screen.dart';
import 'file_type_handler.dart';

class ImageFileHandler extends FileTypeHandler {
  const ImageFileHandler(this.extensionValue);

  final String extensionValue;

  @override
  String get extension => extensionValue;

  @override
  IconData get icon => Icons.image_outlined;

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
  Widget buildScreen(String fileId) => ImageViewerScreen(fileId: fileId);
}
