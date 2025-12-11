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
          padding: const EdgeInsets.only(left: 8),
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
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: widget.isActive
                ? SpaceNotesTheme.primary.withValues(alpha: 0.15)
                : _isHovered
                    ? SpaceNotesTheme.inputSurface
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: widget.isActive
                ? Border.all(
                    color: SpaceNotesTheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 14,
                color: widget.isActive
                    ? SpaceNotesTheme.primary
                    : SpaceNotesTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  _displayName,
                  style: SpaceNotesTextStyles.terminal.copyWith(
                    fontSize: 12,
                    color: widget.isActive
                        ? SpaceNotesTheme.primary
                        : SpaceNotesTheme.text,
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
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: widget.isActive
                          ? SpaceNotesTheme.primary
                          : SpaceNotesTheme.textSecondary,
                    ),
                  ),
                )
              else
                const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}
