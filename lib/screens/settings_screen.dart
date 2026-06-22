import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import '../theme/spacenotes_theme.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../blocs/desktop_notes/desktop_notes_event.dart';
import '../providers/notes_providers.dart';
import '../providers/connection_providers.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/primitives/primitives.dart';
import '../services/debug_logger.dart';

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

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
    _loadLogFileCount();
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
              if (PlatformUtils.isDesktopLayout(context))
                _buildMaxOpenNotesSection(),
              _buildDebugLogsSection(),
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
    final isSpacetimeConnected = ref.watch(spacetimeConnectedProvider);

    return _Section(
      label: 'server',
      children: [
        const Text(
          'All services run on this IP.',
          style: _proseStyle,
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            _PortChip(label: 'spacenotes', port: ConfigLoaded.spacetimeDbPort),
            SizedBox(width: 10),
            _PortChip(label: 'space', port: ConfigLoaded.spacePort),
          ],
        ),
        const SizedBox(height: 18),
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
        const SizedBox(height: 14),
        _ConnectionRow(
          connected: isSpacetimeConnected,
          label: 'spacenotes',
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

  static const TextStyle _proseStyle = TextStyle(
    fontFamily: SpaceNotesTheme.fontSans,
    fontSize: 14,
    color: SpaceNotesTheme.muted,
    height: 1.55,
  );

  Future<void> _loadLogFileCount() async {
    final files = await debugLogger.getLogFiles();
    if (mounted) {
      setState(() => _logFileCount = files.length);
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

class _PortChip extends StatelessWidget {
  final String label;
  final int port;

  const _PortChip({required this.label, required this.port});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 10,
            color: SpaceNotesTheme.dim,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          ':$port',
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 10,
            color: SpaceNotesTheme.muted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  final bool connected;
  final String label;

  const _ConnectionRow({required this.connected, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SnSyncDot(
          state: connected ? SnSyncState.synced : SnSyncState.offline,
          label: label,
        ),
      ],
    );
  }
}
