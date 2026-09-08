import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import '../providers/notes_providers.dart';
import '../router/app_router.dart';

void registerSpaceNotesMarionetteExtensions(ProviderContainer container) {
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
      });
    },
  );
}
