import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:get_it/get_it.dart';
import 'package:spacenotes_client/providers/notes_providers.dart';
import 'package:spacetimedb_sdk/protocol.dart' show SdkLogger, SdkLogLevel;

import 'theme/spacenotes_theme.dart';
import 'services/debug_logger.dart';
import 'blocs/config/config_cubit.dart';
import 'blocs/desktop_notes/desktop_notes_bloc.dart';
import 'router/app_router.dart';
import 'services/web_config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await debugLogger.ensureInitialized();
  debugLogger.info('APP', 'SpaceNotes starting');

  configureSdkLogging();

  final configCubit = ConfigCubit();
  await configCubit.initialize();
  GetIt.I.registerSingleton<ConfigCubit>(configCubit);

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
      container: container,
    ),
  ));
}

const _sdkLogNoisePrefixes = [
  'WS_RX',
  'RX_MSG',
  'syncPendingMutations: no pending mutations',
  'syncPendingMutations: finished',
  'syncPendingMutations: starting',
];

final _singleRowChangePattern = RegExp(
  r'^EMIT_CHANGES\[\w+\]: inserts=0, updates=1, deletes=0$',
);

bool _isSdkLogNoise(String msg) {
  for (final prefix in _sdkLogNoisePrefixes) {
    if (msg.startsWith(prefix)) return true;
  }
  return _singleRowChangePattern.hasMatch(msg);
}

void configureSdkLogging() {
  SdkLogger.onLog = (level, msg) {
    if (level == 'D' && _isSdkLogNoise(msg)) return;
    debugLogger.log(level, 'SDK', msg);
  };
  SdkLogger.level = SdkLogLevel.debug;
}

class SpaceNotesApp extends StatefulWidget {
  final ConfigCubit configCubit;
  final ProviderContainer container;

  const SpaceNotesApp({
    super.key,
    required this.configCubit,
    required this.container,
  });

  @override
  State<SpaceNotesApp> createState() => _SpaceNotesAppState();
}

class _SpaceNotesAppState extends State<SpaceNotesApp>
    with WidgetsBindingObserver {
  Timer? _pauseTimer;
  static const _pauseDebounce = Duration(seconds: 3);

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
    _pauseTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugLogger.info('APP', 'Lifecycle: ${state.name}');
    final repo = widget.container.read(notesRepositoryProvider);
    if (state == AppLifecycleState.resumed) {
      _pauseTimer?.cancel();
      _pauseTimer = null;
      debugLogger.info('APP', 'App resumed - checking connection health');
      repo.tryReconnect(resetAttempts: true, force: true);
    } else if (state == AppLifecycleState.paused) {
      _pauseTimer?.cancel();
      _pauseTimer = Timer(_pauseDebounce, () {
        _pauseTimer = null;
        debugLogger.info('APP', 'App paused - disconnecting');
        repo.handleAppPaused();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ConfigCubit>.value(value: widget.configCubit),
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
