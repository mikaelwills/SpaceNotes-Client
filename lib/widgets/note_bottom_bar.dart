import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../providers/connection_providers.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../generated/note.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import 'quill_note_editor.dart';
import 'adaptive/platform_utils.dart';
import 'notes_search_bar.dart';

class NoteBottomBar extends ConsumerStatefulWidget {
  final String? notePath;
  final GlobalKey<QuillNoteEditorState>? quillKey;
  final VoidCallback onChatTap;
  final VoidCallback? onSendMessage;

  const NoteBottomBar({
    super.key,
    required this.notePath,
    required this.quillKey,
    required this.onChatTap,
    this.onSendMessage,
  });

  @override
  ConsumerState<NoteBottomBar> createState() => _NoteBottomBarState();
}

class _NoteBottomBarState extends ConsumerState<NoteBottomBar> {
  static const _radius = 14.0;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformUtils.isDesktopLayout(context);
    final isChatConnected =
        ref.watch(chatConnectedProvider).valueOrNull ?? false;

    if (isDesktop) {
      return _buildDesktopBar(isChatConnected);
    }
    return _buildMobileBar(isChatConnected);
  }

  Widget _buildDesktopBar(bool isChatConnected) {
    const buttonSize = 36.0;
    const iconSize = 20.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, SpaceNotesTheme.background],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Spacer(),
            _buildIconButton(
              onPressed: () => widget.quillKey?.currentState?.undo(),
              tooltip: 'Undo',
              icon: Icons.undo,
              size: buttonSize,
              iconSize: iconSize,
            ),
            if (isChatConnected) ...[
              const SizedBox(width: 8),
              _buildIconButton(
                onPressed: widget.onChatTap,
                tooltip: 'Chat about note',
                icon: Icons.chat_bubble_outline,
                size: buttonSize,
                iconSize: iconSize,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBar(bool isChatConnected) {
    return Container(
      color: SpaceNotesTheme.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildIconButton(
                onPressed: () => _showNoteActions(context),
                tooltip: 'More actions',
                icon: Icons.more_horiz,
                size: 44,
                iconSize: 24,
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                onPressed: () => widget.quillKey?.currentState?.undo(),
                tooltip: 'Undo',
                icon: Icons.undo,
                size: 44,
                iconSize: 22,
              ),
              if (isChatConnected) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildChatInput(),
                ),
                const SizedBox(width: 8),
                _buildSendButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      decoration: BoxDecoration(
        color: SpaceNotesTheme.inputSurface,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: NotesSearchBar(
        controller: _controller,
        height: 44,
        hintText: 'Ask about note...',
        onChanged: (_) {},
        onSubmitted: _sendMessage,
      ),
    );
  }

  Widget _buildSendButton() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: SpaceNotesTheme.inputSurface,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: IconButton(
        onPressed: _sendMessage,
        tooltip: 'Send',
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.arrow_upward,
          size: 22,
          color: SpaceNotesTheme.primary,
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required VoidCallback onPressed,
    required String tooltip,
    required IconData icon,
    required double size,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SpaceNotesTheme.inputSurface,
        borderRadius: BorderRadius.circular(_radius),
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

  Widget _buildActionsSheet(BuildContext sheetContext) {
    return Container(
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: SpaceNotesTheme.inputSurface, width: 1),
          left: BorderSide(color: SpaceNotesTheme.inputSurface, width: 1),
          right: BorderSide(color: SpaceNotesTheme.inputSurface, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _buildActionTile(
              sheetContext: sheetContext,
              icon: Icons.drive_file_move_outlined,
              label: 'Move to folder',
              color: SpaceNotesTheme.primary,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleMoveNote();
              },
            ),
            _buildActionTile(
              sheetContext: sheetContext,
              icon: Icons.delete_outline,
              label: 'Delete note',
              color: SpaceNotesTheme.error,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleDeleteNote();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext sheetContext,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 15,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }

  void _sendMessage() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    FocusScope.of(context).unfocus();

    final prefixedMessage = '[Viewing note: ${widget.notePath}]\n\n$message';
    context.read<ChatBloc>().add(SendChatMessage(prefixedMessage));
    _controller.clear();

    widget.onSendMessage?.call();
  }

  void _showNoteActions(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _buildActionsSheet(sheetContext),
    );
  }

  Note? _getCurrentNote() {
    if (widget.notePath == null) return null;
    final notes = ref.read(notesListProvider);
    return notes.firstWhereOrNull((n) => n.path == widget.notePath);
  }

  void _handleMoveNote() {
    final note = _getCurrentNote();
    if (note == null) return;
    NotesListDialogs.showMoveNoteDialog(context, ref, note);
  }

  void _handleDeleteNote() {
    final note = _getCurrentNote();
    if (note == null) return;

    final String navigateTo;
    if (widget.notePath!.contains('/')) {
      final lastSlash = widget.notePath!.lastIndexOf('/');
      final folderPath = widget.notePath!.substring(0, lastSlash);
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
