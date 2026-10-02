import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import '../theme/spacenotes_theme.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../blocs/desktop_notes/desktop_notes_event.dart';
import '../providers/notes_providers.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/primitives/primitives.dart';
import '../services/debug_logger.dart';
import '../services/credential_key_store.dart';
import '../services/local_download_store.dart';
import '../platform/capabilities.dart';
import '../providers/preferences_provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _serverIpController = TextEditingController();
  final _maxNotesController = TextEditingController();

  bool _isConnecting = false;
  int _logFileCount = 0;
  final _keyStore = CredentialKeyStore();
  bool _hasCredentialKey = false;
  final _downloadStore = LocalDownloadStore();
  int _downloadedBytes = 0;
  int _downloadedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
    _loadLogFileCount();
    _loadCredentialKeyState();
    _loadDownloadStats();
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    _maxNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPageHeader(),
              _buildServerSection(),
              _buildPreferencesSection(),
              if (PlatformUtils.isDesktopLayout(context))
                _buildMaxOpenNotesSection(),
              if (ref.watch(passwordsEnabledProvider) &&
                  Capabilities.canManagePasswords)
                _buildPasswordManagerSection(),
              _buildDebugLogsSection(),
              _buildDownloadedFilesSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SnMicroLabel('mcp · settings'),
        ],
      ),
    );
  }

  Widget _buildServerSection() {
    return _Section(
      label: 'server',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: SnField(
                controller: _serverIpController,
                hint: 'ip address',
                onSubmitted: (_) => _saveServerConfig(),
              ),
            ),
            const SizedBox(width: 10),
            _isConnecting
                ? _buildSpinnerTile()
                : SnButton(
                    label: 'connect',
                    onPressed: _saveServerConfig,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                  ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpinnerTile() {
    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        border: Border.all(color: SpaceNotesTheme.hairlineStrong, width: 1),
        borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
      ),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(SpaceNotesTheme.accent),
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    final prefs = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    final isDesktop = PlatformUtils.isDesktopLayout(context);

    return _Section(
      label: 'preferences',
      children: [
        if (isDesktop) ...[
          _PreferenceRow(
            label: 'Start with the sidebar collapsed',
            value: prefs.sidebarStartsCollapsed,
            onChanged: notifier.setSidebarStartsCollapsed,
          ),
          _PreferenceRow(
            label: 'Start with the agent panel collapsed',
            value: prefs.chatPanelStartsCollapsed,
            onChanged: notifier.setChatPanelStartsCollapsed,
          ),
        ],
        _PreferenceRow(
          label: 'Show the agents feature',
          value: prefs.agentsEnabled,
          onChanged: notifier.setAgentsEnabled,
        ),
        if (Capabilities.canManagePasswords)
          _PreferenceRow(
            label: 'Show the password manager',
            value: prefs.passwordsEnabled,
            onChanged: notifier.setPasswordsEnabled,
          ),
      ],
    );
  }

  Widget _buildMaxOpenNotesSection() {
    return _Section(
      label: 'desktop · notes',
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Max open notes', style: _proseStyle),
            ),
            SizedBox(
              width: 96,
              child: SnField(
                controller: _maxNotesController,
                hint: '10',
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0) {
                    context
                        .read<DesktopNotesBloc>()
                        .add(SetMaxOpenNotes(parsed));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordManagerSection() {
    return _Section(
      label: 'password manager',
      children: [
        Text(
          _hasCredentialKey
              ? 'A private key is held on this device.'
              : 'No private key on this device. Import one to reveal passwords.',
          style: _proseStyle,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SnButton(
                label: _hasCredentialKey ? 'replace key' : 'import key',
                onPressed: _importCredentialKey,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              ),
            ),
            if (_hasCredentialKey) ...[
              const SizedBox(width: 10),
              Expanded(
                child: SnButton(
                  label: 'remove',
                  accent: SpaceNotesTheme.offline,
                  onPressed: _removeCredentialKey,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadedFilesSection() {
    return _Section(
      label: 'downloaded files',
      children: [
        _StorageStat(bytes: _downloadedBytes, count: _downloadedCount),
        const SizedBox(height: 16),
        SnButton(
          label: 'offload all',
          accent: SpaceNotesTheme.offline,
          onPressed: _downloadedCount == 0
              ? null
              : () async {
                  await _downloadStore.offloadAll();
                  await _loadDownloadStats();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Downloaded files offloaded'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        ),
      ],
    );
  }

  Widget _buildDebugLogsSection() {
    return _Section(
      label: 'debug logs · $_logFileCount',
      children: [
        const Text(
          'Export or save logs to help debug sync issues.',
          style: _proseStyle,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SnButton(
                label: 'export',
                onPressed: () async {
                  await debugLogger.exportToFile();
                },
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SnButton(
                label: 'to notes',
                onPressed: _saveLogsToNotes,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SnButton(
                label: 'clear',
                accent: SpaceNotesTheme.offline,
                onPressed: () async {
                  await debugLogger.clearLogs();
                  await _loadLogFileCount();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logs cleared'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _importCredentialKey() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked?.files.singleOrNull;
    if (file == null) return;

    final bytes = file.bytes;
    if (bytes == null) {
      _showKeyMessage('Could not read that file.');
      return;
    }

    try {
      await _keyStore.store(bytes);
    } catch (e) {
      _showKeyMessage('Could not store the key: $e');
      return;
    } finally {
      // The picker hands back a copy in our own temp directory. Remove it so
      // the key exists only in the keystore. The file the user chose is
      // theirs to delete.
      final tempPath = file.path;
      if (tempPath != null) {
        try {
          await File(tempPath).delete();
        } catch (_) {}
      }
    }

    await _loadCredentialKeyState();
    _showKeyMessage('Key imported.');
  }

  Future<void> _removeCredentialKey() async {
    await _keyStore.delete();
    await _loadCredentialKeyState();
    _showKeyMessage('Key removed from this device.');
  }

  Future<void> _loadCredentialKeyState() async {
    final has = await _keyStore.hasKey();
    if (!mounted) return;
    setState(() => _hasCredentialKey = has);
  }

  void _showKeyMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadLogFileCount() async {
    final files = await debugLogger.getLogFiles();
    if (mounted) {
      setState(() => _logFileCount = files.length);
    }
  }

  Future<void> _loadDownloadStats() async {
    // Clear untracked leftovers before reporting, so the figure shown is the
    // real on-disk cost rather than only what the table knows about.
    final reclaimed = await _downloadStore.sweepOrphans();
    if (reclaimed > 0) {
      debugLogger.info(
          'STORAGE', 'Swept orphaned downloads', '$reclaimed bytes');
    }

    final bytes = await _downloadStore.totalSize();
    final count = await _downloadStore.downloadedCount();
    if (mounted) {
      setState(() {
        _downloadedBytes = bytes;
        _downloadedCount = count;
      });
    }
  }

  void _loadCurrentConfig() {
    final configState = context.read<ConfigCubit>().state;
    if (configState is ConfigLoaded) {
      _serverIpController.text =
          configState.serverIp == '0.0.0.0' ? '' : configState.serverIp;
    }

    final desktopNotesState = context.read<DesktopNotesBloc>().state;
    _maxNotesController.text = desktopNotesState.maxOpenNotes.toString();
  }

  Future<void> _saveServerConfig() async {
    final ip = _serverIpController.text.trim();
    if (ip.isEmpty) return;

    setState(() => _isConnecting = true);

    try {
      final configCubit = context.read<ConfigCubit>();
      await configCubit.updateServer(ip);

      final repository = ref.read(notesRepositoryProvider);
      await repository.configure(host: '$ip:${ConfigLoaded.spacetimeDbPort}');
      await repository.connectAndGetInitialData();
    } catch (e) {
      debugLogger.error('SETTINGS', 'Failed to connect: $e');
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _showResultDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLogsToNotes() async {
    final logFiles = await debugLogger.getLogFiles();
    if (logFiles.isEmpty) {
      if (mounted) _showResultDialog('No Logs', 'There are no logs to save.');
      return;
    }

    final description = await _showDescriptionDialog();
    if (description == null) return;

    try {
      final repo = ref.read(notesRepositoryProvider);
      final savedPaths = <String>[];

      final nonEmptyLogs = logFiles.where((l) => l.content.isNotEmpty).toList();
      final total = nonEmptyLogs.length;

      for (var i = 0; i < nonEmptyLogs.length; i++) {
        final logFile = nonEmptyLogs[i];
        final partNum = i + 1;
        final path =
            'Software Development/SpaceNotes/ClientLogs/${logFile.timestamp}.md';

        final header = StringBuffer();
        if (description.isNotEmpty) {
          header.writeln('## Issue Description\n');
          header.writeln(description);
          header.writeln();
        }
        if (total > 1) {
          header.writeln('**Part $partNum of $total**\n');
        }
        if (header.isNotEmpty) {
          header.writeln('---\n');
        }

        final contentWithDescription = '$header${logFile.content}';
        final noteId = await repo.createNote(path, contentWithDescription);

        if (noteId != null) {
          savedPaths.add(path);
        }
      }

      if (!mounted) return;

      final allSaved = savedPaths.length == total;
      if (allSaved && savedPaths.isNotEmpty) {
        await debugLogger.clearLogs();
        await _loadLogFileCount();
        if (!mounted) return;
        _showResultDialog(
            'Success', 'Saved ${savedPaths.length} log file(s) to ClientLogs/');
      } else if (savedPaths.isNotEmpty) {
        if (!mounted) return;
        _showResultDialog('Partial Save',
            'Saved ${savedPaths.length} of $total logs. Local files kept - try again when you have better signal.');
      } else {
        if (!mounted) return;
        _showResultDialog('Save Failed',
            'Could not save logs. Local files kept - try again when you have signal.');
      }
    } catch (e) {
      if (!mounted) return;
      _showResultDialog('Save Failed',
          'Could not save logs: $e\n\nCheck your connection and try again.');
    }
  }

  Future<String?> _showDescriptionDialog() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Describe the Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'What happened? This will be added to the top of the log notes.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'e.g., Chat messages timed out, app froze after opening note...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save Logs'),
          ),
        ],
      ),
    );
  }
}

const TextStyle _proseStyle = TextStyle(
  fontFamily: SpaceNotesTheme.fontSans,
  fontSize: 14,
  color: SpaceNotesTheme.muted,
  height: 1.55,
);

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: _proseStyle)),
          SnToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _Section({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SnMicroLabel(label),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _StorageStat extends StatelessWidget {
  final int bytes;
  final int count;

  const _StorageStat({required this.bytes, required this.count});

  static const int _scaleMaxBytes = 200 * 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    final fraction = (bytes / _scaleMaxBytes).clamp(0.0, 1.0);
    const segments = 24;
    final filled = (fraction * segments).round().clamp(0, segments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatBytes(bytes),
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 26,
                color: SpaceNotesTheme.fg,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count ${count == 1 ? 'file' : 'files'}',
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 12,
                color: SpaceNotesTheme.muted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(segments, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 2),
                height: 4,
                color: i < filled
                    ? SpaceNotesTheme.accent
                    : SpaceNotesTheme.hairline,
              ),
            );
          }),
        ),
      ],
    );
  }
}
