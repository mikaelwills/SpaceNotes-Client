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
    on<UpdateNotePath>(_onUpdateNotePath);
  }

  void _onOpenNote(OpenNote event, Emitter<DesktopNotesState> emit) {
    final currentPaths = List<String>.from(state.openNotePaths);

    if (currentPaths.contains(event.notePath)) {
      emit(state.copyWith(activeNotePath: event.notePath));
      return;
    }

    currentPaths.add(event.notePath);

    if (currentPaths.length > state.maxOpenNotes) {
      currentPaths.removeAt(0);
    }

    emit(state.copyWith(
      openNotePaths: currentPaths,
      activeNotePath: event.notePath,
    ));
  }

  void _onCloseNote(CloseNote event, Emitter<DesktopNotesState> emit) {
    final currentPaths = List<String>.from(state.openNotePaths);
    final closingIndex = currentPaths.indexOf(event.notePath);

    if (closingIndex == -1) return;

    currentPaths.remove(event.notePath);

    String? newActivePath = state.activeNotePath;
    if (state.activeNotePath == event.notePath) {
      if (currentPaths.isEmpty) {
        newActivePath = null;
      } else if (closingIndex >= currentPaths.length) {
        newActivePath = currentPaths.last;
      } else {
        newActivePath = currentPaths[closingIndex];
      }
    }

    emit(state.copyWith(
      openNotePaths: currentPaths,
      activeNotePath: newActivePath,
      clearActiveNote: newActivePath == null,
    ));
  }

  void _onSetActiveNote(SetActiveNote event, Emitter<DesktopNotesState> emit) {
    if (state.openNotePaths.contains(event.notePath)) {
      emit(state.copyWith(activeNotePath: event.notePath));
    }
  }

  void _onSetMaxOpenNotes(SetMaxOpenNotes event, Emitter<DesktopNotesState> emit) {
    final currentPaths = List<String>.from(state.openNotePaths);

    while (currentPaths.length > event.maxNotes) {
      currentPaths.removeAt(0);
    }

    String? newActivePath = state.activeNotePath;
    if (newActivePath != null && !currentPaths.contains(newActivePath)) {
      newActivePath = currentPaths.isNotEmpty ? currentPaths.last : null;
    }

    emit(state.copyWith(
      openNotePaths: currentPaths,
      activeNotePath: newActivePath,
      clearActiveNote: newActivePath == null,
      maxOpenNotes: event.maxNotes,
    ));
  }

  void _onCloseAllNotes(CloseAllNotes event, Emitter<DesktopNotesState> emit) {
    emit(state.copyWith(
      openNotePaths: [],
      clearActiveNote: true,
    ));
  }

  void _onUpdateNotePath(UpdateNotePath event, Emitter<DesktopNotesState> emit) {
    final currentPaths = List<String>.from(state.openNotePaths);
    final index = currentPaths.indexOf(event.oldPath);

    if (index == -1) return;

    currentPaths[index] = event.newPath;

    String? newActivePath = state.activeNotePath;
    if (state.activeNotePath == event.oldPath) {
      newActivePath = event.newPath;
    }

    emit(state.copyWith(
      openNotePaths: currentPaths,
      activeNotePath: newActivePath,
    ));
  }
}
