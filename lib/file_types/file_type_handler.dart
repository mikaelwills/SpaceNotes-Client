import 'package:flutter/material.dart';
import '../generated/space_file.dart';
import '../platform/capabilities.dart';
import '../screens/unavailable_on_web_screen.dart';

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

  /// Whether this type can be opened on the current platform.
  ///
  /// Anything [isOffloadable] needs the download cache, so it follows
  /// [Capabilities.canDownloadFiles]. Derived rather than declared per type,
  /// so a new binary type can't forget to opt out.
  bool get isViewableHere => !isOffloadable || Capabilities.canDownloadFiles;

  NewFileTemplate? get newFileTemplate;

  bool get isCreatable => newFileTemplate != null;

  bool get hasContextActions => isMovable || isDeletable || isRenameable;

  String displayName(SpaceFile file) => stripExtension(file.name);

  /// The viewer for this type. Call [buildScreen] instead — it enforces the
  /// web gate so no caller or subclass has to remember.
  @protected
  Widget buildViewer(String fileId);

  /// Single enforcement point for [isSupportedOnWeb]. Every route to a file
  /// viewer goes through here, so an unsupported type degrades to an
  /// explanation instead of throwing on a missing plugin.
  Widget buildScreen(String fileId) {
    if (!isViewableHere) return const UnavailableOnWebScreen();
    return buildViewer(fileId);
  }

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
