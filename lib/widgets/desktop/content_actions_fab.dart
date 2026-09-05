import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../actions/note_actions.dart';
import '../../theme/spacenotes_theme.dart';

/// Floating segmented pill for the desktop content area — new note, new
/// folder, upload — all targeting whatever folder is currently open.
class ContentActionsFab extends ConsumerWidget {
  const ContentActionsFab({super.key, required this.folderPath});

  final String folderPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: SpaceNotesTheme.bgAlt,
        border: Border.all(color: SpaceNotesTheme.hairline, width: 1),
        borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FabSegment(
            icon: Icons.post_add_outlined,
            tooltip: 'new note',
            onTap: () => createNoteInFolder(context, ref, folderPath),
          ),
          const _FabDivider(),
          _FabSegment(
            icon: Icons.create_new_folder_outlined,
            tooltip: 'new folder',
            onTap: () => createFolderIn(context, ref, folderPath),
          ),
          const _FabDivider(),
          _FabSegment(
            icon: Icons.cloud_upload_outlined,
            tooltip: 'upload files',
            onTap: () => uploadFilesToFolder(context, ref, folderPath),
          ),
        ],
      ),
    );
  }
}

class _FabDivider extends StatelessWidget {
  const _FabDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: SpaceNotesTheme.hairlineStrong,
      ),
    );
  }
}

class _FabSegment extends StatefulWidget {
  const _FabSegment({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_FabSegment> createState() => _FabSegmentState();
}

class _FabSegmentState extends State<_FabSegment> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 18,
              color: _hovered ? SpaceNotesTheme.accent : SpaceNotesTheme.fg,
            ),
          ),
        ),
      ),
    );
  }
}
