import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../../blocs/desktop_notes/desktop_notes_state.dart';
import '../../screens/note_screen.dart';
import '../../theme/spacenotes_theme.dart';

class DesktopNoteView extends StatelessWidget {
  const DesktopNoteView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DesktopNotesBloc, DesktopNotesState>(
      builder: (context, state) {
        if (!state.hasOpenNotes || state.activeNoteId == null) {
          return const _EmptyState();
        }
        return NoteScreen(
          key: ValueKey(state.activeNoteId),
          noteId: state.activeNoteId!,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 48,
            color: SpaceNotesTheme.dim,
          ),
          SizedBox(height: 20),
          Text(
            'select a note from the sidebar',
            style: TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 12,
              color: SpaceNotesTheme.muted,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
