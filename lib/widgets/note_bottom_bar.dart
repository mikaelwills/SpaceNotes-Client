import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/audio_playback_provider.dart';
import '../providers/notes_providers.dart';
import '../providers/connection_providers.dart';
import '../providers/chat_providers.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../generated/space_file.dart';
import 'desktop/desktop_shell.dart';
import 'quill_note_editor.dart';
import 'adaptive/platform_utils.dart';
import 'audio_mini_bar.dart';
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
    final sidebarCollapsed = ref.watch(sidebarCollapsedProvider);
    final chatCollapsed = ref.watch(chatPanelCollapsedProvider);
    final isFocusMode = sidebarCollapsed && chatCollapsed;
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
            const SizedBox(width: 8),
            _buildTile(
              icon: isFocusMode
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
              onTap: () {
                final next = !isFocusMode;
                ref.read(sidebarCollapsedProvider.notifier).state = next;
                ref.read(chatPanelCollapsedProvider.notifier).state = next;
              },
              semanticLabel: isFocusMode ? 'exit focus mode' : 'focus mode',
              size: 36,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBar(bool isChatConnected) {
    final leading = [
      SnDockTile(
        key: const ValueKey('note-more'),
        icon: Icons.more_horiz,
        onTap: () => _showNoteActions(context),
        semanticLabel: 'more actions',
      ),
      SnDockTile(
        key: const ValueKey('note-undo'),
        icon: Icons.undo,
        onTap: () => widget.quillKey?.currentState?.undo(),
        semanticLabel: 'undo',
      ),
    ];

    if (!isChatConnected) {
      return Container(
        color: SpaceNotesTheme.bg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                leading[0],
                const SizedBox(width: 8),
                leading[1],
              ],
            ),
          ),
        ),
      );
    }

    final audioFileId =
        ref.watch(audioPlaybackProvider.select((s) => s.fileId));
    final attachedToMiniBar = AudioMiniBar.isVisible(context, audioFileId);

    return SafeArea(
      top: false,
      child: SnChatDock(
        controller: _controller,
        hint: 'ask about note…',
        padding: attachedToMiniBar
            ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
            : const EdgeInsets.fromLTRB(14, 10, 14, 12),
        borderRadius: attachedToMiniBar
            ? const BorderRadius.vertical(
                bottom: Radius.circular(SpaceNotesTheme.radiusXs))
            : const BorderRadius.all(Radius.circular(SpaceNotesTheme.radiusXs)),
        onSend: _sendMessage,
        leading: leading,
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
          ),
          child: Icon(icon, size: 16, color: SpaceNotesTheme.accent),
        ),
      ),
    );
  }


  void _sendMessage() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    FocusScope.of(context).unfocus();

    final prefixedMessage = '[Viewing note: ${widget.notePath}]\n\n$message';
    final targetAgent = ref.read(targetAgentProvider);
    sendChatMessage(
      ref,
      agentId: targetAgent,
      text: prefixedMessage,
    );
    _controller.clear();

    widget.onSendMessage?.call();
  }

  void _showNoteActions(BuildContext context) {
    final note = _getCurrentNote();
    if (note == null) return;
    HapticFeedback.lightImpact();
    NotesListDialogs.showNoteContextMenu(
      context,
      ref,
      note,
      navigateToAfterDelete: _parentLocation(),
    );
  }

  String _parentLocation() {
    final path = widget.notePath;
    if (path == null || !path.contains('/')) return '/notes';
    final folderPath = path.substring(0, path.lastIndexOf('/'));
    return '/notes/folder/${Uri.encodeComponent(folderPath)}';
  }

  SpaceFile? _getCurrentNote() {
    if (widget.notePath == null) return null;
    final notes = ref.read(fileListProvider);
    return notes.firstWhereOrNull((n) => n.path == widget.notePath);
  }

}
