import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacenotes_pgp/spacenotes_pgp.dart';
import '../providers/notes_providers.dart';
import '../services/credential_entry_parser.dart';
import '../services/credential_key_store.dart';
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

class CredentialScreen extends ConsumerStatefulWidget {
  const CredentialScreen({super.key, required this.fileId});

  final String fileId;

  @override
  ConsumerState<CredentialScreen> createState() => _CredentialScreenState();
}

class _CredentialScreenState extends ConsumerState<CredentialScreen> {
  final _keyStore = CredentialKeyStore();
  DecryptedCredential? _revealed;
  CredentialState _state = CredentialState.noKey;
  bool _busy = true;
  bool _started = false;

  /// Decrypts as soon as the entry opens.
  ///
  /// Deliberately ONE keystore read: probing with hasKey() first would also
  /// hit the keychain and produce a second biometric prompt for a single
  /// intent. A null key IS the "no key held" answer.
  Future<void> _reveal(String base64Content) async {
    try {
      final privateKey = await _keyStore.read();
      if (privateKey == null) {
        if (mounted) setState(() => _state = CredentialState.noKey);
        return;
      }

      final plaintext = await SpaceNotesPgp.decrypt(
        ciphertext: base64Decode(base64Content),
        privateKey: privateKey,
      );

      if (!mounted) return;
      setState(() {
        _revealed = DecryptedCredential.parse(utf8.decode(plaintext));
        _state = CredentialState.revealed;
      });
    } on PgpDecryptException {
      if (mounted) setState(() => _state = CredentialState.keyCannotRead);
    } catch (_) {
      if (mounted) setState(() => _state = CredentialState.noKey);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(fileByIdProvider(widget.fileId));

    if (file == null) {
      return const Scaffold(
        backgroundColor: SpaceNotesTheme.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_started) {
      _started = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _reveal(file.content));
    }

    final entry = CredentialEntry.fromPath(file.path);
    final revealed = _revealed;

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
              if (revealed != null)
                _RevealedFields(credential: revealed)
              else if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _StateNotice(state: _state),
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

class _RevealedFields extends StatelessWidget {
  const _RevealedFields({required this.credential});

  final DecryptedCredential credential;

  @override
  Widget build(BuildContext context) {
    final username = credential.username;
    final url = credential.url;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CopyableField(
          label: 'password',
          value: credential.password,
          obscure: true,
        ),
        if (username != null) ...[
          const SizedBox(height: 12),
          _CopyableField(label: 'username', value: username),
        ],
        if (url != null) ...[
          const SizedBox(height: 12),
          _CopyableField(label: 'url', value: url),
        ],
      ],
    );
  }
}

class _CopyableField extends StatefulWidget {
  const _CopyableField({
    required this.label,
    required this.value,
    this.obscure = false,
  });

  final String label;
  final String value;
  final bool obscure;

  @override
  State<_CopyableField> createState() => _CopyableFieldState();
}

class _CopyableFieldState extends State<_CopyableField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceNotesTheme.hairlineStrong),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: SpaceNotesTheme.dim,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hidden ? '••••••••••••' : widget.value,
                  style: const TextStyle(
                    color: SpaceNotesTheme.fg,
                    fontSize: 14,
                    fontFamily: SpaceNotesTheme.fontMono,
                  ),
                ),
              ],
            ),
          ),
          if (widget.obscure)
            IconButton(
              icon: Icon(
                _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18,
                color: SpaceNotesTheme.dim,
              ),
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          IconButton(
            icon: const Icon(
              Icons.copy_outlined,
              size: 18,
              color: SpaceNotesTheme.dim,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${widget.label} copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}
