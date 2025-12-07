import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../widgets/terminal_input_field.dart';

/// Screen shown when no SpaceNotes server is configured.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final TextEditingController _hostController = TextEditingController();
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();

    if (host.isEmpty) {
      setState(() {
        _errorMessage = 'Server address is required';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(notesRepositoryProvider);

      // Configure and connect
      repository.configure(host: host);
      await repository.connectAndGetInitialData();

      // Check if connected
      final isConfigured = await repository.isConfigured();

      if (mounted && isConfigured) {
        context.go('/notes');
      } else {
        setState(() {
          _errorMessage = 'Failed to connect to SpaceNotes server';
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Connection failed: $e';
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Connect to SpaceNotes',
              style: TextStyle(
                color: SpaceNotesTheme.text,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your SpaceNotes server address',
              style: TextStyle(
                color: SpaceNotesTheme.text.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Server Address',
                    style: TextStyle(
                      color: SpaceNotesTheme.text.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TerminalInputField(
                    controller: _hostController,
                    hintText: '0.0.0.0:3003',
                    onSubmitted: (_) => _connect(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SpaceNotesTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: SpaceNotesTheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: SpaceNotesTheme.error,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isConnecting ? null : _connect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpaceNotesTheme.primary,
                  foregroundColor: SpaceNotesTheme.background,
                  disabledBackgroundColor:
                      SpaceNotesTheme.primary.withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            SpaceNotesTheme.background,
                          ),
                        ),
                      )
                    : const Text(
                        'Connect',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
