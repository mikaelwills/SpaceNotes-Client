import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' as stdb;
import '../theme/spacenotes_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_event.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_state.dart' as connection_states;
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../providers/notes_providers.dart';

class NavBar extends ConsumerWidget {
  const NavBar({super.key});

  void _onNewSessionPressed(BuildContext context) {
    context.read<ChatBloc>().add(ClearChat());
    final configState = context.read<ConfigCubit>().state;
    final defaultAgent =
        configState is ConfigLoaded ? configState.defaultAgent : null;
    context.read<SessionBloc>().add(CreateSession(agent: defaultAgent));
  }

  bool _isOnNoteScreen(String location) {
    return location.startsWith('/notes/note/');
  }

  String _safeDecodeUri(String encoded) {
    try {
      return Uri.decodeComponent(encoded);
    } catch (e) {
      return encoded;
    }
  }

  String _extractNotePathFromLocation(String location) {
    // Route is /notes/note/:path(.*) - path spans from index 2 onwards
    final uri = Uri.parse(location);
    final pathSegments = uri.pathSegments;
    if (pathSegments.length >= 3 && pathSegments[1] == 'note') {
      // Join all segments after "note" to reconstruct the full path
      final notePathSegments = pathSegments.sublist(2);
      return notePathSegments.map(_safeDecodeUri).join('/');
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    final isOnNote = _isOnNoteScreen(currentLocation);

    return BlocBuilder<ConnectionBloc, connection_states.ConnectionState>(
      builder: (context, connectionState) {
        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: SpaceNotesTheme.background,
          ),
          child: Row(
            children: [
              // Back button for settings screen
              if (currentLocation == '/settings') ...[
                GestureDetector(
                  onTap: () => context.go("/notes"),
                  child:
                      const Icon(Icons.arrow_back, color: SpaceNotesTheme.text),
                ),
              ],

              // Folder contents navigation
              if (currentLocation.startsWith('/notes/folder/')) ...[
                Expanded(
                  child: _EditableFolderName(
                    folderPath: _extractFullFolderPath(currentLocation),
                    currentName: _extractFolderName(currentLocation),
                  ),
                ),
                const SizedBox(width: 16),
              ],

              // Note screen navigation
              if (isOnNote) ...[
                Expanded(
                  child: _EditableNoteName(
                    notePath: _extractNotePathFromLocation(currentLocation),
                    currentName: _extractNoteName(currentLocation),
                  ),
                ),
                const SizedBox(width: 16),
              ],

              // Chat screen specific navigation (hide on sessions page)
              if (ref.watch(isAiChatModeProvider) && currentLocation != '/sessions') ...[
                GestureDetector(
                  onTap: () => context.go("/sessions"),
                  child: const Icon(Icons.list_outlined,
                      color: SpaceNotesTheme.text),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => _onNewSessionPressed(context),
                  child: const Icon(Icons.create_outlined,
                      color: SpaceNotesTheme.text),
                ),
                const Spacer(),
              ],

              // Spacer for other screens (not folder, not note, not in AI chat mode)
              if (!currentLocation.startsWith('/notes/folder/') &&
                  !isOnNote &&
                  !ref.watch(isAiChatModeProvider))
                const Spacer(),

              // Show ellipsis menu on note screen, settings elsewhere
              // NOTE: Ellipsis menu commented out - using bottom action bar instead
              // if (isOnNote) ...[
              //   _buildNoteMenu(context, ref, currentLocation),
              // ] else ...[
              //   GestureDetector(
              //     onTap: () => context.go("/settings"),
              //     child: const Icon(Icons.settings, color: SpaceNotesTheme.text),
              //   ),
              // ],
              GestureDetector(
                onTap: () => context.go("/settings"),
                child: const Icon(Icons.settings, color: SpaceNotesTheme.text),
              ),
              const SizedBox(width: 16),
              _buildConnectionIndicator(ref),
            ],
          ),
        );
      },
    );
  }

  // NOTE: Ellipsis menu commented out - using bottom action bar in note screen instead
  // Widget _buildNoteMenu(BuildContext context, WidgetRef ref, String currentLocation) {
  //   final notePath = _extractNotePathFromLocation(currentLocation);
  //
  //   return PopupMenuButton<String>(
  //     icon: const Icon(Icons.more_vert, color: SpaceNotesTheme.text),
  //     color: SpaceNotesTheme.surface,
  //     onSelected: (value) async {
  //       // Get the note from provider
  //       final notesAsync = ref.read(notesListProvider);
  //       final note = notesAsync.valueOrNull?.firstWhereOrNull((n) => n.path == notePath);
  //
  //       if (note == null) return;
  //
  //       switch (value) {
  //         case 'move':
  //           NotesListDialogs.showMoveNoteDialog(context, ref, note);
  //           break;
  //         case 'delete':
  //           // Calculate where to navigate after delete based on current location
  //           final currentPath = GoRouterState.of(context).uri.toString();
  //           final String navigateTo;
  //
  //           // If we're viewing a specific note, navigate back appropriately
  //           if (currentPath.startsWith('/notes/') && !currentPath.startsWith('/notes/folder/')) {
  //             final notePath = note.path;
  //
  //             if (notePath.contains('/')) {
  //               // Note is in a folder - navigate back to that folder
  //               final lastSlash = notePath.lastIndexOf('/');
  //               final folderPath = notePath.substring(0, lastSlash);
  //               final encodedFolderPath = Uri.encodeComponent(folderPath);
  //               navigateTo = '/notes/folder/$encodedFolderPath';
  //             } else {
  //               // Note is at root - navigate to notes root
  //               navigateTo = '/notes';
  //             }
  //
  //             print('🗑️  NavBar DELETE: Current path=$currentPath, Will navigate to $navigateTo after delete');
  //
  //             NotesListDialogs.showDeleteNoteConfirmation(
  //               context,
  //               ref,
  //               note,
  //               navigateToAfterDelete: navigateTo,
  //             );
  //           }
  //           break;
  //       }
  //     },
  //     itemBuilder: (context) => [
  //       const PopupMenuItem<String>(
  //         value: 'move',
  //         child: Row(
  //           children: [
  //             Icon(Icons.drive_file_move_outlined, color: SpaceNotesTheme.text, size: 20),
  //             SizedBox(width: 12),
  //             Text(
  //               'Move to folder',
  //               style: TextStyle(
  //                 fontFamily: 'FiraCode',
  //                 fontSize: 14,
  //                 color: SpaceNotesTheme.text,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       const PopupMenuItem<String>(
  //         value: 'delete',
  //         child: Row(
  //           children: [
  //             Icon(Icons.delete_outline, color: SpaceNotesTheme.error, size: 20),
  //             SizedBox(width: 12),
  //             Text(
  //               'Delete',
  //               style: TextStyle(
  //                 fontFamily: 'FiraCode',
  //                 fontSize: 14,
  //                 color: SpaceNotesTheme.error,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  String _extractFullFolderPath(String location) {
    final uri = Uri.parse(location);
    final pathSegments = uri.pathSegments;

    if (pathSegments.length >= 3 && pathSegments[1] == 'folder') {
      final folderPath = _safeDecodeUri(pathSegments[2]);
      return folderPath.endsWith('/')
          ? folderPath.substring(0, folderPath.length - 1)
          : folderPath;
    }

    return '';
  }

  String _extractFolderName(String location) {
    final uri = Uri.parse(location);
    final pathSegments = uri.pathSegments;

    if (pathSegments.length >= 3 && pathSegments[1] == 'folder') {
      final folderPath = _safeDecodeUri(pathSegments[2]);
      final folderName = folderPath.endsWith('/')
          ? folderPath.substring(0, folderPath.length - 1).split('/').last
          : folderPath.split('/').last;
      return folderName;
    }

    return 'Folder';
  }

  String _extractNoteName(String location) {
    // Route is /notes/note/:path(.*) - path spans from index 2 onwards
    final uri = Uri.parse(location);
    final pathSegments = uri.pathSegments;

    if (pathSegments.length >= 3 && pathSegments[1] == 'note') {
      // Join all segments after "note" to reconstruct the full path
      final notePathSegments = pathSegments.sublist(2);
      final fileName = _safeDecodeUri(notePathSegments.last);
      final noteName = fileName.replaceAll('.md', '');
      return noteName;
    }

    return 'Note';
  }

  Widget _buildConnectionIndicator(WidgetRef ref) {
    final clientAsync = ref.watch(spacetimeClientProvider);

    return clientAsync.when(
      loading: () => _buildDisconnectedIndicator(),
      error: (_, __) => _buildDisconnectedIndicator(),
      data: (client) {
        if (client == null) {
          return _buildDisconnectedIndicator();
        }

        return StreamBuilder<stdb.ConnectionStatus>(
          stream: client.connection.connectionStatus,
          initialData: client.connection.status,
          builder: (context, statusSnapshot) {
            final status =
                statusSnapshot.data ?? stdb.ConnectionStatus.disconnected;

            return StreamBuilder<stdb.ConnectionQuality>(
              stream: client.connection.connectionQuality,
              builder: (context, qualitySnapshot) {
                final quality = qualitySnapshot.data;

                return _PulsingHealthBar(
                  status: status,
                  quality: quality,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDisconnectedIndicator() {
    return Container(
      // Match padding from _PulsingHealthBar for consistent width
      padding: const EdgeInsets.all(12),
      child: Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: SpaceNotesTheme.error.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

// Inline editable note name widget
class _EditableNoteName extends ConsumerStatefulWidget {
  final String notePath;
  final String currentName;

  const _EditableNoteName({
    required this.notePath,
    required this.currentName,
  });

  @override
  ConsumerState<_EditableNoteName> createState() => _EditableNoteNameState();
}

class _EditableNoteNameState extends ConsumerState<_EditableNoteName> {
  // 1. CONSTRUCTOR
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;
  Timer? _debounceTimer;
  String _lastRenamedTo = '';

  // 2. INIT
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _lastRenamedTo = widget.currentName;
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 3. BUILD
  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 16,
          color: SpaceNotesTheme.text,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onSubmitted: (_) => _performRename(),
      );
    }

    return GestureDetector(
      onTap: _startEditing,
      child: Text(
        widget.currentName,
        style: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 16,
          color: SpaceNotesTheme.text,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // 5. HELPER FUNCTIONS
  void _onTextChanged() {
    if (!_isEditing) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performRename();
    });
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _isEditing) {
      _debounceTimer?.cancel();
      _performRename();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = widget.currentName;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.currentName.length,
      );
    });
    _focusNode.requestFocus();
  }

  Future<void> _performRename() async {
    final newName = _controller.text.trim();

    if (newName.isEmpty || newName == _lastRenamedTo) {
      return;
    }

    final notesAsync = ref.read(notesListProvider);
    final note = notesAsync.valueOrNull
        ?.firstWhereOrNull((n) => n.path == widget.notePath);

    if (note == null) return;

    final folderPath = widget.notePath.contains('/')
        ? widget.notePath.substring(0, widget.notePath.lastIndexOf('/') + 1)
        : '';

    final newPath = '$folderPath$newName.md';

    if (newPath == widget.notePath) return;

    final repo = ref.read(notesRepositoryProvider);
    debugPrint('🏷️  RENAME: $newPath');
    final success = await repo.renameNote(note.id, newPath);

    if (success) {
      _lastRenamedTo = newName;
      if (mounted) {
        final encodedNewPath =
            newPath.split('/').map(Uri.encodeComponent).join('/');
        context.go('/notes/note/$encodedNewPath');
      }
    }
  }
}

// Inline editable folder name widget
class _EditableFolderName extends ConsumerStatefulWidget {
  final String folderPath;
  final String currentName;

  const _EditableFolderName({
    required this.folderPath,
    required this.currentName,
  });

  @override
  ConsumerState<_EditableFolderName> createState() =>
      _EditableFolderNameState();
}

class _EditableFolderNameState extends ConsumerState<_EditableFolderName> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _isEditing) {
      _performRename();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = widget.currentName;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.currentName.length,
      );
    });
    _focusNode.requestFocus();
  }

  Future<void> _performRename() async {
    final newName = _controller.text.trim();

    setState(() {
      _isEditing = false;
    });

    if (newName.isEmpty || newName == widget.currentName) {
      return;
    }

    // Build new folder path
    final parentPath = widget.folderPath.contains('/')
        ? widget.folderPath.substring(0, widget.folderPath.lastIndexOf('/') + 1)
        : '';
    final newFolderPath = '$parentPath$newName';

    // Use the moveFolder reducer to rename the folder and all its contents
    final repo = ref.read(notesRepositoryProvider);
    debugPrint('🏷️  RENAME FOLDER: ${widget.folderPath} -> $newFolderPath');

    final success = await repo.moveFolder(widget.folderPath, newFolderPath);

    if (mounted && success) {
      // Navigate to the new folder path
      final encodedNewPath = Uri.encodeComponent(newFolderPath);
      context.go('/notes/folder/$encodedNewPath');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 16,
          color: SpaceNotesTheme.text,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onSubmitted: (_) => _performRename(),
      );
    }

    return GestureDetector(
      onLongPress: _startEditing,
      child: Text(
        widget.currentName,
        style: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 16,
          color: SpaceNotesTheme.text,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// Pulsing health bar widget
class _PulsingHealthBar extends ConsumerStatefulWidget {
  final stdb.ConnectionStatus status;
  final stdb.ConnectionQuality? quality;

  const _PulsingHealthBar({
    required this.status,
    required this.quality,
  });

  @override
  ConsumerState<_PulsingHealthBar> createState() => _PulsingHealthBarState();
}

class _PulsingHealthBarState extends ConsumerState<_PulsingHealthBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  DateTime? _lastPongTimestamp;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _PulsingHealthBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentPong = widget.quality?.lastPongReceived;

    // Only pulse if we received a NEW pong (successful server communication)
    if (currentPong != null && currentPong != _lastPongTimestamp) {
      _lastPongTimestamp = currentPong;

      // Debounce pulse animation by 500ms
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          _triggerPulse();
        }
      });
    }
  }

  void _triggerPulse() {
    _pulseController.forward(from: 0.0).then((_) {
      if (mounted) {
        _pulseController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case stdb.ConnectionStatus.connected:
        return SpaceNotesTheme.success;
      case stdb.ConnectionStatus.connecting:
      case stdb.ConnectionStatus.reconnecting:
        return SpaceNotesTheme.warning;
      case stdb.ConnectionStatus.fatalError:
      case stdb.ConnectionStatus.disconnected:
        return SpaceNotesTheme.error;
    }
  }

  double _getHealthScore() {
    if (widget.quality != null) {
      return widget.quality!.healthScore;
    }
    // Infer from status
    switch (widget.status) {
      case stdb.ConnectionStatus.connected:
        return 1.0;
      case stdb.ConnectionStatus.connecting:
      case stdb.ConnectionStatus.reconnecting:
        return 0.5;
      case stdb.ConnectionStatus.disconnected:
      case stdb.ConnectionStatus.fatalError:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final healthScore = _getHealthScore();
    final isDegraded = widget.status != stdb.ConnectionStatus.connected;

    return GestureDetector(
      onTap: isDegraded ? _handleReconnectTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // Larger tap target area (44x44 minimum for touch)
        padding: const EdgeInsets.all(12),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final glowOpacity = (_pulseAnimation.value - 1.0) / 0.15;
            return Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: color.withValues(alpha: 0.15),
                boxShadow: glowOpacity > 0
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: glowOpacity * 0.8),
                          blurRadius: 60,
                          spreadRadius: 20,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: healthScore.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleReconnectTap() {
    _forceReconnect();
  }

  void _forceReconnect() async {
    final repo = ref.read(notesRepositoryProvider);

    // Step 1: Reset connection (closes WebSocket, clears client)
    repo.resetConnection();

    // Step 2: Reconnect (creates new client, fetches data)
    await repo.connectAndGetInitialData();
  }
}
