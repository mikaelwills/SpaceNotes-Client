import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';

/// Resolves an upload/creation target folder: pre-populated with
/// [currentFolder] when browsing one, tap opens a fuzzy-find picker over
/// every existing folder, and typing a name with no match creates it.
Future<String?> pickFolder(
  BuildContext context,
  WidgetRef ref, {
  String? currentFolder,
}) async {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _FolderPickerDialog(currentFolder: currentFolder),
  );
}

class _FolderPickerDialog extends ConsumerStatefulWidget {
  const _FolderPickerDialog({this.currentFolder});

  final String? currentFolder;

  @override
  ConsumerState<_FolderPickerDialog> createState() =>
      _FolderPickerDialogState();
}

class _FolderPickerDialogState extends ConsumerState<_FolderPickerDialog> {
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

    return AlertDialog(
      title: const Text('Choose folder'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              style: SpaceNotesTextStyles.terminal,
              decoration: const InputDecoration(hintText: 'Folder path'),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No folders yet'
                            : 'No match — press enter to create "$_query"',
                        style: const TextStyle(
                          color: SpaceNotesTheme.muted,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (ctx, i) {
                        final folder = matches[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.folder_outlined, size: 18),
                          title: Text(folder.path,
                              style: SpaceNotesTextStyles.terminal),
                          onTap: () => Navigator.of(context).pop(folder.path),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _query.isEmpty
              ? null
              : () => Navigator.of(context).pop(_query),
          child: Text(exactMatch ? 'Select' : 'Create & select'),
        ),
      ],
    );
  }
}
