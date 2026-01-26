abstract class DesktopNotesEvent {}

class OpenNote extends DesktopNotesEvent {
  final String noteId;
  OpenNote(this.noteId);
}

class CloseNote extends DesktopNotesEvent {
  final String noteId;
  CloseNote(this.noteId);
}

class SetActiveNote extends DesktopNotesEvent {
  final String noteId;
  SetActiveNote(this.noteId);
}

class SetMaxOpenNotes extends DesktopNotesEvent {
  final int maxNotes;
  SetMaxOpenNotes(this.maxNotes);
}

class CloseAllNotes extends DesktopNotesEvent {}
