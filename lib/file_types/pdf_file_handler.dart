import 'package:flutter/material.dart';
import '../screens/unsupported_file_screen.dart';
import 'file_type_handler.dart';

class PdfFileHandler extends FileTypeHandler {
  const PdfFileHandler();

  @override
  String get extension => 'pdf';

  @override
  IconData get icon => Icons.picture_as_pdf_outlined;

  @override
  Color get color => const Color(0xFFE0836E);

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
  Widget buildViewer(String fileId) => UnsupportedFileScreen(fileId: fileId);
}
