import 'package:flutter/material.dart';
import '../generated/space_file.dart';

class NewFileTemplate {
  const NewFileTemplate({
    required this.label,
    required this.extension,
    this.initialContent = '',
  });

  final String label;
  final String extension;
  final String initialContent;

  String defaultName() =>
      'Untitled-${DateTime.now().millisecondsSinceEpoch}.$extension';
}

abstract class FileTypeHandler {
  const FileTypeHandler();

  String get extension;

  IconData get icon;

  Color get color;

  bool get isRenameable;

  bool get isMovable;

  bool get isEditable;

  bool get isDeletable;

  bool get hasTextRepresentation;

  /// Whether this type is downloaded on demand and cached locally, so it can
  /// be offloaded to free device storage without losing the vault copy.
  bool get isOffloadable => false;

  NewFileTemplate? get newFileTemplate;

  bool get isCreatable => newFileTemplate != null;

  bool get hasContextActions => isMovable || isDeletable || isRenameable;

  String displayName(SpaceFile file) => stripExtension(file.name);

  Widget buildScreen(String fileId);

  String stripExtension(String name) {
    final suffix = '.$extension';
    return name.endsWith(suffix)
        ? name.substring(0, name.length - suffix.length)
        : name;
  }

  String applyExtension(String baseName) {
    if (extension.isEmpty) return baseName;
    final suffix = '.$extension';
    return baseName.endsWith(suffix) ? baseName : '$baseName$suffix';
  }
}
