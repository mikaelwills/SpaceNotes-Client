import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import '../theme/spacenotes_theme.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_event.dart';
import '../providers/notes_providers.dart';
import '../providers/connection_providers.dart';
import '../widgets/terminal_ip_input.dart';

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
    super.dispose();
  }

  void _loadCurrentConfig() {
    // Load SpaceNotes host from repository
    final repository = ref.read(notesRepositoryProvider);
    final host = repository.host ?? '';
    if (host.contains(':')) {
      final parts = host.split(':');
      _spaceNotesIpController.text = parts[0];
      _spaceNotesPortController.text = parts.length > 1 ? parts[1] : '3003';
    } else {
      _spaceNotesIpController.text = host;
      _spaceNotesPortController.text = '3003';
    }

    // Load OpenCode config from ConfigCubit
    final configState = context.read<ConfigCubit>().state;
    if (configState is ConfigLoaded) {
      _openCodeIpController.text = configState.serverIp == '0.0.0.0' ? '' : configState.serverIp;
      _openCodePortController.text = configState.port.toString();
    }
  }

  Future<void> _saveSpaceNotesConfig() async {
    final ip = _spaceNotesIpController.text.trim();
    final port = _spaceNotesPortController.text.trim();
    if (ip.isEmpty) return;

    final host = port.isNotEmpty ? '$ip:$port' : '$ip:3003';

    setState(() => _isSpaceNotesConnecting = true);

    try {
      final repository = ref.read(notesRepositoryProvider);
      repository.configure(host: host);
      await repository.connectAndGetInitialData();
    } catch (e) {
      debugPrint('Failed to connect to SpaceNotes: $e');
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

    final port = int.tryParse(portText) ?? 4096;

    setState(() => _isOpenCodeConnecting = true);

    try {
      final configCubit = context.read<ConfigCubit>();
      await configCubit.updateServer(ip, port: port);

      if (mounted) {
        context.read<ConnectionBloc>().add(ResetConnection());
      }
    } catch (e) {
      debugPrint('Failed to save OpenCode config: $e');
    } finally {
      if (mounted) {
        setState(() => _isOpenCodeConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSpaceNotesSection(),
          const SizedBox(height: 32),
          _buildOpenCodeSection(),
        ],
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
        const SizedBox(height: 8),
        Text(
          'Your notes database connection',
          style: TextStyle(
            fontSize: 12,
            color: SpaceNotesTheme.text.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        TerminalIPInput(
          ipController: _spaceNotesIpController,
          portController: _spaceNotesPortController,
          ipHint: 'IP Address',
          portHint: '3003',
          isConnecting: _isSpaceNotesConnecting,
          isConnected: isConnected,
          onConnect: _saveSpaceNotesConfig,
        ),
      ],
    );
  }

  Widget _buildOpenCodeSection() {
    final isConnected = ref.watch(openCodeConnectionProvider).valueOrNull ?? false;

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
        const SizedBox(height: 8),
        Text(
          'AI assistant connection',
          style: TextStyle(
            fontSize: 12,
            color: SpaceNotesTheme.text.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        TerminalIPInput(
          ipController: _openCodeIpController,
          portController: _openCodePortController,
          ipHint: 'IP Address',
          portHint: '4096',
          isConnecting: _isOpenCodeConnecting,
          isConnected: isConnected,
          onConnect: _saveOpenCodeConfig,
        ),
      ],
    );
  }
}
