import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:spacenotes_client/providers/notes_providers.dart';
import 'package:provider/provider.dart';

import 'theme/spacenotes_theme.dart';
import 'services/opencode_client.dart';
import 'services/sse_service.dart';
import 'services/message_queue_service.dart';
import 'services/notes_api_service.dart';
import 'blocs/connection/connection_bloc.dart';
import 'blocs/session/session_bloc.dart';
import 'blocs/session/session_event.dart';
import 'blocs/session_list/session_list_bloc.dart';
import 'blocs/chat/chat_bloc.dart';
import 'blocs/config/config_cubit.dart';
import 'blocs/config/config_state.dart';
import 'blocs/instance/instance_bloc.dart';
import 'blocs/obsidian_instance/obsidian_instance_bloc.dart';
import 'blocs/obsidian_connection/obsidian_connection_cubit.dart';
import 'blocs/spacetimedb_instance/spacetimedb_instance_bloc.dart';
import 'router/app_router.dart';
import 'config/opencode_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create and initialize ConfigCubit
  final configCubit = ConfigCubit();
  await configCubit.initialize();

  // Set the cubit for backward compatibility
  OpenCodeConfig.setConfigCubit(configCubit);

  print('🚀 Creating services...');

  // Create unconfigured Obsidian service
  final notesService = NotesService.unconfigured();
  print('  Created NotesService (unconfigured)');

  print('  SpacetimeDbNotesRepository created');
  print('✅ All services created');

  final openCodeClient = OpenCodeClient();

  // Apply saved provider/model settings if available
  final configState = configCubit.state;
  if (configState is ConfigLoaded &&
      configState.selectedProviderID != null &&
      configState.selectedModelID != null) {
    openCodeClient.setProvider(
        configState.selectedProviderID!, configState.selectedModelID!);
  }

  // Create SessionBloc and initialize with stored session
  final sessionBloc = SessionBloc(
    openCodeClient: openCodeClient,
    configCubit: configCubit,
  );
  sessionBloc.add(LoadStoredSession());

  final container = ProviderContainer();

  runApp(UncontrolledProviderScope(
    container: container,
    child: OpenCodeApp(
      openCodeClient: openCodeClient,
      configCubit: configCubit,
      sessionBloc: sessionBloc,
      notesService: notesService,
      container: container,
    ),
  ));
}

class OpenCodeApp extends StatefulWidget {
  final OpenCodeClient openCodeClient;
  final ConfigCubit configCubit;
  final SessionBloc sessionBloc;
  final NotesService notesService;
  final ProviderContainer container;

  const OpenCodeApp({
    super.key,
    required this.openCodeClient,
    required this.configCubit,
    required this.sessionBloc,
    required this.notesService,
    required this.container,
  });

  @override
  State<OpenCodeApp> createState() => _OpenCodeAppState();
}

class _OpenCodeAppState extends State<OpenCodeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize SpacetimeDB connection after app starts
    // This prevents blocking the splash screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = widget.container.read(notesRepositoryProvider);
      repo.connectAndGetInitialData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('🔥 APP RESUMED - Checking connection health');

      // Get repository and trigger connection check
      final repo = widget.container.read(notesRepositoryProvider);

      // This will call _ensureConnected() which checks status and reconnects if degraded
      repo.connectAndGetInitialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<OpenCodeClient>.value(value: widget.openCodeClient),
        Provider<SSEService>(create: (_) => SSEService()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ConfigCubit>.value(value: widget.configCubit),
          BlocProvider<SessionBloc>.value(value: widget.sessionBloc),
          BlocProvider<SessionListBloc>(
            create: (context) => SessionListBloc(
              openCodeClient: context.read<OpenCodeClient>(),
            ),
          ),
          BlocProvider<ConnectionBloc>(
            create: (context) => ConnectionBloc(
              openCodeClient: context.read<OpenCodeClient>(),
              sessionBloc: widget.sessionBloc,
            ),
          ),
          Provider<MessageQueueService>(
            create: (context) => MessageQueueService(
              connectionBloc: context.read<ConnectionBloc>(),
              sessionBloc: widget.sessionBloc,
            ),
          ),
          BlocProvider<ChatBloc>(
            create: (context) {
              final chatBloc = ChatBloc(
                sessionBloc: widget.sessionBloc,
                sseService: context.read<SSEService>(),
                openCodeClient: context.read<OpenCodeClient>(),
                messageQueueService: context.read<MessageQueueService>(),
              );

              // Initialize the MessageQueueService's ChatBloc listener
              context
                  .read<MessageQueueService>()
                  .initChatBlocListener(chatBloc);

              return chatBloc;
            },
          ),
          BlocProvider<InstanceBloc>(
            create: (context) => InstanceBloc(),
          ),
          BlocProvider<ObsidianInstanceBloc>(
            create: (context) => ObsidianInstanceBloc(),
          ),
          BlocProvider<ObsidianConnectionCubit>(
            create: (context) => ObsidianConnectionCubit(),
          ),
          BlocProvider<SpacetimeDbInstanceBloc>(
            create: (context) => SpacetimeDbInstanceBloc(),
          ),
        ],
        child: Container(
          color: SpaceNotesTheme.background,
          child: SafeArea(
            child: MaterialApp.router(
              title: 'OpenCode Mobile',
              theme: SpaceNotesTheme.themeData,
              routerConfig: appRouter,
              debugShowCheckedModeBanner: false,
            ),
          ),
        ),
      ),
    );
  }
}
