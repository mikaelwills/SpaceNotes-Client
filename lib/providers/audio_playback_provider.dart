import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/client.dart';
import '../services/debug_logger.dart';
import '../services/parametric_eq_service.dart';
import '../widgets/parametric_eq_pad.dart';
import 'notes_providers.dart';

const double audioWaveformBinSeconds = 0.125;
const Duration audioSkipStep = Duration(seconds: 10);
const Duration _positionPollInterval = Duration(milliseconds: 200);
const Duration _endTolerance = Duration(milliseconds: 50);

class AudioPlaybackState {
  const AudioPlaybackState({
    this.fileId,
    this.title = '',
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.peaks,
    this.notches = const [],
    this.eqBypassed = false,
  });

  final String? fileId;
  final String title;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<double>? peaks;
  final List<EqNotch> notches;
  final bool eqBypassed;

  bool get isLoaded => fileId != null;

  bool get isAtEnd =>
      duration > Duration.zero && position + _endTolerance >= duration;

  double get progress => duration == Duration.zero
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  AudioPlaybackState copyWith({
    bool? isPlaying,
    Duration? position,
    List<double>? peaks,
    List<EqNotch>? notches,
    bool? eqBypassed,
  }) {
    return AudioPlaybackState(
      fileId: fileId,
      title: title,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration,
      peaks: peaks ?? this.peaks,
      notches: notches ?? this.notches,
      eqBypassed: eqBypassed ?? this.eqBypassed,
    );
  }
}

class _SavedEq {
  const _SavedEq(this.notches, this.bypassed);
  final List<EqNotch> notches;
  final bool bypassed;
}

final parametricEqServiceProvider =
    Provider<ParametricEqService>((ref) => ParametricEqService());

final audioPlaybackProvider =
    StateNotifierProvider<AudioPlaybackController, AudioPlaybackState>(
  (ref) => AudioPlaybackController(ref, ref.watch(parametricEqServiceProvider)),
);

class AudioPlaybackController extends StateNotifier<AudioPlaybackState> {
  AudioPlaybackController(this._ref, this._eq)
      : super(const AudioPlaybackState()) {
    _eq.onPlaybackStateChanged = _reflectNativePlaybackState;
  }

  final Ref _ref;
  final ParametricEqService _eq;
  Timer? _poll;
  bool _polling = false;
  int _loadGeneration = 0;
  ProviderSubscription<Object?>? _clientSub;
  StreamSubscription<Object?>? _deleteSub;
  final Map<String, Duration> _lastPositions = {};
  final Map<String, _SavedEq> _lastEq = {};

  Duration lastPositionFor(String fileId) =>
      _lastPositions[fileId] ?? Duration.zero;

  void clearLastPosition(String fileId) {
    _lastPositions.remove(fileId);
    _lastEq.remove(fileId);
  }

  Future<void> load({
    required String fileId,
    required String localPath,
    required String title,
  }) async {
    if (state.isLoaded && state.fileId != fileId) {
      Duration outgoingPosition;
      try {
        outgoingPosition = await _eq.position();
      } catch (_) {
        outgoingPosition = state.position;
      }
      _lastPositions[state.fileId!] = outgoingPosition;
      _lastEq[state.fileId!] = _SavedEq(state.notches, state.eqBypassed);
    }

    final generation = ++_loadGeneration;
    bool loaded;
    try {
      loaded = await _eq.load(localPath, title: title);
    } catch (e) {
      await _reconcileAfterFailedLoad();
      rethrow;
    }
    if (!loaded) {
      await _reconcileAfterFailedLoad();
      throw Exception('native player rejected the file');
    }
    if (generation != _loadGeneration) return;

    final duration = await _eq.duration();
    if (generation != _loadGeneration) return;
    await _eq.clearEq();
    if (generation != _loadGeneration) return;

    state =
        AudioPlaybackState(fileId: fileId, title: title, duration: duration);
    _watchDeletion();
    final resumeFrom = _lastPositions[fileId] ?? Duration.zero;
    if (resumeFrom > Duration.zero && resumeFrom < duration) {
      await _eq.seek(resumeFrom);
      if (generation != _loadGeneration) return;
      state = state.copyWith(position: resumeFrom);
    }
    final savedEq = _lastEq[fileId];
    if (savedEq != null && savedEq.notches.isNotEmpty) {
      state = state.copyWith(
        notches: savedEq.notches,
        eqBypassed: savedEq.bypassed,
      );
      if (!savedEq.bypassed) _applyAllBands();
    }
    await play();
    _startPoll();
    _loadWaveform(generation, localPath);
  }

  Future<void> play() async {
    if (!state.isLoaded) return;
    if (state.isAtEnd) {
      await _eq.seek(Duration.zero);
      if (!state.isLoaded) return;
      state = state.copyWith(position: Duration.zero);
    }
    await _eq.play();
    if (!state.isLoaded) return;
    state = state.copyWith(isPlaying: true);
  }

  Future<void> pause() async {
    if (!state.isLoaded) return;
    await _eq.pause();
    if (!state.isLoaded) return;
    state = state.copyWith(isPlaying: false);
  }

  Future<void> togglePlayPause() => state.isPlaying ? pause() : play();

