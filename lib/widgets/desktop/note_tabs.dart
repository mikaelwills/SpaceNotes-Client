import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../../blocs/desktop_notes/desktop_notes_event.dart';
import '../../blocs/desktop_notes/desktop_notes_state.dart';
import '../../theme/spacenotes_theme.dart';

class NoteTabs extends StatelessWidget {
  const NoteTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DesktopNotesBloc, DesktopNotesState>(
      builder: (context, state) {
        if (!state.hasOpenNotes) {
          return const SizedBox.shrink();
        }

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: state.openNotePaths.length,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final notePath = state.openNotePaths[index];
            final isActive = notePath == state.activeNotePath;
            return _NoteTab(
              notePath: notePath,
              isActive: isActive,
            );
          },
        );
      },
    );
  }
}

class _NoteTab extends StatefulWidget {
  final String notePath;
  final bool isActive;

  const _NoteTab({
    required this.notePath,
    required this.isActive,
  });

  @override
  State<_NoteTab> createState() => _NoteTabState();
}

class _NoteTabState extends State<_NoteTab> {
  bool _isHovered = false;

  String get _displayName {
    final name = widget.notePath.split('/').last;
    if (name.endsWith('.md')) {
      return name.substring(0, name.length - 3);
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          context.read<DesktopNotesBloc>().add(SetActiveNote(widget.notePath));
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.only(left: 10, right: 4),
          color: _isHovered && !widget.isActive
              ? SpaceNotesTheme.textSecondary.withValues(alpha: 0.1)
              : Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 14,
                color: widget.isActive
                    ? SpaceNotesTheme.text
                    : SpaceNotesTheme.primary,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  _displayName,
                  style: SpaceNotesTextStyles.terminal.copyWith(
                    fontSize: 12,
                    color: widget.isActive
                        ? SpaceNotesTheme.text
                        : SpaceNotesTheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              if (_isHovered || widget.isActive)
                GestureDetector(
                  onTap: () {
                    context.read<DesktopNotesBloc>().add(CloseNote(widget.notePath));
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: SpaceNotesTheme.primary,
                    ),
                  ),
                )
              else
                const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
