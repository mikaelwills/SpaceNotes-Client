import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../../blocs/desktop_notes/desktop_notes_event.dart';
import '../../blocs/desktop_notes/desktop_notes_state.dart';
import '../../providers/middle_pane_mode_provider.dart';
import '../../providers/notes_providers.dart';
import '../../theme/spacenotes_theme.dart';
import '../../file_types/file_type_registry.dart';

class NoteTabs extends ConsumerWidget {
  const NoteTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<DesktopNotesBloc, DesktopNotesState>(
      builder: (context, state) {
        final mode = ref.watch(middlePaneModeProvider);
        final backOnPressed = switch (mode) {
          FileViewerMode() => () {
              final activeId = state.activeNoteId;
              if (activeId == null) return;
              final parentFolder = state.parentFolderByNoteId[activeId] ?? '';
              ref.read(middlePaneModeProvider.notifier).state =
                  MiddlePaneMode.browse(parentFolder);
            },
          BrowseMode(:final folderPath) when folderPath.isNotEmpty => () {
              final lastSlash = folderPath.lastIndexOf('/');
              final parentPath =
                  lastSlash == -1 ? '' : folderPath.substring(0, lastSlash);
              ref.read(middlePaneModeProvider.notifier).state =
                  MiddlePaneMode.browse(parentPath);
            },
          _ => null,
        };

        if (backOnPressed == null && !state.hasOpenNotes) {
          return const SizedBox.shrink();
        }

        return Row(
          children: [
            if (backOnPressed != null)
              _BackToFolderButton(onPressed: backOnPressed),
            Expanded(
              child: ListView.builder(
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
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BackToFolderButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackToFolderButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
          ),
        ),
        child: const Icon(
          Icons.arrow_back,
          size: 14,
          color: SpaceNotesTheme.muted,
        ),
      ),
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
          ref.read(middlePaneModeProvider.notifier).state =
              MiddlePaneMode.fileViewer(widget.noteId);
        },
        child: Container(
          padding: const EdgeInsets.only(left: 14, right: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? SpaceNotesTheme.bg
                : _isHovered
                    ? SpaceNotesTheme.bgAlt
                    : Colors.transparent,
            border: const Border(
              right: BorderSide(
                color: SpaceNotesTheme.hairline,
                width: 1,
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
                  onTap: _closeTab,
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

  void _closeTab() {
    final bloc = context.read<DesktopNotesBloc>();
    final isLastOpen = bloc.state.openNoteIds.length == 1;
    if (isLastOpen && ref.read(middlePaneModeProvider) is FileViewerMode) {
      ref.read(middlePaneModeProvider.notifier).state = MiddlePaneMode.browse(
        bloc.state.parentFolderByNoteId[widget.noteId] ?? '',
      );
    }
    bloc.add(CloseNote(widget.noteId));
  }

  String get _displayName {
    final note = ref.watch(fileByIdProvider(widget.noteId));
    if (note == null) return 'Loading...';

    final name = note.path.split('/').last;
    return FileTypeRegistry.forFileName(name).stripExtension(name);
  }
}
