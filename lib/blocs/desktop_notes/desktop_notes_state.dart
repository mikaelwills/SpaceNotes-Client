import 'package:equatable/equatable.dart';

class DesktopNotesState extends Equatable {
  final List<String> openNotePaths;
  final String? activeNotePath;
  final int maxOpenNotes;

  const DesktopNotesState({
    this.openNotePaths = const [],
    this.activeNotePath,
    this.maxOpenNotes = 10,
  });

  bool get hasOpenNotes => openNotePaths.isNotEmpty;

  DesktopNotesState copyWith({
    List<String>? openNotePaths,
    String? activeNotePath,
    bool clearActiveNote = false,
    int? maxOpenNotes,
  }) {
    return DesktopNotesState(
      openNotePaths: openNotePaths ?? this.openNotePaths,
      activeNotePath: clearActiveNote ? null : (activeNotePath ?? this.activeNotePath),
      maxOpenNotes: maxOpenNotes ?? this.maxOpenNotes,
    );
  }

  @override
  List<Object?> get props => [openNotePaths, activeNotePath, maxOpenNotes];
}