  Future<void> seek(Duration target) async {
    if (!state.isLoaded) return;
    var clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (clamped > state.duration) clamped = state.duration;
    state = state.copyWith(position: clamped);
    await _eq.seek(clamped);
  }

  Future<void> skip(Duration delta) => seek(state.position + delta);

  Future<void> stop() async {
    _loadGeneration++;
    _stopWatching();
    final pending = _eq.stop();
    state = const AudioPlaybackState();
    try {
      await pending;
    } catch (e) {
      debugLogger.error('AUDIO_PLAYBACK', 'Native stop failed', e.toString());
    }
  }

  void setNotch(int index, EqNotch notch) {
    final notches = [...state.notches];
    if (index < notches.length) {
      notches[index] = notch;
    } else {
      notches.add(notch);
    }
    state = state.copyWith(notches: notches);
    if (!state.eqBypassed) _applyAllBands();
  }

  void clearNotch(int index) {
    final notches = [...state.notches];
    if (index < notches.length) notches.removeAt(index);
    state = state.copyWith(notches: notches, eqBypassed: false);
    _eq.clearEq();
    if (notches.isNotEmpty) _applyAllBands();
  }

  void toggleEqBypass() {
    final bypassing = !state.eqBypassed;
    state = state.copyWith(eqBypassed: bypassing);
    if (bypassing) {
      _eq.clearEq();
    } else {
      _applyAllBands();
    }
  }

  void _applyAllBands() {
    final notches = state.notches;
    for (var i = 0; i < notches.length; i++) {
      _eq.setEq(
        band: i,
        frequencyHz: notches[i].frequencyHz,
        gainDb: notches[i].gainDb,
        bandwidth: notches[i].bandwidth,
      );
    }
  }

  void _reflectNativePlaybackState(bool isPlaying) {
    if (!mounted || !state.isLoaded) return;
    state = state.copyWith(isPlaying: isPlaying);
  }

  Future<void> _reconcileAfterFailedLoad() async {
    if (!state.isLoaded) return;
    Duration remaining;
    try {
      remaining = await _eq.duration();
    } catch (_) {
      remaining = Duration.zero;
    }
    if (remaining == Duration.zero) _clearLoaded();
  }

  void _clearLoaded() {
    _stopWatching();
    state = const AudioPlaybackState();
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(_positionPollInterval, (_) => _reflectPosition());
  }

  Future<void> _reflectPosition() async {
    if (_polling || !mounted || !state.isLoaded) return;
    _polling = true;
    final fileId = state.fileId;
    try {
      final position = await _eq.position();
      if (!mounted || state.fileId != fileId) return;
      final reachedEnd = state.duration > Duration.zero &&
          position + _endTolerance >= state.duration;
      if (!reachedEnd) {
        state = state.copyWith(position: position);
        return;
      }
      if (state.isPlaying) {
        await _eq.pause();
        if (!mounted || state.fileId != fileId) return;
      }
      state = state.copyWith(position: state.duration, isPlaying: false);
    } catch (e) {
      debugLogger.error('AUDIO_PLAYBACK', 'Position poll failed', e.toString());
    } finally {
      _polling = false;
    }
  }

  Future<void> _loadWaveform(int generation, String localPath) async {
    final cachePath = '$localPath.peaks.json';
    try {
      final cached = await _readCachedWaveform(cachePath);
      if (cached != null) {
        if (!mounted || generation != _loadGeneration) return;
        debugLogger.info('AUDIO_PLAYBACK', 'Waveform loaded from cache',
            '${cached.length} bins');
        state = state.copyWith(peaks: cached);
        return;
      }

      final peaks = await _eq.waveform(binSeconds: audioWaveformBinSeconds);
      if (!mounted || generation != _loadGeneration) return;
      debugLogger.info(
          'AUDIO_PLAYBACK', 'Waveform loaded', '${peaks.length} bins');
      state = state.copyWith(peaks: peaks);
      unawaited(_writeCachedWaveform(cachePath, peaks));
    } catch (e) {
      debugLogger.error('AUDIO_PLAYBACK', 'Waveform failed', e.toString());
    }
  }

  Future<List<double>?> _readCachedWaveform(String cachePath) async {
    try {
      final file = File(cachePath);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return null;
      return decoded.map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedWaveform(
      String cachePath, List<double> peaks) async {
    try {
      await File(cachePath).writeAsString(jsonEncode(peaks));
    } catch (e) {
      debugLogger.warning(
          'AUDIO_PLAYBACK', 'Could not cache waveform', e.toString());
    }
  }

  void _watchDeletion() {
    _clientSub?.close();
    _deleteSub?.cancel();
    _clientSub = _ref.listen<SpacetimeDbClient?>(
      notesClientProvider,
      (_, client) {
        _deleteSub?.cancel();
        _deleteSub = client?.spaceFile.onDelete.listen((event) {
          if (event.row.id == state.fileId) stop();
        });
      },
      fireImmediately: true,
    );
  }

  void _stopWatching() {
    _poll?.cancel();
    _poll = null;
    _deleteSub?.cancel();
    _deleteSub = null;
    _clientSub?.close();
    _clientSub = null;
  }

  @override
  void dispose() {
    _stopWatching();
    _eq.onPlaybackStateChanged = null;
    super.dispose();
  }
}
