import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/spacenotes_theme.dart';

class ShareButton extends StatelessWidget {
  const ShareButton({super.key, required this.localPath});

  final String localPath;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpaceNotesTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: SpaceNotesTheme.hairlineStrong, width: 1),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => SharePlus.instance.share(
          ShareParams(files: [XFile(localPath)]),
        ),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Icon(Icons.ios_share, size: 20, color: SpaceNotesTheme.fg),
        ),
      ),
    );
  }
}
