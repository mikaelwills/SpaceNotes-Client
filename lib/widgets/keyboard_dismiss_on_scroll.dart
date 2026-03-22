import 'package:flutter/material.dart';

class KeyboardDismissOnScroll extends StatelessWidget {
  final Widget child;

  const KeyboardDismissOnScroll({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: (event) {
        if (event.delta.dy > 3) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: child,
    );
  }
}
