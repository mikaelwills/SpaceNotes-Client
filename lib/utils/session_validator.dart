import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:spacenotes_client/blocs/session/session_bloc.dart';
import 'package:spacenotes_client/blocs/session/session_state.dart';

class SessionValidator {
  /// Checks if there is a valid, loaded session.
  static bool isValidSession(BuildContext context) {
    final sessionState = context.read<SessionBloc>().state;
    // A session is considered valid if it's in the "Loaded" state,
    // meaning we have session data.
    return sessionState is SessionLoaded;
  }

  /// Navigates to the notes screen (which contains AI chat functionality).
  /// Previously navigated to /chat but AI chat is now integrated into notes.
  static void navigateToChat(BuildContext context) {
    context.go('/notes');
  }
}
