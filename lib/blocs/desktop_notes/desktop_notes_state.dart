import 'package:equatable/equatable.dart';

class DesktopNotesState extends Equatable {
  final List<String> openNoteIds;
  final String? activeNoteId;
  final int maxOpenNotes;

  const DesktopNotesState({
    this.openNoteIds = const [],
    this.activeNoteId,
    this.maxOpenNotes = 5,
  });

  bool get hasOpenNotes => openNoteIds.isNotEmpty;

  DesktopNotesState copyWith({
    List<String>? openNoteIds,
    String? activeNoteId,
    bool clearActiveNote = false,
    int? maxOpenNotes,
  }) {
    return DesktopNotesState(
      openNoteIds: openNoteIds ?? this.openNoteIds,
      activeNoteId: clearActiveNote ? null : (activeNoteId ?? this.activeNoteId),
      maxOpenNotes: maxOpenNotes ?? this.maxOpenNotes,
    );
  }

  @override
  List<Object?> get props => [openNoteIds, activeNoteId, maxOpenNotes];
}
