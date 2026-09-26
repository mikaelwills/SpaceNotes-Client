import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import '../providers/notes_providers.dart';
import '../router/app_router.dart';

bool _isModalOpen(GoRouter router) => ModalTracker.isModalOpen;

String? _focusedFieldText() {
  final focused = FocusManager.instance.primaryFocus;
  if (focused == null) return null;

  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return null;

  EditableTextState? found;
  void visit(Element element) {
    if (found != null) return;
    if (element is StatefulElement && element.state is EditableTextState) {
      final state = element.state as EditableTextState;
      if (state.widget.focusNode == focused) {
        found = state;
        return;
      }
    }
    element.visitChildren(visit);
  }

  visit(root);
  final state = found;
  if (state == null) return null;
  return state.textEditingValue.text;
}

void registerSpaceNotesMarionetteExtensions(ProviderContainer container) {
  registerMarionetteExtension(
    name: 'dismissKeyboard',
    description: 'Unfocus any focused text field and hide the soft keyboard.',
    callback: (_) async {
      final focused = FocusManager.instance.primaryFocus;
      focused?.unfocus();
      return MarionetteExtensionResult.success({
        'wasFocused': focused != null,
      });
    },
  );

  registerMarionetteExtension(
    name: 'whereAmI',
    description:
        'Current screen: route location, and the note or folder path when on one.',
    callback: (_) async {
      final router = appRouter;
      if (router == null) {
        return const MarionetteExtensionResult.error(
          1,
          'Router not initialised',
        );
      }

      final location =
          router.routerDelegate.currentConfiguration.uri.toString();
      final segments = Uri.parse(location).pathSegments;

      var screen = segments.isEmpty ? 'root' : segments.join('/');
      String? notePath;
      String? folderPath;

      if (segments.length >= 3 && segments[1] == 'note') {
        screen = 'note';
        final id = segments[2];
        final file = container
            .read(fileListProvider)
            .where((f) => f.id == id)
            .firstOrNull;
        notePath = file?.path;
      } else if (segments.length >= 3 && segments[1] == 'folder') {
        screen = 'folder';
        folderPath = Uri.decodeComponent(segments.sublist(2).join('/'));
      }

      return MarionetteExtensionResult.success({
        'screen': screen,
        'location': location,
        if (notePath != null) 'notePath': notePath,
        if (folderPath != null) 'folderPath': folderPath,
        'modalOpen': _isModalOpen(router),
        'keyboardUp': _focusedFieldText() != null,
        'focusedField': _focusedFieldText() ?? '',
      });
    },
  );

  registerMarionetteExtension(
    name: 'setWindowSize',
    description:
        'Desktop only: resize the app window, e.g. width=1400 height=900 for the desktop layout.',
    callback: (params) async {
      if (kIsWeb || !(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
        return const MarionetteExtensionResult.error(1, 'Not a desktop app');
      }
      final width = double.tryParse(params['width'] ?? '');
      final height = double.tryParse(params['height'] ?? '');
      if (width == null || height == null) {
        return const MarionetteExtensionResult.error(2, 'width and height are required');
      }
      await windowManager.setSize(Size(width, height));
      return MarionetteExtensionResult.success({'width': width, 'height': height});
    },
  );
}
