import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../providers/connection_providers.dart';
import '../providers/chat_providers.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../generated/note.dart';
import 'quill_note_editor.dart';
import 'adaptive/platform_utils.dart';
import 'primitives/primitives.dart';

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
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformUtils.isDesktopLayout(context);
    final isChatConnected = ref.watch(spacetimeConnectedProvider);

    if (isDesktop) {
      return _buildDesktopBar(isChatConnected);
    }
    return _buildMobileBar(isChatConnected);
  }

  Widget _buildDesktopBar(bool isChatConnected) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x000D0D0F), Color(0xD90D0D0F)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Spacer(),
            _buildTile(
              icon: Icons.undo,
              onTap: () => widget.quillKey?.currentState?.undo(),
              semanticLabel: 'undo',
              size: 36,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBar(bool isChatConnected) {
    return Container(
      color: SpaceNotesTheme.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTile(
                icon: Icons.more_horiz,
                onTap: () => _showNoteActions(context),
                semanticLabel: 'more actions',
              ),
              const SizedBox(width: 8),
              _buildTile(
                icon: Icons.undo,
                onTap: () => widget.quillKey?.currentState?.undo(),
                semanticLabel: 'undo',
              ),
              if (isChatConnected) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: SnField(
                    controller: _controller,
                    hint: 'ask about note…',
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                _buildTile(
                  icon: Icons.arrow_upward,
                  onTap: _sendMessage,
                  semanticLabel: 'send',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required VoidCallback onTap,
    required String semanticLabel,
    double size = 44,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: SpaceNotesTheme.bgAlt,
            border: Border.all(
              color: SpaceNotesTheme.hairlineStrong,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusDock),
          ),
          child: Icon(icon, size: 16, color: SpaceNotesTheme.accent),
        ),
      ),
    );
  }

  Widget _buildActionsSheet(BuildContext sheetContext) {
    return Container(
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.bg,
        border: Border(
          top: BorderSide(color: SpaceNotesTheme.hairlineStrong, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 2,
              color: SpaceNotesTheme.hairlineStrong,
            ),
            const SizedBox(height: 14),
            _buildActionTile(
              sheetContext: sheetContext,
              icon: Icons.drive_file_move_outlined,
              label: 'move to folder',
              color: SpaceNotesTheme.accent,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleMoveNote();
              },
            ),
            _buildActionTile(
              sheetContext: sheetContext,
              icon: Icons.delete_outline,
              label: 'delete note',
              color: SpaceNotesTheme.offline,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleDeleteNote();
              },
            ),
            const SizedBox(height: 12),
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 14),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 11,
                color: color,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    FocusScope.of(context).unfocus();

    final prefixedMessage = '[Viewing note: ${widget.notePath}]\n\n$message';
    final targetSession = ref.read(targetSessionProvider);
    sendChatMessage(
      ref,
      sessionId: targetSession,
      text: prefixedMessage,
    );
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
