import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import '../generated/space_file.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';
import 'credential_screen.dart';

class PasswordsScreen extends ConsumerWidget {
  const PasswordsScreen({super.key});

  static const _targetCardWidth = 220.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentials = ref.watch(filteredCredentialsProvider);
    final total = ref.watch(credentialsProvider).length;

    if (credentials.isEmpty) {
      return SafeArea(child: _EmptyState(hasAny: total > 0));
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: MasonryGridView.count(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: (MediaQuery.of(context).size.width / _targetCardWidth)
              .floor()
              .clamp(1, 8),
          mainAxisSpacing: _gap,
          crossAxisSpacing: _gap,
          itemCount: credentials.length,
          itemBuilder: (context, index) =>
              _CredentialCard(file: credentials[index]),
        ),
      ),
    );
  }
}

class _CredentialCard extends ConsumerWidget {
  const _CredentialCard({required this.file});

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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: SpaceNotesTheme.card,
          border: Border.all(color: SpaceNotesTheme.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.key_outlined,
              color: SpaceNotesTheme.accent2,
              size: 16,
            ),
            const SizedBox(height: 10),
            Text(
              entry.site.isEmpty ? entry.account : entry.site,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 15,
                color: SpaceNotesTheme.fg,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
                height: 1.2,
              ),
            ),
            if (entry.site.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.account,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontSans,
                  fontSize: 12,
                  color: SpaceNotesTheme.dim,
                ),
              ),
            ],
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
