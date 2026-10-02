import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';
import '../utils/pops_when_file_deleted.dart';
import '../widgets/audio_file_picker.dart';
import '../widgets/audio_file_player.dart';

class AudioViewerScreen extends ConsumerStatefulWidget {
  const AudioViewerScreen({super.key, required this.fileId});

  final String fileId;

  @override
  ConsumerState<AudioViewerScreen> createState() => _AudioViewerScreenState();
}

class _AudioViewerScreenState extends ConsumerState<AudioViewerScreen>
    with PopsWhenFileDeleted<AudioViewerScreen> {
  String? _topFileId;

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(fileByIdProvider(widget.fileId));

    if (!trackFilePresence(file, context)) {
      return const Center(child: CircularProgressIndicator());
    }

    return ColoredBox(
      color: SpaceNotesTheme.bg,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _topFileId == null
                  ? SizedBox(
                      height: 200,
                      child: Center(
                        child: IconButton(
                          iconSize: 28,
                          icon:
                              const Icon(Icons.add, color: SpaceNotesTheme.dim),
                          onPressed: _pickTopFile,
                        ),
                      ),
                    )
                  : AudioFilePlayer(
                      key: ValueKey(_topFileId),
                      fileId: _topFileId!,
                      replaceable: true,
                      onReplace: (newFileId) =>
                          setState(() => _topFileId = newFileId),
                    ),
              const SizedBox(height: 12),
              AudioFilePlayer(
                key: ValueKey(widget.fileId),
                fileId: widget.fileId,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTopFile() async {
    final fileId = await pickAudioFile(context, ref);
    if (fileId == null || !mounted) return;
    setState(() => _topFileId = fileId);
  }
}
