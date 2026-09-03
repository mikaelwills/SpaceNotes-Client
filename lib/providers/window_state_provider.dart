import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

final isFullScreenProvider =
    StateNotifierProvider<_FullScreenNotifier, bool>((ref) {
  final notifier = _FullScreenNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

class _FullScreenNotifier extends StateNotifier<bool> with WindowListener {
  _FullScreenNotifier() : super(false) {
    if (!kIsWeb && Platform.isMacOS) {
      windowManager.addListener(this);
      windowManager.isFullScreen().then((value) => state = value);
    }
  }

  @override
  void onWindowEnterFullScreen() => state = true;

  @override
  void onWindowLeaveFullScreen() => state = false;

  @override
  void dispose() {
    if (!kIsWeb && Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }
}
