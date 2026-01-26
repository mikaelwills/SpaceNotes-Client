import 'package:flutter_bloc/flutter_bloc.dart';
import 'desktop_notes_event.dart';
import 'desktop_notes_state.dart';

class DesktopNotesBloc extends Bloc<DesktopNotesEvent, DesktopNotesState> {
  DesktopNotesBloc() : super(const DesktopNotesState()) {
    on<OpenNote>(_onOpenNote);
    on<CloseNote>(_onCloseNote);
    on<SetActiveNote>(_onSetActiveNote);
    on<SetMaxOpenNotes>(_onSetMaxOpenNotes);
    on<CloseAllNotes>(_onCloseAllNotes);
  }

  void _onOpenNote(OpenNote event, Emitter<DesktopNotesState> emit) {
    final currentIds = List<String>.from(state.openNoteIds);

    if (currentIds.contains(event.noteId)) {
      emit(state.copyWith(activeNoteId: event.noteId));
      return;
    }

    currentIds.add(event.noteId);

    if (currentIds.length > state.maxOpenNotes) {
      currentIds.removeAt(0);
    }

    emit(state.copyWith(
      openNoteIds: currentIds,
      activeNoteId: event.noteId,
    ));
  }

  void _onCloseNote(CloseNote event, Emitter<DesktopNotesState> emit) {
    final currentIds = List<String>.from(state.openNoteIds);
    final closingIndex = currentIds.indexOf(event.noteId);

    if (closingIndex == -1) return;

    currentIds.remove(event.noteId);

    String? newActiveId = state.activeNoteId;
    if (state.activeNoteId == event.noteId) {
      if (currentIds.isEmpty) {
        newActiveId = null;
      } else if (closingIndex >= currentIds.length) {
        newActiveId = currentIds.last;
      } else {
        newActiveId = currentIds[closingIndex];
      }
    }

    emit(state.copyWith(
      openNoteIds: currentIds,
      activeNoteId: newActiveId,
      clearActiveNote: newActiveId == null,
    ));
  }

  void _onSetActiveNote(SetActiveNote event, Emitter<DesktopNotesState> emit) {
    if (state.openNoteIds.contains(event.noteId)) {
      emit(state.copyWith(activeNoteId: event.noteId));
    }
  }

  void _onSetMaxOpenNotes(SetMaxOpenNotes event, Emitter<DesktopNotesState> emit) {
    final currentIds = List<String>.from(state.openNoteIds);

    while (currentIds.length > event.maxNotes) {
      currentIds.removeAt(0);
    }

    String? newActiveId = state.activeNoteId;
    if (newActiveId != null && !currentIds.contains(newActiveId)) {
      newActiveId = currentIds.isNotEmpty ? currentIds.last : null;
    }

    emit(state.copyWith(
      openNoteIds: currentIds,
      activeNoteId: newActiveId,
      clearActiveNote: newActiveId == null,
      maxOpenNotes: event.maxNotes,
    ));
  }

  void _onCloseAllNotes(CloseAllNotes event, Emitter<DesktopNotesState> emit) {
    emit(state.copyWith(
      openNoteIds: [],
      clearActiveNote: true,
    ));
  }
}
