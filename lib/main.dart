import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:get_it/get_it.dart';
import 'package:spacenotes_client/providers/notes_providers.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' show SdkLogger;

import 'theme/spacenotes_theme.dart';
import 'services/debug_logger.dart';
import 'blocs/chat/chat_bloc.dart';
import 'blocs/chat/chat_event.dart';
import 'blocs/config/config_cubit.dart';
import 'blocs/desktop_notes/desktop_notes_bloc.dart';
import 'router/app_router.dart';
import 'services/space_channel_service.dart';
import 'services/web_config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await debugLogger.ensureInitialized();
  debugLogger.info('APP', 'SpaceNotes starting');

  SdkLogger.onLog = (level, msg) => debugLogger.log(level, 'SDK', msg);

  final configCubit = ConfigCubit();
  await configCubit.initialize();
  GetIt.I.registerSingleton<ConfigCubit>(configCubit);

  final spaceChannelService = SpaceChannelService();
  GetIt.I.registerSingleton<SpaceChannelService>(spaceChannelService);
  spaceChannelService.initialize();

  final chatBloc = ChatBloc();
  GetIt.I.registerSingleton<ChatBloc>(chatBloc);

  if (kIsWeb) {
    await WebConfigService.tryAutoConfigureSpace(configCubit);
  }

  final container = ProviderContainer();

  final repo = container.read(notesRepositoryProvider);
  await repo.loadSavedConfig();

  if (kIsWeb) {
    await WebConfigService.tryAutoConfigureFromServer(repo);
  }

  runApp(UncontrolledProviderScope(
    container: container,
    child: SpaceNotesApp(
      configCubit: configCubit,
      chatBloc: chatBloc,
      container: container,
    ),
  ));
}

class SpaceNotesApp extends StatefulWidget {
  final ConfigCubit configCubit;
  final ChatBloc chatBloc;
  final ProviderContainer container;

  const SpaceNotesApp({
    super.key,
    required this.configCubit,
    required this.chatBloc,
    required this.container,
  });

  @override
  State<SpaceNotesApp> createState() => _SpaceNotesAppState();
}

class _SpaceNotesAppState extends State<SpaceNotesApp> with WidgetsBindingObserver {
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
      debugLogger.info('APP', 'App resumed - checking connection health');
      widget.chatBloc.add(const ClearTransientActivity());
      final repo = widget.container.read(notesRepositoryProvider);
      repo.tryReconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ConfigCubit>.value(value: widget.configCubit),
        BlocProvider<ChatBloc>.value(value: widget.chatBloc),
        BlocProvider<DesktopNotesBloc>(
          create: (_) => DesktopNotesBloc(),
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
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
            ],
          ),
        ),
      ),
    );
  }
}
