import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/middle_pane_mode_provider.dart';
import '../providers/notes_providers.dart';
import '../services/debug_logger.dart';
import '../services/vault_link.dart';
import '../widgets/adaptive/platform_utils.dart';
import 'note_actions.dart';

class VaultLinkReturn {
  const VaultLinkReturn({required this.opened, required this.returnTo});
  final String opened;
  final String returnTo;
}

final vaultLinkReturnProvider = StateProvider<VaultLinkReturn?>((ref) => null);

void _goFromLink(BuildContext context, WidgetRef ref, String target) {
  final from = GoRouterState.of(context).uri.toString();
  ref.read(vaultLinkReturnProvider.notifier).state =
      VaultLinkReturn(opened: target, returnTo: from);
  context.go(target);
}

bool returnFromVaultLink(BuildContext context, WidgetRef ref) {
  final pending = ref.read(vaultLinkReturnProvider);
  if (pending == null) return false;
  ref.read(vaultLinkReturnProvider.notifier).state = null;
  if (GoRouterState.of(context).uri.toString() != pending.opened) return false;
  context.go(pending.returnTo);
  return true;
}

Future<void> openVaultLink(BuildContext context, WidgetRef ref, String href) async {
  debugLogger.info('VAULT_LINK', 'Tapped', href);
  final isDesktop = PlatformUtils.isDesktopLayout(context);

  switch (parseVaultLink(href)) {
    case FileLink(:final id):
      final file = ref.read(fileByIdProvider(id));
      if (file == null) return _showNotice(context, 'File not found');
      if (isDesktop) {
        openNoteInDesktop(
          context,
          ref,
          id,
          parentFolderPath: _withoutTrailingSlash(file.folderPath),
        );
      } else {
        _goFromLink(context, ref, '/notes/note/$id');
      }
    case FolderLink(:final path):
      final exists = ref.read(foldersListProvider).any((f) => f.path == path);
      if (!exists) return _showNotice(context, 'Folder not found');
      if (isDesktop) {
        ref.read(middlePaneModeProvider.notifier).state =
            MiddlePaneMode.browse(path);
        ensureNotesView(context);
      } else {
        final encoded = path.split('/').map(Uri.encodeComponent).join('/');
        _goFromLink(context, ref, '/notes/folder/$encoded');
      }
    case WebLink(:final uri):
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) _showNotice(context, 'Could not open link');
    case UnknownLink():
      _showNotice(context, 'Link not recognised');
  }
}

String _withoutTrailingSlash(String path) =>
    path.endsWith('/') ? path.substring(0, path.length - 1) : path;

void _showNotice(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );
}
