import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';
import 'primitives/sn_dialog.dart';

class UploadTarget {
  const UploadTarget({required this.folder, required this.source});

  final String folder;
  final FileType source;
}

/// Resolves an upload destination in one dialog: a fuzzy-find folder field
/// (pre-populated with [currentFolder], typing a name with no match creates
/// it) plus Photos / Files source buttons.
Future<UploadTarget?> pickUploadTarget(
  BuildContext context,
  WidgetRef ref, {
  String? currentFolder,
}) async {
  return showDialog<UploadTarget>(
    context: context,
    builder: (ctx) => _UploadTargetDialog(currentFolder: currentFolder),
  );
}

class _UploadTargetDialog extends ConsumerStatefulWidget {
  const _UploadTargetDialog({this.currentFolder});

  final String? currentFolder;

  @override
  ConsumerState<_UploadTargetDialog> createState() =>
      _UploadTargetDialogState();
}

class _UploadTargetDialogState extends ConsumerState<_UploadTargetDialog> {
  late final TextEditingController _controller;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentFolder ?? '');
    _query = widget.currentFolder ?? '';
    _controller.addListener(() {
      setState(() => _query = _controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(FileType source) {
    if (_query.trim().isEmpty) return;
    Navigator.of(context)
        .pop(UploadTarget(folder: _query.trim(), source: source));
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(foldersListProvider);
    final query = _query.toLowerCase();
    final matches = query.isEmpty
        ? folders
        : folders.where((f) => f.path.toLowerCase().contains(query)).toList();
    matches.sort((a, b) => a.path.compareTo(b.path));

    final exactMatch =
        folders.any((f) => f.path.toLowerCase() == query && query.isNotEmpty);
    final showCreateRow = _query.isNotEmpty && !exactMatch;

    return SnDialog(
      title: 'Upload to',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SnDialogField(
            controller: _controller,
            hint: 'folder',
          ),
          const SizedBox(height: SpaceNotesTheme.space4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: matches.isEmpty && !showCreateRow
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _query.isEmpty ? 'no folders yet' : 'no match',
                      style: const TextStyle(
                        fontFamily: SpaceNotesTheme.fontMono,
                        fontSize: 12,
                        color: SpaceNotesTheme.dim,
                        letterSpacing: 0.4,
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      if (showCreateRow)
                        _FolderRow(
                          icon: Icons.add,
                          label: _query,
                          sublabel: 'create folder',
                          highlighted: true,
                          onTap: () =>
                              setState(() => _controller.text = _query),
                        ),
                      for (final folder in matches)
                        _FolderRow(
                          icon: Icons.folder_outlined,
                          label: folder.path,
                          highlighted: folder.path == widget.currentFolder,
                          onTap: () =>
                              setState(() => _controller.text = folder.path),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: SpaceNotesTheme.space6),
          _SourceButtonRow(
            enabled: _query.trim().isNotEmpty,
            onPhotos: () => _finish(FileType.media),
            onFiles: () => _finish(FileType.any),
          ),
        ],
      ),
    );
  }
}

class _SourceButtonRow extends StatelessWidget {
  const _SourceButtonRow({
    required this.enabled,
    required this.onPhotos,
    required this.onFiles,
  });

  final bool enabled;
  final VoidCallback onPhotos;
  final VoidCallback onFiles;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SourceButton(
              icon: Icons.photo_outlined,
              label: 'Photos',
              enabled: enabled,
              onTap: onPhotos,
            ),
          ),
          Container(
            width: 1,
            color: SpaceNotesTheme.hairlineStrong,
          ),
          Expanded(
            child: _SourceButton(
              icon: Icons.folder_outlined,
              label: 'Files',
              enabled: enabled,
              onTap: onFiles,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        enabled ? SpaceNotesTheme.fg : SpaceNotesTheme.dim;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sublabel,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: highlighted
                  ? SpaceNotesTheme.accent
                  : SpaceNotesTheme.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: SpaceNotesTheme.fontMono,
                      fontSize: 13,
                      color: highlighted
                          ? SpaceNotesTheme.accent
                          : SpaceNotesTheme.fg,
                      letterSpacing: -0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: const TextStyle(
                        fontFamily: SpaceNotesTheme.fontMono,
                        fontSize: 10,
                        color: SpaceNotesTheme.dim,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
