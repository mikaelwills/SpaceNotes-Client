import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/widgets/waveform_scrubber.dart';

Duration _displayed(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(find.descendant(
    of: find.byType(WaveformScrubber),
    matching: find.byType(CustomPaint),
  ));
  final position = (paint.painter as dynamic).position as ValueNotifier<Duration>;
  return position.value;
}

Widget _host({
  required Duration position,
  required bool isPlaying,
  ValueChanged<Duration>? onSeek,
}) =>
    MaterialApp(
      home: Scaffold(
        body: WaveformScrubber(
          peaks: List<double>.filled(720, 0.5),
          binSeconds: 0.25,
          position: position,
          duration: const Duration(minutes: 3),
          isPlaying: isPlaying,
          onSeek: onSeek ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('playhead advances every frame while playing', (tester) async {
    await tester.pumpWidget(_host(position: Duration.zero, isPlaying: false));
    await tester.pumpWidget(
        _host(position: const Duration(seconds: 10), isPlaying: true));

    final samples = <Duration>[];
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      samples.add(_displayed(tester));
    }

    for (var i = 1; i < samples.length; i++) {
      final step = samples[i] - samples[i - 1];
      expect(step.inMilliseconds, inInclusiveRange(15, 17),
          reason: 'frame $i moved ${step.inMilliseconds}ms');
    }
    expect(samples.last, greaterThan(const Duration(seconds: 10)));
  });

  testWidgets('a position poll within tolerance does not yank the playhead',
      (tester) async {
    await tester.pumpWidget(
        _host(position: const Duration(seconds: 10), isPlaying: true));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final before = _displayed(tester);

    await tester.pumpWidget(
        _host(position: const Duration(seconds: 10, milliseconds: 100), isPlaying: true));
    await tester.pump(const Duration(milliseconds: 16));

    final after = _displayed(tester);
    expect(after - before, const Duration(milliseconds: 16));
  });

  testWidgets('paused playhead holds still', (tester) async {
    await tester.pumpWidget(
        _host(position: const Duration(seconds: 42), isPlaying: false));
    await tester.pump(const Duration(seconds: 1));
    expect(_displayed(tester), const Duration(seconds: 42));
  });

  testWidgets('dragging left scrubs forward and seeks on release',
      (tester) async {
    Duration? seeked;
    await tester.pumpWidget(_host(
      position: const Duration(seconds: 30),
      isPlaying: false,
      onSeek: (d) => seeked = d,
    ));

    await tester.drag(find.byType(WaveformScrubber), const Offset(-120, 0));
    await tester.pump();

    expect(seeked, isNotNull);
    expect(seeked!.inMilliseconds, inInclusiveRange(34000, 35000));
    expect(_displayed(tester), seeked);
  });
}
