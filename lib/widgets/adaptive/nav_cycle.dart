import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The main nav destinations, in cycle order. Single source shared by the
/// mobile nav bar's Shift+Tab handler and the desktop shell's.
const navScreens = <String>[
  '/notes',
  '/agents/chat',
  '/agents',
  '/notes/passwords',
];

String currentNavScreen(String location) {
  if (location.startsWith('/agents/chat')) return '/agents/chat';
  if (location.startsWith('/agents')) return '/agents';
  if (location.startsWith('/notes/passwords')) return '/notes/passwords';
  return '/notes';
}

/// Navigates to the next nav destination, wrapping. [reverse] steps backward.
void cycleNav(BuildContext context, {bool reverse = false}) {
  final location = GoRouterState.of(context).uri.toString();
  final current = currentNavScreen(location);
  final index = navScreens.indexOf(current);
  final step = reverse ? -1 : 1;
  final next = navScreens[(index + step) % navScreens.length];
  context.go(next);
}
