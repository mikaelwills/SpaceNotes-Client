import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';

enum SnSyncState { synced, reconnecting, offline }

class SnSyncDot extends StatelessWidget {
  final SnSyncState state;
  final String? label;
  final double size;

  const SnSyncDot({
    super.key,
    required this.state,
    this.label,
    this.size = 6,
  });

  @override
  Widget build(BuildContext context) {
    final text = (label ?? _defaultLabel).toUpperCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _glyph,
          style: TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: size + 4,
            color: _color,
            height: 1,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 10,
            color: _color,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Color get _color => switch (state) {
        SnSyncState.synced => SpaceNotesTheme.accent,
        SnSyncState.reconnecting => SpaceNotesTheme.accent2,
        SnSyncState.offline => SpaceNotesTheme.offline,
      };

  String get _glyph => switch (state) {
        SnSyncState.synced => '●',
        SnSyncState.reconnecting => '◐',
        SnSyncState.offline => '○',
      };

  String get _defaultLabel => switch (state) {
        SnSyncState.synced => 'synced',
        SnSyncState.reconnecting => 'reconnect',
        SnSyncState.offline => 'offline',
      };
}
