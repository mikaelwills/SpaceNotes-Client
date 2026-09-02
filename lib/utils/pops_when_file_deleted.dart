import 'package:flutter/material.dart';

mixin PopsWhenFileDeleted<T extends StatefulWidget> on State<T> {
  bool _hasSeenFile = false;

  bool trackFilePresence(Object? file, BuildContext context) {
    if (file != null) {
      _hasSeenFile = true;
      return true;
    }
    if (_hasSeenFile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
    return false;
  }
}
