import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' as stdb;
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';

class ConnectionIndicator extends ConsumerWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(spacetimeClientProvider);

    if (client == null) {
      return _buildDisconnectedIndicator();
    }

    return StreamBuilder<stdb.ConnectionState>(
      stream: client.connection.onStateChanged,
      initialData: client.connection.state,
      builder: (context, stateSnapshot) {
        final state = stateSnapshot.data ?? const stdb.Disconnected();

        return StreamBuilder<stdb.ConnectionQuality>(
          stream: client.connection.connectionQuality,
          builder: (context, qualitySnapshot) {
            final quality = qualitySnapshot.data;

            return _PulsingHealthBar(
              state: state,
              quality: quality,
            );
          },
        );
      },
    );
  }

  static Widget _buildDisconnectedIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: SpaceNotesTheme.error.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

class _PulsingHealthBar extends ConsumerStatefulWidget {
  final stdb.ConnectionState state;
  final stdb.ConnectionQuality? quality;

  const _PulsingHealthBar({
    required this.state,
    required this.quality,
  });

  @override
  ConsumerState<_PulsingHealthBar> createState() => _PulsingHealthBarState();
}

class _PulsingHealthBarState extends ConsumerState<_PulsingHealthBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  DateTime? _lastPongTimestamp;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _PulsingHealthBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentPong = widget.quality?.lastPongReceived;

    if (currentPong != null && currentPong != _lastPongTimestamp) {
      _lastPongTimestamp = currentPong;

      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          _triggerPulse();
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final healthScore = _getHealthScore();
    final isDegraded = !widget.state.isConnected;

    return GestureDetector(
      onTap: isDegraded ? _handleReconnectTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final glowOpacity = (_pulseAnimation.value - 1.0) / 0.15;
            return Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: color.withValues(alpha: 0.15),
                boxShadow: glowOpacity > 0
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: glowOpacity * 0.8),
                          blurRadius: 60,
                          spreadRadius: 20,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: healthScore.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _triggerPulse() {
    _pulseController.forward(from: 0.0).then((_) {
      if (mounted) {
        _pulseController.reverse();
      }
    });
  }

  Color _getStatusColor() {
    return switch (widget.state) {
      stdb.Connected() => SpaceNotesTheme.success,
      stdb.Connecting() || stdb.Reconnecting() => SpaceNotesTheme.warning,
      stdb.AuthError() ||
      stdb.FatalError() ||
      stdb.Disconnected() =>
        SpaceNotesTheme.error,
    };
  }

  double _getHealthScore() {
    if (widget.quality != null) {
      return widget.quality!.healthScore;
    }
    return switch (widget.state) {
      stdb.Connected() => 1.0,
      stdb.Connecting() || stdb.Reconnecting() => 0.5,
      stdb.AuthError() || stdb.Disconnected() || stdb.FatalError() => 0.0,
    };
  }

  void _handleReconnectTap() {
    _forceReconnect();
  }

  void _forceReconnect() async {
    final repo = ref.read(notesRepositoryProvider);
    repo.resetConnection();
    await repo.connectAndGetInitialData();
  }
}
