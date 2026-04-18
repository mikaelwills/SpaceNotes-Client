import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/spacenotes_theme.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../providers/notes_providers.dart';
import '../widgets/primitives/primitives.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final TextEditingController _ipController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _ipController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpaceNotesTheme.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SnMicroLabel('mcp · connect'),
                const SizedBox(height: 14),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: SpaceNotesTheme.fontSans,
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: SpaceNotesTheme.fg,
                      letterSpacing: -0.8,
                      height: 1.0,
                    ),
                    children: [
                      TextSpan(text: 'Connect'),
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: SpaceNotesTheme.accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter the server IP running SpaceNotes.',
                  style: TextStyle(
                    fontFamily: SpaceNotesTheme.fontSans,
                    fontSize: 14,
                    color: SpaceNotesTheme.muted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 28),
                SnField(
                  controller: _ipController,
                  focusNode: _focusNode,
                  hint: 'ip address',
                  onSubmitted: (_) => _connect(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: SpaceNotesTheme.offline.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontFamily: SpaceNotesTheme.fontMono,
                        fontSize: 11,
                        color: SpaceNotesTheme.offline,
                        letterSpacing: 0.3,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _isConnecting
                    ? _spinnerTile()
                    : GestureDetector(
                        onTap: _connect,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: SpaceNotesTheme.hairlineStrong,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(
                                SpaceNotesTheme.radiusXs),
                          ),
                          child: const Text(
                            'CONNECT',
                            style: TextStyle(
                              fontFamily: SpaceNotesTheme.fontMono,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: SpaceNotesTheme.fg,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _spinnerTile() {
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: SpaceNotesTheme.hairlineStrong, width: 1),
        borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
      ),
      child: const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(SpaceNotesTheme.accent),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    final ip = _ipController.text.trim();

    if (ip.isEmpty) {
      setState(() {
        _errorMessage = 'server address is required';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final configCubit = context.read<ConfigCubit>();
      await configCubit.updateServer(ip);

      final repository = ref.read(notesRepositoryProvider);
      await repository.configure(host: '$ip:${ConfigLoaded.spacetimeDbPort}');
      await repository.connectAndGetInitialData();

      final isConfigured = await repository.isConfigured();

      if (mounted && isConfigured) {
        context.go('/notes');
      } else {
        setState(() {
          _errorMessage = 'failed to connect to server';
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'connection failed: $e';
          _isConnecting = false;
        });
      }
    }
  }
}
