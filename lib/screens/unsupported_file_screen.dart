import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';

class UnsupportedFileScreen extends ConsumerWidget {
  const UnsupportedFileScreen({super.key, required this.fileId});

  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(fileByIdProvider(fileId));

    if (file == null) {
      return const Scaffold(
        backgroundColor: SpaceNotesTheme.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: SpaceNotesTheme.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insert_drive_file_outlined,
                color: SpaceNotesTheme.dim,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                file.name,
                style: const TextStyle(
                  color: SpaceNotesTheme.fg,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This file type cannot be opened here.',
                style: TextStyle(color: SpaceNotesTheme.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
