import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import '../generated/connected_user.dart';
import '../providers/call_providers.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';

final connectedUsersProvider = Provider.autoDispose<List<ConnectedUser>>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return const [];
  final rows = watchListenable(ref, client.connectedUser.rows);
  final myIdentity = client.identity;
  return rows
      .where((u) => myIdentity == null || u.identity != myIdentity)
      .toList();
});

final myConnectedUserProvider = Provider.autoDispose<ConnectedUser?>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return null;
  final rows = watchListenable(ref, client.connectedUser.rows);
  final myIdentity = client.identity;
  if (myIdentity == null) return null;
  for (final u in rows) {
    if (u.identity == myIdentity) return u;
  }
  return null;
});

class OnlineUsersScreen extends ConsumerWidget {
  const OnlineUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(connectedUsersProvider);
    final myIdentity = ref.watch(myIdentityProvider);
    final myUser = ref.watch(myConnectedUserProvider);

    return Column(
      children: [
        if (myIdentity != null)
          _MyProfileCard(
            myUser: myUser,
            myIdentity: myIdentity,
            onEditName: () =>
                _showSetNameDialog(context, ref, myUser?.name ?? ''),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const Text(
                'Contacts',
                style: TextStyle(
                  color: SpaceNotesTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: SpaceNotesTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${users.length}',
                  style: const TextStyle(
                    color: SpaceNotesTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 48,
                          color: SpaceNotesTheme.textSecondary
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text(
                        'No one else online',
                        style: TextStyle(
                            color: SpaceNotesTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _ContactTile(
                      user: user,
                      onCall: () => _startCall(context, ref, user.identity),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showSetNameDialog(
      BuildContext context, WidgetRef ref, String currentName) {
    final nameController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    void submit(BuildContext dialogContext) {
      if (formKey.currentState?.validate() ?? false) {
        final name = nameController.text.trim();
        Navigator.of(dialogContext).pop();
        final repo = ref.read(notesRepositoryProvider);
        repo.client?.reducers.setDisplayName(name: name);
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SpaceNotesTheme.dialogSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: SpaceNotesTheme.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        title: const Text(
          'Set Display Name',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: SpaceNotesTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => submit(dialogContext),
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.text,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: const TextStyle(color: SpaceNotesTheme.textSecondary),
              filled: true,
              fillColor: SpaceNotesTheme.inputSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: SpaceNotesTheme.primary.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: SpaceNotesTheme.primary.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: SpaceNotesTheme.primary),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
                foregroundColor: SpaceNotesTheme.textSecondary),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => submit(dialogContext),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _startCall(BuildContext context, WidgetRef ref, Identity callee) {
    final callService = ref.read(callServiceProvider);
    final repo = ref.read(notesRepositoryProvider);
    callService.setClient(repo.client);
    callService.requestCall(callee);

    final navigator = GoRouter.of(context);
    Future.delayed(const Duration(milliseconds: 500), () {
      final client = repo.client;
      if (client == null) return;
      final sessions = client.callSession.iter().where((s) {
        return s.caller == client.identity && s.callee == callee;
      }).toList();
      if (sessions.isNotEmpty) {
        navigator.goNamed('call',
            pathParameters: {'sessionId': sessions.last.sessionId.toString()});
      }
    });
  }
}

class _MyProfileCard extends StatelessWidget {
  final ConnectedUser? myUser;
  final Identity myIdentity;
  final VoidCallback onEditName;

  const _MyProfileCard({
    required this.myUser,
    required this.myIdentity,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    final hasName = myUser != null && myUser!.name.isNotEmpty;
    final displayName = hasName ? myUser!.name : 'Set your name';
    final identityShort = myIdentity.toHexString.substring(0, 12);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SpaceNotesTheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _Avatar(name: hasName ? myUser!.name : '', size: 44, isPrimary: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: hasName
                        ? SpaceNotesTheme.text
                        : SpaceNotesTheme.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontStyle: hasName ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      identityShort,
                      style: const TextStyle(
                        color: SpaceNotesTheme.textSecondary,
                        fontSize: 11,
                        fontFamily: 'FiraCode',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEditName,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SpaceNotesTheme.inputSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: SpaceNotesTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final ConnectedUser user;
  final VoidCallback onCall;

  const _ContactTile({required this.user, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final hasName = user.name.isNotEmpty;
    final displayName =
        hasName ? user.name : user.identity.toHexString.substring(0, 12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCall,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _Avatar(name: hasName ? user.name : '', size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: SpaceNotesTheme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: hasName ? null : 'FiraCode',
                      ),
                    ),
                    if (hasName) ...[
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Online',
                            style: TextStyle(
                              color: SpaceNotesTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onCall,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: SpaceNotesTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      size: 20,
                      color: SpaceNotesTheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  final bool isPrimary;

  const _Avatar(
      {required this.name, required this.size, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = isPrimary ? SpaceNotesTheme.primary : _colorFromName(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Color _colorFromName(String name) {
    if (name.isEmpty) return SpaceNotesTheme.textSecondary;
    final colors = [
      const Color(0xFF00D9FF),
      const Color(0xFF7C3AED),
      const Color(0xFFFF6B6B),
      const Color(0xFF51CF66),
      const Color(0xFFFFB86C),
      const Color(0xFFFF79C6),
      const Color(0xFF69DB7C),
      const Color(0xFF748FFC),
    ];
    final hash = name.codeUnits.fold<int>(0, (prev, c) => prev + c);
    return colors[hash % colors.length];
  }
}
