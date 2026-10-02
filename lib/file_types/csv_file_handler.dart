import 'package:flutter/material.dart';
import '../screens/unsupported_file_screen.dart';
import 'file_type_handler.dart';

class CsvFileHandler extends FileTypeHandler {
  const CsvFileHandler();

  @override
  String get extension => 'csv';

  @override
  IconData get icon => Icons.table_chart_outlined;

  @override
  Color get color => const Color(0xFF8FCB9B);

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
