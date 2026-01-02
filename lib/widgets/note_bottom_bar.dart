import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../generated/note.dart';
import 'quill_note_editor.dart';
import 'adaptive/platform_utils.dart';

class NoteBottomBar extends ConsumerWidget {
  final String? notePath;
  final GlobalKey<QuillNoteEditorState>? quillKey;
  final VoidCallback onChatTap;

  const NoteBottomBar({
    super.key,
    required this.notePath,
    required this.quillKey,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = PlatformUtils.isDesktopLayout(context);
    final buttonSize = isDesktop ? 36.0 : 48.0;
    final iconSize = isDesktop ? 20.0 : 24.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            SpaceNotesTheme.background,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!isDesktop) ...[
              Expanded(
                child: _buildActionButton(
                  onPressed: () => _handleDeleteNote(context, ref),
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: SpaceNotesTheme.error,
                  height: buttonSize,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  onPressed: () => _handleMoveNote(context, ref),
                  icon: Icons.drive_file_move_outlined,
                  label: 'Move',
                  color: SpaceNotesTheme.primary,
                  height: buttonSize,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (isDesktop) const Spacer(),
            _buildCircularButton(
              onPressed: () => quillKey?.currentState?.undo(),
              tooltip: 'Undo',
              icon: Icons.undo,
              size: buttonSize,
              iconSize: iconSize,
            ),
            const SizedBox(width: 8),
            _buildCircularButton(
              onPressed: onChatTap,
              tooltip: 'Chat about note',
              icon: Icons.chat_bubble_outline,
              size: buttonSize,
              iconSize: iconSize,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularButton({
    required VoidCallback onPressed,
    required String tooltip,
    required IconData icon,
    required double size,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.inputSurface,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: iconSize,
          color: SpaceNotesTheme.primary,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required double height,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: SpaceNotesTheme.inputSurface,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(height / 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Note? _getCurrentNote(WidgetRef ref) {
    if (notePath == null) return null;
    final notes = ref.read(notesListProvider).valueOrNull;
    return notes?.firstWhereOrNull((n) => n.path == notePath);
  }

  void _handleMoveNote(BuildContext context, WidgetRef ref) {
    final note = _getCurrentNote(ref);
    if (note == null) return;
    NotesListDialogs.showMoveNoteDialog(context, ref, note);
  }

  void _handleDeleteNote(BuildContext context, WidgetRef ref) {
    final note = _getCurrentNote(ref);
    if (note == null) return;

    final String navigateTo;
    if (notePath!.contains('/')) {
      final lastSlash = notePath!.lastIndexOf('/');
      final folderPath = notePath!.substring(0, lastSlash);
      final encodedFolderPath = Uri.encodeComponent(folderPath);
      navigateTo = '/notes/folder/$encodedFolderPath';
    } else {
      navigateTo = '/notes';
    }

    NotesListDialogs.showDeleteNoteConfirmation(
      context,
      ref,
      note,
      navigateToAfterDelete: navigateTo,
    );
  }
}
