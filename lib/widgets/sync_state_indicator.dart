import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart'
    show SyncState, MutationSyncResult, OptimisticChange, OptimisticChangeType;
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

        // Failures persist on the state until a clean flush or an explicit
        // dismiss, so show them even when nothing is pending or syncing.
        if (state.pendingCount == 0 && !state.isSyncing && !state.hasError) {
          return const SizedBox.shrink();
        }

        return _buildIndicator(state);
      },
    );
  }

  Widget _buildIndicator(SyncState state) {
    if (state.hasError) {
      return _ErrorIndicator(
        failedCount: state.failedCount,
        failures: state.recentFailures,
        onTap: () => _showFailureSheet(state),
      );
    }

    if (state.isSyncing) {
      return _SyncingIndicator(pendingCount: state.pendingCount);
    }

    if (state.pendingCount > 0) {
      return _PendingIndicator(pendingCount: state.pendingCount);
    }

    return const SizedBox.shrink();
  }

  void _showFailureSheet(SyncState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _SyncFailureSheet(
        failures: state.recentFailures,
        failedCount: state.failedCount,
        onDismiss: () {
          ref.read(notesRepositoryProvider).clearSyncErrors();
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  void _logStateChange(SyncState state, String source) {
    if (_lastLoggedState == null ||
        _lastLoggedState!.isSyncing != state.isSyncing ||
        _lastLoggedState!.pendingCount != state.pendingCount ||
        _lastLoggedState!.failedCount != state.failedCount) {
      debugLogger.debug(
        'SYNC_UI',
        '$source: isSyncing=${state.isSyncing}, pending=${state.pendingCount}, '
            'failed=${state.failedCount}',
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
  final int failedCount;
  final List<MutationSyncResult> failures;
  final VoidCallback onTap;

  const _ErrorIndicator({
    required this.failedCount,
    required this.failures,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = failedCount == 1
        ? '1 change failed'
        : '$failedCount changes failed';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 14,
              color: SpaceNotesTheme.error.withValues(alpha: 0.95),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 11,
                color: SpaceNotesTheme.error.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 13,
              color: SpaceNotesTheme.error.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
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

class _SyncFailureSheet extends StatelessWidget {
  final List<MutationSyncResult> failures;
  final int failedCount;
  final VoidCallback onDismiss;

  const _SyncFailureSheet({
    required this.failures,
    required this.failedCount,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxSheetHeight = mediaQuery.size.height * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.bg,
        border: Border(
          top: BorderSide(color: SpaceNotesTheme.hairlineStrong, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 2,
              color: SpaceNotesTheme.hairlineStrong,
            ),
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: failures.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _FailureCard(failure: failures[index]),
              ),
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: SpaceNotesTheme.hairline,
            ),
            _buildDismissButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: SpaceNotesTheme.error.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 8),
          Text(
            failedCount == 1
                ? '1 change could not be saved'
                : '$failedCount changes could not be saved',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: SpaceNotesTheme.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissButton(BuildContext context) {
    return InkWell(
      onTap: onDismiss,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: Text(
          'Dismiss',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 13,
            color: SpaceNotesTheme.text.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  final MutationSyncResult failure;

  const _FailureCard({required this.failure});

  @override
  Widget build(BuildContext context) {
    final lostEdit = _lostEditSummary(failure.optimisticChanges);
    final reason = failure.expired
        ? 'Discarded: this edit was queued too long to safely replay.'
        : (failure.error ?? 'The server rejected this change.');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceNotesTheme.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                failure.expired
                    ? Icons.timer_off_outlined
                    : Icons.cancel_outlined,
                size: 14,
                color: SpaceNotesTheme.error.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _humanReducerName(failure.reducerName),
                  style: const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 12,
                    color: SpaceNotesTheme.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.4,
              color: SpaceNotesTheme.textSecondary,
            ),
          ),
          if (lostEdit != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SpaceNotesTheme.bgAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your edit',
                    style: TextStyle(
                      fontFamily: 'FiraCode',
                      fontSize: 10,
                      color: SpaceNotesTheme.dim,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    lostEdit,
                    maxLines: 6,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      height: 1.4,
                      color: SpaceNotesTheme.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _humanReducerName(String reducerName) {
    return reducerName
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String? _lostEditSummary(List<OptimisticChange>? changes) {
    if (changes == null || changes.isEmpty) return null;

    for (final change in changes) {
      final row = change.type == OptimisticChangeType.delete
          ? change.oldRowJson
          : change.newRowJson;
      if (row == null) continue;

      final content = row['content'];
      if (content is String && content.trim().isNotEmpty) {
        return content;
      }
      final title = row['title'] ?? row['name'] ?? row['path'];
      if (title is String && title.trim().isNotEmpty) {
        return title;
      }
    }
    return null;
  }
}
