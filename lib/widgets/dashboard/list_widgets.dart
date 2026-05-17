import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';
import '../primitives/primitives.dart';
import 'status_widgets.dart';

class DashListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailing;
  final Widget? trailingWidget;
  final VoidCallback? onTap;

  const DashListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: SpaceNotesTheme.fontSans,
                    fontSize: 14,
                    color: SpaceNotesTheme.fg,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontSans,
                      fontSize: 12,
                      color: SpaceNotesTheme.muted,
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailingWidget != null)
            trailingWidget!
          else if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 12,
                color: SpaceNotesTheme.muted,
                letterSpacing: 0.3,
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class DashPropertyCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? body;
  final DashStatusBadge? status;
  final List<({String label, String value})> meta;
  final Widget? action;
  final VoidCallback? onTap;

  const DashPropertyCard({
    super.key,
    required this.title,
    this.subtitle,
    this.body,
    this.status,
    this.meta = const [],
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SnCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: SpaceNotesTheme.fontSans,
                        fontSize: 15,
                        color: SpaceNotesTheme.fg,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontFamily: SpaceNotesTheme.fontMono,
                          fontSize: 11,
                          color: SpaceNotesTheme.muted,
                          letterSpacing: 0.3,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 8),
                status!,
              ],
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 10),
            Text(
              body!,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 13,
                color: SpaceNotesTheme.muted,
                height: 1.45,
              ),
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                for (final m in meta)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SnMicroLabel(m.label),
                      const SizedBox(height: 2),
                      Text(
                        m.value,
                        style: const TextStyle(
                          fontFamily: SpaceNotesTheme.fontMono,
                          fontSize: 12,
                          color: SpaceNotesTheme.fg,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft, child: action),
          ],
        ],
      ),
    );
  }
}

class DashTimelineEntry extends StatelessWidget {
  final String timestamp;
  final String text;
  final Color? markerColor;
  final bool last;

  const DashTimelineEntry({
    super.key,
    required this.timestamp,
    required this.text,
    this.markerColor,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = markerColor ?? SpaceNotesTheme.accent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.2),
                  border: Border.all(color: c, width: 1.25),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 1,
                    color: SpaceNotesTheme.hairline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timestamp,
                    style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontMono,
                      fontSize: 10,
                      color: SpaceNotesTheme.dim,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontSans,
                      fontSize: 13,
                      color: SpaceNotesTheme.fg,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashCountdownItem extends StatelessWidget {
  final String title;
  final String due;
  final String relative;
  final DashStatusBadge? status;

  const DashCountdownItem({
    super.key,
    required this.title,
    required this.due,
    required this.relative,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: SpaceNotesTheme.fontSans,
                    fontSize: 14,
                    color: SpaceNotesTheme.fg,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  due,
                  style: const TextStyle(
                    fontFamily: SpaceNotesTheme.fontMono,
                    fontSize: 11,
                    color: SpaceNotesTheme.muted,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          if (status != null) ...[
            status!,
            const SizedBox(width: 10),
          ],
          Text(
            relative,
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 12,
              color: SpaceNotesTheme.accent,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
