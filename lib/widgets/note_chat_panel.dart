import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';
import '../screens/chat_view.dart';
import 'note_chat_input.dart';

class NoteChatPanel extends StatelessWidget {
  final String notePath;
  final VoidCallback onClose;
  final bool isDesktop;

  const NoteChatPanel({
    super.key,
    required this.notePath,
    required this.onClose,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return _buildDesktopPanel(context);
    } else {
      return _buildMobileSheet(context);
    }
  }

  Widget _buildDesktopPanel(BuildContext context) {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: SpaceNotesTheme.background,
        border: Border(
          left: BorderSide(
            color: SpaceNotesTheme.inputSurface,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(showCloseButton: true),
          Expanded(
            child: ChatView(
              showConnectionStatus: false,
              showInput: false,
              customInput: NoteChatInput(
                notePath: notePath,
                onClose: onClose,
                isDesktop: true,
              ),
              messagePadding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSheet(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      behavior: HitTestBehavior.opaque,
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        snap: true,
        snapSizes: const [0.5, 0.9],
        builder: (context, scrollController) {
          return GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                color: SpaceNotesTheme.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildDragHandle(),
                        _buildHeader(),
                      ],
                    ),
                  ),
                  SliverFillRemaining(
                    child: ChatView(
                      showConnectionStatus: false,
                      showInput: false,
                      customInput: NoteChatInput(
                        notePath: notePath,
                        onClose: onClose,
                      ),
                      messagePadding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader({bool showCloseButton = false}) {
    final noteName = notePath.split('/').last.replaceAll('.md', '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: SpaceNotesTheme.inputSurface,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 18,
            color: SpaceNotesTheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chat: $noteName',
              style: SpaceNotesTextStyles.terminal.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showCloseButton)
            IconButton(
              onPressed: onClose,
              icon: const Icon(
                Icons.close,
                size: 20,
                color: SpaceNotesTheme.textSecondary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
        ],
      ),
    );
  }
}
