import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SessionValidator {
  static void navigateToChat(BuildContext context) {
    context.go('/notes');
  }
}
