import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:spacenotes_client/providers/notes_providers.dart';
import 'package:spacenotes_client/providers/connection_providers.dart';
import 'package:provider/provider.dart';

import 'theme/spacenotes_theme.dart';
import 'services/opencode_client.dart';
import 'services/sse_service.dart';
import 'services/message_queue_service.dart';
import 'blocs/connection/connection_bloc.dart';
import 'blocs/session/session_bloc.dart';
import 'blocs/session/session_event.dart';
import 'blocs/session_list/session_list_bloc.dart';
import 'blocs/chat/chat_bloc.dart';
import 'blocs/config/config_cubit.dart';
import 'blocs/config/config_state.dart';
import 'blocs/desktop_notes/desktop_notes_bloc.dart';
import 'router/app_router.dart';
import 'services/web_config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create and initialize ConfigCubit
  final configCubit = ConfigCubit();
  await configCubit.initialize();

  // Create OpenCodeClient with ConfigCubit
  final openCodeClient = OpenCodeClient(configCubit: configCubit);

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

  // Create ConnectionBloc
  final connectionBloc = ConnectionBloc(
    openCodeClient: openCodeClient,
    sessionBloc: sessionBloc,
    configCubit: configCubit,
  );

  final container = ProviderContainer(
    overrides: [
      connectionBlocProvider.overrideWith((ref) => connectionBloc),
    ],
  );

  final repo = container.read(notesRepositoryProvider);
  await repo.loadSavedConfig();

  if (kIsWeb) {
    await WebConfigService.tryAutoConfigureFromServer(repo);
  }

  runApp(UncontrolledProviderScope(
    container: container,
    child: OpenCodeApp(
      openCodeClient: openCodeClient,
      configCubit: configCubit,
      sessionBloc: sessionBloc,
      connectionBloc: connectionBloc,
      container: container,
    ),
  ));
}

class OpenCodeApp extends StatefulWidget {
  final OpenCodeClient openCodeClient;
  final ConfigCubit configCubit;
  final SessionBloc sessionBloc;
  final ConnectionBloc connectionBloc;
  final ProviderContainer container;

  const OpenCodeApp({
    super.key,
    required this.openCodeClient,
    required this.configCubit,
    required this.sessionBloc,
    required this.connectionBloc,
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
        Provider<SSEService>(create: (_) => SSEService(configCubit: widget.configCubit)),
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
          BlocProvider<ConnectionBloc>.value(value: widget.connectionBloc),
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
          BlocProvider<DesktopNotesBloc>(
            create: (context) => DesktopNotesBloc(),
          ),
        ],
        child: Container(
          color: SpaceNotesTheme.background,
          child: SafeArea(
            child: MaterialApp.router(
              title: 'SpaceNotes',
              theme: SpaceNotesTheme.themeData,
              routerConfig: createAppRouter(widget.container),
              debugShowCheckedModeBanner: false,
            ),
          ),
        ),
      ),
    );
  }
}
