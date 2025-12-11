abstract class DesktopNotesEvent {}

class OpenNote extends DesktopNotesEvent {
  final String notePath;
  OpenNote(this.notePath);
}

class CloseNote extends DesktopNotesEvent {
  final String notePath;
  CloseNote(this.notePath);
}

class SetActiveNote extends DesktopNotesEvent {
  final String notePath;
  SetActiveNote(this.notePath);
}

class SetMaxOpenNotes extends DesktopNotesEvent {
  final int maxNotes;
  SetMaxOpenNotes(this.maxNotes);
}

class CloseAllNotes extends DesktopNotesEvent {}
