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
        if (!state.hasOpenNotes || state.activeNotePath == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 64,
                  color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select a note from the sidebar',
                  style: SpaceNotesTextStyles.terminal.copyWith(
                    color: SpaceNotesTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return NoteScreen(
          key: ValueKey(state.activeNotePath),
          notePath: state.activeNotePath!,
        );
      },
    );
  }
}
