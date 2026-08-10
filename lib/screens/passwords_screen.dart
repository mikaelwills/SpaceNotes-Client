import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../generated/space_file.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';
import 'credential_screen.dart';

class PasswordsScreen extends ConsumerWidget {
  const PasswordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentials = ref.watch(filteredCredentialsProvider);
    final total = ref.watch(credentialsProvider).length;

    if (credentials.isEmpty) {
      return SafeArea(child: _EmptyState(hasAny: total > 0));
    }

    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: credentials.length,
        itemBuilder: (context, index) =>
            _CredentialRow(file: credentials[index]),
      ),
    );
  }
}

class _CredentialRow extends ConsumerWidget {
  const _CredentialRow({required this.file});

  final SpaceFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = CredentialEntry.fromPath(file.path);

    return InkWell(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        ref.read(credentialFilterProvider.notifier).state = '';
        context.go('/notes/note/${file.id}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.key_outlined,
              color: SpaceNotesTheme.accent2,
              size: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.site.isEmpty ? entry.account : entry.site,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SpaceNotesTheme.fg,
                      fontSize: 14,
                    ),
                  ),
                  if (entry.site.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.account,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SpaceNotesTheme.dim,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAny});

  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        hasAny ? 'No matching passwords' : 'No passwords in the vault',
        style: const TextStyle(color: SpaceNotesTheme.dim, fontSize: 13),
      ),
    );
  }
}
