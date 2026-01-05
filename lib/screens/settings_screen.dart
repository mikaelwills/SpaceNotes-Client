import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import '../theme/spacenotes_theme.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_event.dart';
import '../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../blocs/desktop_notes/desktop_notes_event.dart';
import '../providers/notes_providers.dart';
import '../providers/connection_providers.dart';
import '../widgets/terminal_ip_input.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../services/debug_logger.dart';

/// Settings screen for configuring SpaceNotes and OpenCode connections.
/// There is only ONE connection of each type - no multi-instance support.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _spaceNotesIpController = TextEditingController();
  final _spaceNotesPortController = TextEditingController();
  final _openCodeIpController = TextEditingController();
  final _openCodePortController = TextEditingController();
  final _maxNotesController = TextEditingController();

  bool _isSpaceNotesConnecting = false;
  bool _isOpenCodeConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _spaceNotesIpController.dispose();
    _spaceNotesPortController.dispose();
    _openCodeIpController.dispose();
    _openCodePortController.dispose();
    _maxNotesController.dispose();
    super.dispose();
  }

  void _loadCurrentConfig() {
    // Load SpaceNotes host from repository
    final repository = ref.read(notesRepositoryProvider);
    final host = repository.host ?? '';
    if (host.contains(':')) {
      final parts = host.split(':');
      _spaceNotesIpController.text = parts[0];
      _spaceNotesPortController.text = parts.length > 1 ? parts[1] : '5050';
    } else {
      _spaceNotesIpController.text = host;
      _spaceNotesPortController.text = '5050';
    }

    // Load OpenCode config from ConfigCubit
    final configState = context.read<ConfigCubit>().state;
    if (configState is ConfigLoaded) {
      _openCodeIpController.text =
          configState.serverIp == '0.0.0.0' ? '' : configState.serverIp;
      _openCodePortController.text = configState.port.toString();
    }

    // Load max open notes from DesktopNotesBloc
    final desktopNotesState = context.read<DesktopNotesBloc>().state;
    _maxNotesController.text = desktopNotesState.maxOpenNotes.toString();
  }

  Future<void> _saveSpaceNotesConfig() async {
    final ip = _spaceNotesIpController.text.trim();
    final port = _spaceNotesPortController.text.trim();
    if (ip.isEmpty) return;

    final host = port.isNotEmpty ? '$ip:$port' : '$ip:5050';

    setState(() => _isSpaceNotesConnecting = true);

    try {
      final repository = ref.read(notesRepositoryProvider);
      await repository.configure(host: host);
      await repository.connectAndGetInitialData();
    } catch (e) {
      debugLogger.error('SETTINGS', 'Failed to connect to SpaceNotes: $e');
    } finally {
      if (mounted) {
        setState(() => _isSpaceNotesConnecting = false);
      }
    }
  }

  Future<void> _saveOpenCodeConfig() async {
    final ip = _openCodeIpController.text.trim();
    final portText = _openCodePortController.text.trim();
    if (ip.isEmpty) return;

    final port = int.tryParse(portText) ?? 5053;

    setState(() => _isOpenCodeConnecting = true);

    try {
      final configCubit = context.read<ConfigCubit>();
      await configCubit.updateServer(ip, port: port);

      if (mounted) {
        context.read<ConnectionBloc>().add(ResetConnection());
      }
    } catch (e) {
      debugLogger.error('SETTINGS', 'Failed to save OpenCode config: $e');
    } finally {
      if (mounted) {
        setState(() => _isOpenCodeConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSpaceNotesSection(),
              const SizedBox(height: 32),
              _buildOpenCodeSection(),
              const SizedBox(height: 32),
              _buildDebugLogsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpaceNotesSection() {
    final isConnected = ref.watch(spacetimeConnectedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SpaceNotes Server',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: SpaceNotesTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        TerminalIPInput(
          ipController: _spaceNotesIpController,
          portController: _spaceNotesPortController,
          ipHint: 'IP Address',
          portHint: '5050',
          isConnecting: _isSpaceNotesConnecting,
          isConnected: isConnected,
          onConnect: _saveSpaceNotesConfig,
        ),
      ],
    );
  }

  Widget _buildOpenCodeSection() {
    final isConnected =
        ref.watch(openCodeConnectionProvider).valueOrNull ?? false;
    final isDesktop = PlatformUtils.isDesktopLayout(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OpenCode Server',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: SpaceNotesTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        TerminalIPInput(
          ipController: _openCodeIpController,
          portController: _openCodePortController,
          ipHint: 'IP Address',
          portHint: '5053',
          isConnecting: _isOpenCodeConnecting,
          isConnected: isConnected,
          onConnect: _saveOpenCodeConfig,
        ),
        if (isDesktop) ...[
          const SizedBox(height: 24),
          _buildMaxOpenNotesSection(),
        ],
      ],
    );
  }

  Widget _buildMaxOpenNotesSection() {
    return Row(
      children: [
        Text(
          'Max open notes',
          style: SpaceNotesTextStyles.terminal.copyWith(
            fontSize: 13,
            color: SpaceNotesTheme.text,
          ),
        ),
        const Spacer(),
        Container(
          width: 80,
          height: 32,
          decoration: BoxDecoration(
            color: SpaceNotesTheme.inputSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _maxNotesController,
                  style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 12),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      context
                          .read<DesktopNotesBloc>()
                          .add(SetMaxOpenNotes(parsed));
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '10',
                    hintStyle: SpaceNotesTextStyles.terminal.copyWith(
                      fontSize: 12,
                      color: SpaceNotesTheme.textSecondary,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ],
    );
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
        final path = 'Software Development/SpaceNotes/ClientLogs/${logFile.timestamp}.md';

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
        if (!mounted) return;
        _showResultDialog('Success', 'Saved ${savedPaths.length} log file(s) to ClientLogs/');
      } else if (savedPaths.isNotEmpty) {
        if (!mounted) return;
        _showResultDialog('Partial Save', 'Saved ${savedPaths.length} of $total logs. Local files kept - try again when you have better signal.');
      } else {
        if (!mounted) return;
        _showResultDialog('Save Failed', 'Could not save logs. Local files kept - try again when you have signal.');
      }
    } catch (e) {
      if (!mounted) return;
      _showResultDialog('Save Failed', 'Could not save logs: $e\n\nCheck your connection and try again.');
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
                hintText: 'e.g., Chat messages timed out, app froze after opening note...',
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

  Widget _buildDebugLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Debug Logs',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: SpaceNotesTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Export or save logs to help debug sync issues.',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 12,
            color: SpaceNotesTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await debugLogger.exportToFile();
                },
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpaceNotesTheme.inputSurface,
                  foregroundColor: SpaceNotesTheme.text,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _saveLogsToNotes(),
                icon: const Icon(Icons.note_add, size: 18),
                label: const Text('To Notes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpaceNotesTheme.inputSurface,
                  foregroundColor: SpaceNotesTheme.text,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await debugLogger.clearLogs();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logs cleared'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpaceNotesTheme.inputSurface,
                  foregroundColor: SpaceNotesTheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
