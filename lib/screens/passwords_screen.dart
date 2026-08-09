import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../generated/space_file.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';
import 'credential_screen.dart';

class PasswordsScreen extends ConsumerStatefulWidget {
  const PasswordsScreen({super.key});

  @override
  ConsumerState<PasswordsScreen> createState() => _PasswordsScreenState();
}

class _PasswordsScreenState extends ConsumerState<PasswordsScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final credentials = ref.watch(filteredCredentialsProvider);
    final total = ref.watch(credentialsProvider).length;

    return Scaffold(
      backgroundColor: SpaceNotesTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _FilterField(controller: _controller),
            if (credentials.isEmpty)
              Expanded(child: _EmptyState(hasAny: total > 0))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: credentials.length,
                  itemBuilder: (context, index) =>
                      _CredentialRow(file: credentials[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterField extends ConsumerWidget {
  const _FilterField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(color: SpaceNotesTheme.fg, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Filter passwords',
          hintStyle: const TextStyle(color: SpaceNotesTheme.dim, fontSize: 14),
          prefixIcon: const Icon(
            Icons.search,
            color: SpaceNotesTheme.dim,
            size: 18,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: SpaceNotesTheme.dim,
                    size: 18,
                  ),
                  onPressed: () {
                    controller.clear();
                    ref.read(credentialFilterProvider.notifier).state = '';
                  },
                ),
          filled: true,
          fillColor: SpaceNotesTheme.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: SpaceNotesTheme.hairlineStrong),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: SpaceNotesTheme.hairlineStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: SpaceNotesTheme.accent),
          ),
        ),
        onChanged: (value) =>
            ref.read(credentialFilterProvider.notifier).state = value,
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.file});

  final SpaceFile file;

  @override
  Widget build(BuildContext context) {
    final entry = CredentialEntry.fromPath(file.path);

    return InkWell(
      onTap: () => context.go('/notes/note/${file.id}'),
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
