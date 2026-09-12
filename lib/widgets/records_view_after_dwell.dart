import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recently_viewed_provider.dart';
import '../services/recently_viewed_store.dart';

/// Marks [fileId] as viewed once it has been on screen long enough to mean it.
///
/// The timer is why this is a widget rather than a line in a build method: it
/// must be cancelled when the screen goes away, or it fires against a disposed
/// widget and records a file the user only passed through on the way to
/// another. One place to get that right, inherited by every screen.
///
/// State lives in [recentlyViewedIdsProvider]; this only decides when to tell
/// it.
class RecordsViewAfterDwell extends ConsumerStatefulWidget {
  const RecordsViewAfterDwell({
    super.key,
    required this.fileId,
    required this.child,
  });

  final String fileId;
  final Widget child;

  @override
  ConsumerState<RecordsViewAfterDwell> createState() =>
      _RecordsViewAfterDwellState();
}

class _RecordsViewAfterDwellState extends ConsumerState<RecordsViewAfterDwell> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// A route reuses this screen when only the id changes, so a new file must
  /// restart the clock rather than inherit the previous file's.
  @override
  void didUpdateWidget(RecordsViewAfterDwell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileId != widget.fileId) {
      _timer?.cancel();
      _start();
    }
  }

  void _start() {
    if (widget.fileId.isEmpty) return;
    final fileId = widget.fileId;
    _timer = Timer(RecentlyViewedStore.dwell, () {
      if (!mounted) return;
      ref.read(recentlyViewedIdsProvider.notifier).record(fileId);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
