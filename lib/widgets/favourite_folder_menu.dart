import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../file_types/file_type_registry.dart';
import '../generated/folder.dart';
import '../providers/favourite_folders_provider.dart';
import '../theme/spacenotes_theme.dart';

class FavouriteFolderMenu {
  static const _toggleValue = 'favourite';

  static List<PopupMenuEntry<String>>? items(WidgetRef ref, Folder folder) {
    if (FileTypeRegistry.isProtectedPath(folder.path)) return null;
    final isFavourited =
        ref.watch(favouriteFoldersProvider).contains(folder.path);
    return [
      PopupMenuItem<String>(
        value: _toggleValue,
        height: 36,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFavourited ? Icons.star : Icons.star_border,
              size: 15,
              color: isFavourited
                  ? SpaceNotesTheme.accent
                  : SpaceNotesTheme.dim,
            ),
            const SizedBox(width: 10),
            Text(
              isFavourited ? 'Remove from Favourites' : 'Favourite',
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 13,
                color: SpaceNotesTheme.fg,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  static void Function(String value)? onSelected(WidgetRef ref, Folder folder) {
    if (FileTypeRegistry.isProtectedPath(folder.path)) return null;
    return (value) {
      final notifier = ref.read(favouriteFoldersProvider.notifier);
      if (ref.read(favouriteFoldersProvider).contains(folder.path)) {
        notifier.remove(folder.path);
      } else {
        notifier.add(folder.path);
      }
    };
  }
}
