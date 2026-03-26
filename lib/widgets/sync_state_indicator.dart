import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' show SyncState;
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';
import '../services/debug_logger.dart';

class SyncStateIndicator extends ConsumerStatefulWidget {
  const SyncStateIndicator({super.key});

  @override
  ConsumerState<SyncStateIndicator> createState() => _SyncStateIndicatorState();
}

class _SyncStateIndicatorState extends ConsumerState<SyncStateIndicator> {
  SyncState? _lastLoggedState;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(notesRepositoryProvider);

    return StreamBuilder<SyncState>(
      stream: repo.watchSyncState(),
      initialData: repo.currentSyncState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? const SyncState();

        _logStateChange(state, snapshot.connectionState.name);

        if (!repo.hasOfflineStorage) {
          return const SizedBox.shrink();
        }

        if (state.pendingCount == 0 && !state.isSyncing) {
          return const SizedBox.shrink();
        }

        return _buildIndicator(state);
      },
    );
  }

  Widget _buildIndicator(SyncState state) {
    if (state.isSyncing) {
      return _SyncingIndicator(pendingCount: state.pendingCount);
    }

    if (state.hasError) {
      return _ErrorIndicator(error: state.lastError);
    }

    if (state.pendingCount > 0) {
      return _PendingIndicator(pendingCount: state.pendingCount);
    }

    return const SizedBox.shrink();
  }

  void _logStateChange(SyncState state, String source) {
    if (_lastLoggedState == null ||
        _lastLoggedState!.isSyncing != state.isSyncing ||
        _lastLoggedState!.pendingCount != state.pendingCount ||
        _lastLoggedState!.hasError != state.hasError) {
      debugLogger.debug(
        'SYNC_UI',
        '$source: isSyncing=${state.isSyncing}, pending=${state.pendingCount}, hasError=${state.hasError}',
      );
      _lastLoggedState = state;
    }
  }
}

class _SyncingIndicator extends StatelessWidget {
  final int pendingCount;

  const _SyncingIndicator({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              SpaceNotesTheme.primary.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Syncing${pendingCount > 1 ? ' ($pendingCount)' : ''}',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 11,
            color: SpaceNotesTheme.text.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _ErrorIndicator extends StatelessWidget {
  final String? error;

  const _ErrorIndicator({this.error});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size: 14,
          color: Colors.orange.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 6),
        Text(
          'Sync error',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 11,
            color: Colors.orange.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

class _PendingIndicator extends StatelessWidget {
  final int pendingCount;

  const _PendingIndicator({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: 14,
          color: SpaceNotesTheme.text.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 6),
        Text(
          'Pending ($pendingCount)',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 11,
            color: SpaceNotesTheme.text.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
