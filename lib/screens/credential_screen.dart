import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';

enum CredentialState { noKey, keyCannotRead, notEncryptedToDevice, revealed }

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
    const state = CredentialState.noKey;

    return Scaffold(
      backgroundColor: SpaceNotesTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(entry: entry),
              const SizedBox(height: 28),
              const _StateNotice(state: state),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.entry});

  final CredentialEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                entry.site.isEmpty ? entry.account : entry.site,
                style: const TextStyle(
                  color: SpaceNotesTheme.fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (entry.site.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              entry.account,
              style: const TextStyle(
                color: SpaceNotesTheme.muted,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StateNotice extends StatelessWidget {
  const _StateNotice({required this.state});

  final CredentialState state;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (state) {
      CredentialState.noKey => (
          'No private key on this device',
          'Import a private key to reveal this password.',
        ),
      CredentialState.keyCannotRead => (
          "This device's key cannot read this entry",
          'The key held here does not match the recipients this entry was encrypted to. It may be left over from before a reissue.',
        ),
      CredentialState.notEncryptedToDevice => (
          'Not encrypted to this device',
          'This entry was encrypted to other recipients, so it cannot be revealed here.',
        ),
      CredentialState.revealed => ('', ''),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceNotesTheme.hairlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: SpaceNotesTheme.fg,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: SpaceNotesTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
