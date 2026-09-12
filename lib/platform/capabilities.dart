import 'package:flutter/foundation.dart';

/// What this build of the client can actually do.
///
/// Every platform gate in the app is declared here and nowhere else. Widgets
/// ask a named capability (`Capabilities.canUploadFiles`), never `kIsWeb`
/// directly — so the reason for a gate lives with the gate, and adding a
/// platform later means changing this file rather than hunting call sites.
///
/// Full detail: `knowledge/web-vs-native.md`.
abstract final class Capabilities {
  /// Reading and writing files by path.
  ///
  /// The browser sandbox has no filesystem path: `path_provider` throws, and
  /// both `file_picker` and `desktop_drop` hand back a blob URL where native
  /// hands back a real path. Everything below follows from this one fact.
  static bool get hasFileSystem => !kIsWeb;

  /// Downloading a file and keeping it on the device.
  ///
  /// Needs the sqflite + path_provider cache in `LocalDownloadStore`.
  static bool get canDownloadFiles => hasFileSystem;

  /// Uploading files chosen from the device.
  ///
  /// `file_picker` runs on web, but `PlatformFile.path` is a blob URL there
  /// and the upload opens it with `File()`. Would need a bytes-based path.
  static bool get canUploadFiles => hasFileSystem;

  /// Dropping files onto the window from the OS.
  ///
  /// `desktop_drop` supports web, but `DropItem.path` is a blob URL there.
  static bool get canDropFiles => hasFileSystem;

  /// Playing audio, and the parametric EQ that rides on it.
  ///
  /// Both are native `MethodChannel` plugins with no web implementation.
  static bool get canPlayAudio => !kIsWeb;

  /// Microphone and camera capture for calls.
  static bool get canCapture => !kIsWeb;

  /// Offline cache that survives a restart.
  ///
  /// Web falls back to `InMemoryOfflineStorage`, so a refresh clears it.
  static bool get hasPersistentCache => hasFileSystem;
}
