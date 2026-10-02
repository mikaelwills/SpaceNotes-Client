import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../file_types/audio_file_handler.dart';
import '../file_types/file_type_registry.dart';
import '../generated/space_file.dart';
import '../providers/file_sort_provider.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';
import 'primitives/sn_dialog.dart';

/// Fuzzy-find dialog over every audio file in the vault, regardless of
/// folder. Returns the selected file's id, or null if dismissed.
Future<String?> pickAudioFile(BuildContext context, WidgetRef ref) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => const _AudioFilePickerDialog(),
  );
}

class _AudioFilePickerDialog extends ConsumerStatefulWidget {
  const _AudioFilePickerDialog();

  @override
  ConsumerState<_AudioFilePickerDialog> createState() =>
      _AudioFilePickerDialogState();
}

class _AudioFilePickerDialogState
    extends ConsumerState<_AudioFilePickerDialog> {
  late final TextEditingController _controller;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      setState(() => _query = _controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(fileListProvider);
    final audioFiles =
        files.where((f) => FileTypeRegistry.forFile(f) is AudioFileHandler);
    final query = _query.toLowerCase();
    final filtered = query.isEmpty
        ? audioFiles.toList()
        : audioFiles
            .where((f) => f.name.toLowerCase().contains(query))
            .toList();
    final matches = sortFiles(filtered, FileSortMode.name);

    return SnDialog(
      title: 'Play audio',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SnDialogField(
            controller: _controller,
            hint: 'search audio files',
          ),
          const SizedBox(height: SpaceNotesTheme.space4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: matches.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _query.isEmpty ? 'no audio files' : 'no match',
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
                      for (final file in matches)
                        Dismissible(
                          key: ValueKey(file.id),
                          direction: DismissDirection.endToStart,
                          background: const _DeleteBackground(),
                          onDismissed: (_) =>
                              ref.read(notesRepositoryProvider).deleteNote(
                                    file.id,
                                  ),
                          child: _AudioFileRow(
                            file: file,
                            onTap: () => Navigator.of(context).pop(file.id),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AudioFileRow extends StatelessWidget {
  const _AudioFileRow({required this.file, required this.onTap});

  final SpaceFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(
              Icons.music_note_outlined,
              size: 14,
              color: SpaceNotesTheme.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    file.name,
                    style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontMono,
                      fontSize: 13,
                      color: SpaceNotesTheme.fg,
                      letterSpacing: -0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (file.folderPath.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      file.folderPath,
                      style: const TextStyle(
                        fontFamily: SpaceNotesTheme.fontMono,
                        fontSize: 10,
                        color: SpaceNotesTheme.dim,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
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

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: SpaceNotesTheme.offline,
      child: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
    );
  }
}
