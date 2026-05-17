import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../theme/spacenotes_theme.dart';
import '../markdown_styles.dart';
import '../quill_note_editor.dart';

class DashSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const DashSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: SpaceNotesTheme.fg,
                    letterSpacing: -0.2,
                    height: 1.25,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
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
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class DashWidgetGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  const DashWidgetGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / (minItemWidth + spacing)).floor().clamp(1, 6);
        final itemWidth = (width - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class DashMarkdown extends StatelessWidget {
  final String text;
  final ValueChanged<String>? onChanged;

  const DashMarkdown({super.key, required this.text, this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (onChanged == null) {
      return MarkdownBody(
        data: text,
        selectable: false,
        fitContent: false,
        shrinkWrap: true,
        styleSheet: SpaceMarkdownStyles.chatAssistant(context),
        softLineBreak: true,
      );
    }
    return QuillNoteEditor(
      initialContent: text,
      showToolbar: false,
      padding: EdgeInsets.zero,
      scrollable: false,
      onContentChanged: onChanged!,
    );
  }
}

class DashSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DashSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SpaceNotesTheme.card,
        border: Border.all(color: SpaceNotesTheme.hairline, width: 1),
      ),
      padding: padding,
      child: child,
    );
  }
}
