import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';

class CredentialEntry {
  const CredentialEntry({required this.site, required this.account});

  final String site;
  final String account;

  static CredentialEntry fromPath(String path) {
    const storeRoot = '.password-store/';
    var relative = path;
    if (relative.startsWith(storeRoot)) {
      relative = relative.substring(storeRoot.length);
    }

    final segments = relative.split('/');
    final file = segments.isEmpty ? relative : segments.last;
    final account = file.endsWith('.gpg')
        ? file.substring(0, file.length - '.gpg'.length)
        : file;
    final site = segments.length > 1
        ? segments.sublist(0, segments.length - 1).join('/')
        : '';

    return CredentialEntry(site: site, account: account);
  }
}

class CredentialScreen extends ConsumerWidget {
  const CredentialScreen({super.key, required this.fileId});

  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(fileByIdProvider(fileId));

    if (file == null) {
      return const Scaffold(
        backgroundColor: SpaceNotesTheme.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final entry = CredentialEntry.fromPath(file.path);

    return Scaffold(
      backgroundColor: SpaceNotesTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.key_outlined,
                    color: SpaceNotesTheme.accent2,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.site,
                      style: const TextStyle(
                        color: SpaceNotesTheme.fg,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                entry.account,
                style: const TextStyle(
                  color: SpaceNotesTheme.muted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              const _NoKeyNotice(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoKeyNotice extends StatelessWidget {
  const _NoKeyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceNotesTheme.hairlineStrong),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No private key on this device',
            style: TextStyle(
              color: SpaceNotesTheme.fg,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Import a private key to reveal this password.',
            style: TextStyle(color: SpaceNotesTheme.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
