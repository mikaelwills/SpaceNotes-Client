import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'adaptive/nav_cycle.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../providers/preferences_provider.dart';
import 'connection_indicator.dart';
import '../file_types/file_type_registry.dart';
import '../actions/vault_link_actions.dart';
import '../platform/capabilities.dart';

class MobileNavBar extends ConsumerWidget {
  const MobileNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    final isOnNote = _isOnNoteScreen(currentLocation);
    final isOnFolder = currentLocation.startsWith('/notes/folder/');
    final isOnSettings = currentLocation == '/settings';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.bg,
        border: Border(
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          ..._buildNavIcons(
            context,
            currentLocation,
            isOnSettings,
            agentsEnabled: ref.watch(agentsEnabledProvider),
            passwordsEnabled: ref.watch(passwordsEnabledProvider) &&
                Capabilities.canManagePasswords,
            backOverride: switch ((isOnFolder, isOnNote)) {
              (true, _) => () => _navigateToParentFolder(
                    context,
                    ref,
                    _extractFullFolderPath(currentLocation),
                  ),
              (_, true) => () => _navigateBackFromNote(
                    context,
                    ref,
                    ref
                            .read(fileByIdProvider(
                                _extractNoteIdFromLocation(currentLocation)))
                            ?.path ??
                        '',
                  ),
              _ => null,
            },
          ),
          const Spacer(),
          if (!isOnSettings) ...[
            _NavIcon(
              key: const ValueKey('nav-settings'),
              icon: Icons.settings_outlined,
              onTap: () => context.go('/settings'),
              active: false,
              slotWidth: 40,
              iconAlignment: Alignment.centerRight,
            ),
          ],
          const ConnectionIndicator(),
        ],
      ),
    );
  }

  bool _isOnNoteScreen(String location) {
    return location.startsWith('/notes/note/');
  }

  String _safeDecodeUri(String encoded) {
    try {
      return Uri.decodeComponent(encoded);
    } catch (e) {
      return encoded;
    }
  }

  String _extractNoteIdFromLocation(String location) {
    final uri = Uri.parse(location);
    final pathSegments = uri.pathSegments;
    if (pathSegments.length >= 3 && pathSegments[1] == 'note') {
      return pathSegments[2];
    }
    return '';
  }

  static const _navIcons = <String, IconData>{
    '/notes': Icons.notes_outlined,
    '/agents/chat': Icons.chat_bubble_outline,
    '/agents': Icons.terminal_outlined,
    '/notes/passwords': Icons.key_outlined,
  };

  String _currentScreen(String location) => currentNavScreen(location);

  List<Widget> _buildNavIcons(
    BuildContext context,
    String location,
    bool isOnSettings, {
    required bool agentsEnabled,
    required bool passwordsEnabled,
    VoidCallback? backOverride,
  }) {
    final current = isOnSettings ? null : _currentScreen(location);
    final icons = <Widget>[];
    for (final route in navScreensFor(
      agentsEnabled: agentsEnabled,
      passwordsEnabled: passwordsEnabled,
    )) {
      final isNotesSlot = route == '/notes';
      if (isNotesSlot && backOverride != null) {
        icons.add(
          _NavIcon(
            key: const ValueKey('nav-back'),
            icon: Icons.arrow_back,
            onTap: backOverride,
            active: false,
            slotWidth: 46,
          ),
        );
        continue;
      }

      final icon = _navIcons[route]!;
      final isActive = route == current;
      final isAtRoot = isActive && location == route;
      icons.add(
        _NavIcon(
          key: ValueKey('nav-${route.split('/').last}'),
          icon: icon,
          onTap: isAtRoot ? null : () => context.go(route),
          active: isActive,
          slotWidth: 46,
        ),
      );
    }
    return icons;
  }

  void _navigateBackFromNote(
      BuildContext context, WidgetRef ref, String notePath) {
    if (returnFromVaultLink(context, ref)) return;
    if (notePath.isEmpty) {
      context.go('/notes');
      return;
    }

    final fileName = notePath.split('/').last;
    if (FileTypeRegistry.forFileName(fileName).extension == 'gpg') {
      context.go('/notes/passwords');
      return;
    }

    final lastSlash = notePath.lastIndexOf('/');
    if (lastSlash == -1) {
      context.go('/notes');
    } else {
      final folderPath = notePath.substring(0, lastSlash);
      final encodedPath =
          folderPath.split('/').map(Uri.encodeComponent).join('/');
      context.go('/notes/folder/$encodedPath');
    }
  }

  void _navigateToParentFolder(
      BuildContext context, WidgetRef ref, String currentPath) {
    if (returnFromVaultLink(context, ref)) return;
    if (currentPath.isEmpty) {
      context.go('/notes');
      return;
    }

    final lastSlash = currentPath.lastIndexOf('/');
    if (lastSlash == -1) {
      context.go('/notes');
    } else {
      final parentPath = currentPath.substring(0, lastSlash);
      final encodedPath =
          parentPath.split('/').map(Uri.encodeComponent).join('/');
      context.go('/notes/folder/$encodedPath');
    }
  }

  String _extractFullFolderPath(String location) {
    final uri = Uri.parse(location);
    final pathSegments = uri.pathSegments;

    if (pathSegments.length >= 3 && pathSegments[1] == 'folder') {
      final folderPathSegments = pathSegments.sublist(2);
      final folderPath = folderPathSegments.map(_safeDecodeUri).join('/');
      return folderPath.endsWith('/')
          ? folderPath.substring(0, folderPath.length - 1)
          : folderPath;
    }

    return '';
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final double slotWidth;
  final AlignmentGeometry iconAlignment;

  const _NavIcon({
    super.key,
    required this.icon,
    required this.onTap,
    required this.active,
    this.slotWidth = 24,
    this.iconAlignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? SpaceNotesTheme.accent
        : SpaceNotesTheme.fg.withValues(alpha: 0.5);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: slotWidth,
        height: 44,
        child: Align(
          alignment: iconAlignment,
          child: SizedBox(
            width: 24,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}
