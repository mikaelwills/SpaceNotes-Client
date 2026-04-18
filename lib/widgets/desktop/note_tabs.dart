import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../../blocs/desktop_notes/desktop_notes_event.dart';
import '../../blocs/desktop_notes/desktop_notes_state.dart';
import '../../providers/notes_providers.dart';
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
          itemCount: state.openNoteIds.length,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final noteId = state.openNoteIds[index];
            final isActive = noteId == state.activeNoteId;
            return _NoteTab(
              noteId: noteId,
              isActive: isActive,
            );
          },
        );
      },
    );
  }
}

class _NoteTab extends ConsumerStatefulWidget {
  final String noteId;
  final bool isActive;

  const _NoteTab({
    required this.noteId,
    required this.isActive,
  });

  @override
  ConsumerState<_NoteTab> createState() => _NoteTabState();
}

class _NoteTabState extends ConsumerState<_NoteTab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          context.read<DesktopNotesBloc>().add(SetActiveNote(widget.noteId));
        },
        child: Container(
          padding: const EdgeInsets.only(left: 14, right: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? SpaceNotesTheme.bg
                : _isHovered
                    ? SpaceNotesTheme.bgAlt
                    : Colors.transparent,
            border: Border(
              right: const BorderSide(
                color: SpaceNotesTheme.hairline,
                width: 1,
              ),
              top: BorderSide(
                color: widget.isActive
                    ? SpaceNotesTheme.accent
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 13,
                color: widget.isActive
                    ? SpaceNotesTheme.accent
                    : SpaceNotesTheme.dim,
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  _displayName,
                  style: TextStyle(
                    fontFamily: SpaceNotesTheme.fontSans,
                    fontSize: 13,
                    color: widget.isActive
                        ? SpaceNotesTheme.fg
                        : SpaceNotesTheme.muted,
                    letterSpacing: -0.1,
                    fontWeight:
                        widget.isActive ? FontWeight.w500 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              if (_isHovered || widget.isActive)
                GestureDetector(
                  onTap: () {
                    context
                        .read<DesktopNotesBloc>()
                        .add(CloseNote(widget.noteId));
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: SpaceNotesTheme.muted,
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

  String get _displayName {
    final note = ref.watch(noteByIdProvider(widget.noteId));
    if (note == null) return 'Loading...';

    final name = note.path.split('/').last;
    if (name.endsWith('.md')) {
      return name.substring(0, name.length - 3);
    }
    return name;
  }
}
