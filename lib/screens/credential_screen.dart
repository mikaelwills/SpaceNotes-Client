import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacenotes_pgp/spacenotes_pgp.dart';
import 'package:uuid/uuid.dart';
import '../generated/space_file.dart';
import '../providers/notes_providers.dart';
import '../services/credential_entry_parser.dart';
import '../services/credential_key_store.dart';
import '../services/credential_writer.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/credential_field.dart';
import '../widgets/primitives/primitives.dart';

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

class CredentialCreateScreen extends ConsumerStatefulWidget {
  const CredentialCreateScreen({super.key});

  @override
  ConsumerState<CredentialCreateScreen> createState() =>
      _CredentialCreateScreenState();
}

class _CredentialCreateScreenState
    extends ConsumerState<CredentialCreateScreen> {
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _url = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _username.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final writer = ref.watch(credentialWriterProvider);

    return Scaffold(
      backgroundColor: SpaceNotesTheme.bg,
      appBar: AppBar(
        backgroundColor: SpaceNotesTheme.bg,
        title: const Text('New credential'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: writer == null
              ? const Text(
                  'The store\'s recipient list has not synced yet, so a new '
                  'entry cannot be encrypted.',
                  style: TextStyle(color: SpaceNotesTheme.muted, fontSize: 13),
                )
              : _buildForm(writer),
        ),
      ),
    );
  }

  Widget _buildForm(CredentialWriter writer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CredentialField(
          label: 'password',
          controller: _password,
          editing: true,
          obscurable: true,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        CredentialField(
          label: 'username',
          controller: _username,
          editing: true,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        CredentialField(
          label: 'url',
          controller: _url,
          editing: true,
          onChanged: () => setState(() {}),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorText(_error!),
        ],
        const SizedBox(height: 20),
        _EditActions(
          busy: _busy,
          submitLabel: 'create',
          canSubmit: _complete,
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: () => _create(writer),
        ),
      ],
    );
  }

  bool get _complete =>
      _password.text.trim().isNotEmpty &&
      _username.text.trim().isNotEmpty &&
      _url.text.trim().isNotEmpty;

  Future<void> _create(CredentialWriter writer) async {
    if (!_complete || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await writer.write(
        CredentialWriteRequest(
          id: const Uuid().v4(),
          password: _password.text,
          username: _username.text,
          url: _url.text,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _messageOf(e);
      });
    }
  }
}

class _CredentialScreenState extends ConsumerState<CredentialScreen> {
  final _keyStore = CredentialKeyStore();
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _url = TextEditingController();
  CredentialState _state = CredentialState.noKey;
  bool _busy = true;
  bool _started = false;
  bool _editing = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _username.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(fileByIdProvider(widget.fileId));

    if (file == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_started) {
      _started = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _reveal(file.content));
    }

    final entry = CredentialEntry.fromPath(file.path);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(entry: entry),
            const SizedBox(height: 28),
            if (_state == CredentialState.revealed)
              _buildFields(file)
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
    );
  }

  Widget _buildFields(SpaceFile file) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CredentialField(
          label: 'password',
          controller: _password,
          editing: _editing,
          obscurable: true,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        CredentialField(
          label: 'username',
          controller: _username,
          editing: _editing,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        CredentialField(
          label: 'url',
          controller: _url,
          editing: _editing,
          editable: false,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorText(_error!),
        ],
        const SizedBox(height: 20),
        if (_editing)
          _EditActions(
            busy: _saving,
            submitLabel: 'save',
            canSubmit: _complete,
            onCancel: _cancelEdit,
            onSubmit: () => _save(file.id, file.path),
          )
        else
          SizedBox(
            width: double.infinity,
            child: SnButton(
              key: const Key('credential-edit-button'),
              label: 'edit',
              onPressed: () => setState(() => _editing = true),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            ),
          ),
      ],
    );
  }

  bool get _complete =>
      _password.text.trim().isNotEmpty && _username.text.trim().isNotEmpty;

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _error = null;
      _seedControllers();
    });
  }

  void _seedControllers() {
    _password.text = _revealed?.password ?? '';
    _username.text = _revealed?.username ?? '';
    _url.text = _revealed?.url ?? '';
  }

  DecryptedCredential? _revealed;

  Future<void> _save(String id, String currentPath) async {
    if (!_complete || _saving) return;
    final writer = ref.read(credentialWriterProvider);
    if (writer == null) {
      setState(() => _error =
          'the store\'s recipient list has not synced yet, so nothing was written');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await writer.write(
        CredentialWriteRequest(
          id: id,
          password: _password.text,
          username: _username.text,
          url: _url.text,
          existingStorePath: currentPath,
        ),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
        _revealed = DecryptedCredential.parse(
          '${_password.text}\n'
          'username: ${_username.text}\n'
          'url: ${_url.text}\n',
        );
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _messageOf(e);
      });
    }
  }

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
        _seedControllers();
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

class _EditActions extends StatelessWidget {
  const _EditActions({
    required this.busy,
    required this.submitLabel,
    required this.canSubmit,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool busy;
  final String submitLabel;
  final bool canSubmit;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SnButton(
            key: const Key('credential-cancel-button'),
            label: 'cancel',
            onPressed: busy ? null : onCancel,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SnButton(
            key: const Key('credential-save-button'),
            label: busy ? 'saving…' : submitLabel,
            variant: SnButtonVariant.filled,
            onPressed: canSubmit && !busy ? onSubmit : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          ),
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      key: const Key('credential-refusal-message'),
      style: const TextStyle(
        color: SpaceNotesTheme.accent2,
        fontSize: 13,
        height: 1.4,
      ),
    );
  }
}

String _messageOf(Exception e) {
  final text = e.toString();
  final separator = text.indexOf(': ');
  return separator > 0 ? text.substring(separator + 2) : text;
}
