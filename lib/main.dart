import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:get_it/get_it.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:spacenotes_client/providers/notes_providers.dart';
import 'package:spacetimedb_sdk/protocol.dart' show SdkLogger, SdkLogLevel;
import 'package:window_manager/window_manager.dart';

import 'theme/spacenotes_theme.dart';
import 'services/debug_logger.dart';
import 'services/marionette_extensions.dart';
import 'providers/preferences_provider.dart';
import 'services/exit_recorder.dart';
import 'services/resume_pending_transfers.dart';
import 'providers/file_transfer_providers.dart';
import 'providers/upload_progress_providers.dart';
import 'providers/download_queue_provider.dart';
import 'platform/capabilities.dart';
import 'blocs/config/config_cubit.dart';
import 'blocs/desktop_notes/desktop_notes_bloc.dart';
import 'router/app_router.dart';
import 'services/web_config_service.dart';

void main() async {
  if (kDebugMode) {
    final logCollector = PrintLogCollector();
    MarionetteBinding.ensureInitialized(
      MarionetteConfiguration(logCollector: logCollector),
    );
    debugLogger.sink = logCollector.addLog;
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  if (!kIsWeb && Platform.isMacOS) {
    await windowManager.ensureInitialized();
  }

  await debugLogger.ensureInitialized();

  final priorOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    debugLogger.error(
      'FLUTTER',
      details.exceptionAsString(),
      details.library,
    );
    priorOnError?.call(details);
  };
  debugLogger.info('APP', 'SpaceNotes starting');
  await exitRecorder.init();

  configureSdkLogging();

  final configCubit = ConfigCubit();
  await configCubit.initialize();
  GetIt.I.registerSingleton<ConfigCubit>(configCubit);

  if (kIsWeb) {
    await WebConfigService.tryAutoConfigureSpace(configCubit);
  }

  final preferences = await PreferencesNotifier.load();

  final container = ProviderContainer(
    overrides: [
      preferencesProvider.overrideWith(
        (ref) => PreferencesNotifier(preferences),
      ),
    ],
  );

  if (kDebugMode) {
    registerSpaceNotesMarionetteExtensions(container);
  }

  final repo = container.read(notesRepositoryProvider);
  await repo.loadSavedConfig();

  if (kIsWeb) {
    await WebConfigService.tryAutoConfigureFromServer(repo);
  }

  await repo.initializeOfflineFirst();

  runApp(UncontrolledProviderScope(
    container: container,
    child: SpaceNotesApp(
      configCubit: configCubit,
      container: container,
    ),
  ));
}

const _sdkLogNoisePrefixes = [
  'RX_MSG',
  'syncPendingMutations: no pending mutations',
  'syncPendingMutations: finished',
  'syncPendingMutations: starting',
];

final _singleRowChangePattern = RegExp(
  r'^EMIT_CHANGES\[\w+\]: inserts=(0, updates=(0, deletes=1|1, deletes=0)'
  r'|1, updates=0, deletes=0)$',
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
    if (msg.startsWith('WS_RX')) {
      final bytes =
          int.tryParse(RegExp(r'WS_RX: (\d+)').firstMatch(msg)?.group(1) ?? '');
      if (bytes == null || bytes < 100000) return;
      debugLogger.log(level, 'SDK', msg.split(', head=').first);
      return;
    }
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
      _resumeInterruptedUploads();
      _restoreDownloadQueue();
    });
  }

  Future<void> _restoreDownloadQueue() async {
    if (!Capabilities.canDownloadFiles) return;
    try {
      await widget.container.read(downloadQueueProvider.notifier).restore();
    } catch (e) {
      debugLogger.warning('RESUME', 'Could not restore download queue', e.toString());
    }
  }

  /// Picks up uploads the last run did not finish.
  ///
  /// Deliberately not awaited: a slow or dead network must never hold up the
  /// first frame. Each upload continues from the offset the server confirms,
  /// so nothing already sent goes up twice.
  Future<void> _resumeInterruptedUploads() async {
    try {
      final pending = await findPendingTransfers();
      if (pending.uploads.isEmpty) return;

      debugLogger.info('RESUME', 'Continuing interrupted uploads',
          'count=${pending.uploads.length}');

      await resumeUploads(
        pending,
        widget.container.read(fileTransferServiceProvider),
        widget.container.read(uploadBatchProvider.notifier),
      );
    } catch (e) {
      debugLogger.warning('RESUME', 'Could not resume uploads', e.toString());
    }
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
    exitRecorder.record(state.name);
    final repo = widget.container.read(notesRepositoryProvider);
    if (state == AppLifecycleState.resumed) {
      widget.container.read(downloadQueueProvider.notifier).setForeground(true);
      _pauseTimer?.cancel();
      _pauseTimer = null;
      repo.resumeSpanClocks();
      debugLogger.info('APP', 'App resumed - checking connection health');
      repo.tryReconnect(resetAttempts: true, force: true);
    } else if (state == AppLifecycleState.paused) {
      widget.container.read(downloadQueueProvider.notifier).setForeground(false);
      repo.pauseSpanClocks();
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
