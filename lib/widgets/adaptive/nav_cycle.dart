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

/// The agents feature routes, hidden when the agents preference is off.
const agentRoutes = <String>{'/agents/chat', '/agents'};

List<String> navScreensFor({required bool agentsEnabled}) {
  if (agentsEnabled) return navScreens;
  return [
    for (final route in navScreens)
      if (!agentRoutes.contains(route)) route,
  ];
}

String currentNavScreen(String location) {
  if (location.startsWith('/agents/chat')) return '/agents/chat';
  if (location.startsWith('/agents')) return '/agents';
  if (location.startsWith('/notes/passwords')) return '/notes/passwords';
  return '/notes';
}

/// Navigates to the next nav destination, wrapping. [reverse] steps backward.
void cycleNav(
  BuildContext context, {
  bool reverse = false,
  bool agentsEnabled = true,
}) {
  final screens = navScreensFor(agentsEnabled: agentsEnabled);
  final location = GoRouterState.of(context).uri.toString();
  final current = currentNavScreen(location);
  final index = screens.indexOf(current);
  final step = reverse ? -1 : 1;
  final from = index < 0 ? 0 : index;
  final next = screens[(from + step) % screens.length];
  context.go(next);
}
