import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';
import '../primitives/primitives.dart';

class DashActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final SnButtonVariant variant;

  const DashActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = SnButtonVariant.outline,
  });

  @override
  Widget build(BuildContext context) {
    return SnButton(label: label, onPressed: onPressed, variant: variant);
  }
}

class DashLinkRow extends StatefulWidget {
  final String label;
  final String? trailing;
  final VoidCallback? onTap;

  const DashLinkRow({
    super.key,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  State<DashLinkRow> createState() => _DashLinkRowState();
}

class _DashLinkRowState extends State<DashLinkRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hover
                ? SpaceNotesTheme.fg.withValues(alpha: 0.03)
                : Colors.transparent,
            border: const Border(
              bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: SpaceNotesTheme.fontSans,
                    fontSize: 13,
                    color: _hover ? SpaceNotesTheme.fg : SpaceNotesTheme.muted,
                    height: 1.3,
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                Text(
                  widget.trailing!,
                  style: const TextStyle(
                    fontFamily: SpaceNotesTheme.fontMono,
                    fontSize: 11,
                    color: SpaceNotesTheme.dim,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                '›',
                style: TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 14,
                  color: _hover ? SpaceNotesTheme.accent : SpaceNotesTheme.dim,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
