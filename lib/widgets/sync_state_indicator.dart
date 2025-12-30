import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' show SyncState;
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';

class SyncStateIndicator extends ConsumerWidget {
  const SyncStateIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(notesRepositoryProvider);

    return StreamBuilder<SyncState>(
      stream: repo.watchSyncState(),
      initialData: repo.currentSyncState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? const SyncState();

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
