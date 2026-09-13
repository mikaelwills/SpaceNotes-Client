import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/providers/audio_playback_provider.dart';
import 'package:spacenotes_client/providers/notes_providers.dart';
import 'package:spacenotes_client/services/parametric_eq_service.dart';

class _FakeEq extends ParametricEqService {
  final List<String> calls = [];
  bool loadResult = true;
  bool tearDownOnFailedLoad = false;
  bool nativeLoaded = false;
  Duration nativeDuration = const Duration(minutes: 3);
  Duration nativePosition = Duration.zero;

  ValueChanged<bool> get nativeCallback => onPlaybackStateChanged!;

  @override
  Future<bool> load(String path, {String? title}) async {
    calls.add('load:$path');
    if (!loadResult) {
      if (tearDownOnFailedLoad) nativeLoaded = false;
      return false;
    }
    nativeLoaded = true;
    nativePosition = Duration.zero;
    return true;
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
    nativePosition = position;
  }

  @override
  Future<Duration> position() async => nativePosition;

  @override
  Future<Duration> duration() async =>
      nativeLoaded ? nativeDuration : Duration.zero;

  @override
  Future<List<double>> waveform({required double binSeconds}) async =>
      const [0.5, 1.0];

  @override
  Future<void> setEq({
    required double frequencyHz,
    required double gainDb,
    required double bandwidth,
    int band = 0,
  }) async =>
      calls.add('setEq:$band');

  @override
  Future<void> clearEq() async => calls.add('clearEq');

  @override
  Future<void> stop() async {
    calls.add('stop');
    nativeLoaded = false;
  }
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

Future<void> _pollTick() =>
    Future<void>.delayed(const Duration(milliseconds: 300));

({ProviderContainer container, _FakeEq eq}) _harness() {
  final eq = _FakeEq();
  final container = ProviderContainer(overrides: [
    parametricEqServiceProvider.overrideWithValue(eq),
    notesClientProvider.overrideWith((ref) => null),
  ]);
  addTearDown(container.dispose);
  return (container: container, eq: eq);
}

Future<void> _loadTrack(ProviderContainer container, String fileId) =>
    container.read(audioPlaybackProvider.notifier).load(
          fileId: fileId,
          localPath: '/tmp/$fileId.wav',
          title: '$fileId title',
        );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nothing is loaded until a file loads', () {
    final h = _harness();
    final state = h.container.read(audioPlaybackProvider);
    expect(state.isLoaded, isFalse);
    expect(state.isPlaying, isFalse);
  });

  test('load starts playback and exposes title, duration and position',
      () async {
    final h = _harness();
    await _loadTrack(h.container, 'a');
    await _settle();

    final state = h.container.read(audioPlaybackProvider);
    expect(state.fileId, 'a');
    expect(state.title, 'a title');
    expect(state.isPlaying, isTrue);
    expect(state.duration, const Duration(minutes: 3));
    expect(state.position, Duration.zero);
    expect(state.peaks, const [0.5, 1.0]);
    expect(h.eq.calls, containsAllInOrder(['load:/tmp/a.wav', 'play']));
  });

  test('transport from any surface acts on the one player', () async {
    final h = _harness();
    await _loadTrack(h.container, 'a');
    final controller = h.container.read(audioPlaybackProvider.notifier);

    await controller.togglePlayPause();
    expect(h.container.read(audioPlaybackProvider).isPlaying, isFalse);
    expect(h.eq.calls.last, 'pause');

    await controller.togglePlayPause();
    expect(h.container.read(audioPlaybackProvider).isPlaying, isTrue);
    expect(h.eq.calls.last, 'play');
  });

  test('native pause from lock screen or headphones is reflected', () async {
    final h = _harness();
    await _loadTrack(h.container, 'a');

    h.eq.nativeCallback(false);
    expect(h.container.read(audioPlaybackProvider).isPlaying, isFalse);

    h.eq.nativeCallback(true);
    expect(h.container.read(audioPlaybackProvider).isPlaying, isTrue);
  });

  test('position mirrors the native player rather than a local clock',
      () async {
    final h = _harness();
    await _loadTrack(h.container, 'a');

    h.eq.nativePosition = const Duration(seconds: 42);
    await _pollTick();

    expect(h.container.read(audioPlaybackProvider).position,
        const Duration(seconds: 42));
  });

  test('reaching the end stops at the end and play replays from zero',
      () async {
    final h = _harness();
    await _loadTrack(h.container, 'a');

    h.eq.nativePosition = h.eq.nativeDuration;
    await _pollTick();

    var state = h.container.read(audioPlaybackProvider);
    expect(state.isLoaded, isTrue);
    expect(state.isPlaying, isFalse);
    expect(state.position, state.duration);

    h.eq.calls.clear();
    await h.container.read(audioPlaybackProvider.notifier).play();
    state = h.container.read(audioPlaybackProvider);
    expect(h.eq.calls, ['seek:0', 'play']);
    expect(state.isPlaying, isTrue);
    expect(state.position, Duration.zero);
  });

  test('stop dispatches the native stop and clears the loaded file',
      () async {
    final h = _harness();
    await _loadTrack(h.container, 'a');

    await h.container.read(audioPlaybackProvider.notifier).stop();

    expect(h.eq.calls.last, 'stop');
    expect(h.eq.nativeLoaded, isFalse);
    expect(h.container.read(audioPlaybackProvider).isLoaded, isFalse);
  });

  test('loading a second file replaces the first', () async {
    final h = _harness();
    await _loadTrack(h.container, 'a');
    await _loadTrack(h.container, 'b');
    await _settle();

    final state = h.container.read(audioPlaybackProvider);
    expect(state.fileId, 'b');
    expect(state.title, 'b title');
    expect(state.isPlaying, isTrue);
    expect(h.eq.calls.where((c) => c.startsWith('load:')).toList(),
        ['load:/tmp/a.wav', 'load:/tmp/b.wav']);
  });

  test('a failed load leaves the previous file loaded when native kept it',
      () async {
    final h = _harness();
    await _loadTrack(h.container, 'a');

    h.eq.loadResult = false;
    await expectLater(_loadTrack(h.container, 'b'), throwsException);

    final state = h.container.read(audioPlaybackProvider);
    expect(state.fileId, 'a');
    expect(state.isPlaying, isTrue);
  });

  test('a failed load clears the bar when native tore playback down',
      () async {
    final h = _harness();
    await _loadTrack(h.container, 'a');

    h.eq.loadResult = false;
    h.eq.tearDownOnFailedLoad = true;
    await expectLater(_loadTrack(h.container, 'b'), throwsException);

    expect(h.container.read(audioPlaybackProvider).isLoaded, isFalse);
  });

  test('seek clamps to the track bounds', () async {
    final h = _harness();
    await _loadTrack(h.container, 'a');
    final controller = h.container.read(audioPlaybackProvider.notifier);

    await controller.skip(const Duration(minutes: -1));
    expect(h.container.read(audioPlaybackProvider).position, Duration.zero);

    await controller.seek(const Duration(hours: 1));
    expect(h.container.read(audioPlaybackProvider).position,
        const Duration(minutes: 3));
  });
}
