import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/spacenotes_theme.dart';

class ShareButton extends StatefulWidget {
  const ShareButton({super.key, required this.localPath});

  final String localPath;

  @override
  State<ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<ShareButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => SharePlus.instance.share(
          ShareParams(files: [XFile(widget.localPath)]),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(
            Icons.ios_share,
            size: 20,
            color: _hovered ? SpaceNotesTheme.accent : SpaceNotesTheme.fg,
          ),
        ),
      ),
    );
  }
}
