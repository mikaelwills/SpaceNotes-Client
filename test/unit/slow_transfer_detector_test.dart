import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/file_transfer_service.dart';

void main() {
  final t0 = DateTime(2026, 9, 23, 8);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  SlowTransferDetector detector() => SlowTransferDetector(
        floorBytesPerSecond: 50 * 1024,
        window: const Duration(seconds: 10),
        startedAt: t0,
      );

  group('SlowTransferDetector', () {
    test('never slow before a full window has passed', () {
      final d = detector();
      expect(d.isSlow(at(9999)), isFalse);
    });

    test('nothing received over a full window is slow', () {
      final d = detector();
      expect(d.isSlow(at(10000)), isTrue);
    });

    test('a steady stream above the floor is not slow', () {
      final d = detector();
      for (var ms = 0; ms <= 10000; ms += 100) {
        d.add(10 * 1024, at(ms));
      }
      expect(d.isSlow(at(10000)), isFalse);
    });

    test('a trickle below the floor is slow', () {
      final d = detector();
      for (var ms = 0; ms <= 10000; ms += 1000) {
        d.add(4 * 1024, at(ms));
      }
      expect(d.isSlow(at(10000)), isTrue);
    });

    test('a fast start that then crawls becomes slow once the burst leaves the window', () {
      final d = detector();
      d.add(20 * 1024 * 1024, at(500));
      for (var ms = 1000; ms <= 20000; ms += 1000) {
        d.add(1024, at(ms));
      }
      expect(d.isSlow(at(10000)), isFalse);
      expect(d.isSlow(at(20000)), isTrue);
    });

    test('exactly the floor is not slow', () {
      final d = detector();
      d.add(50 * 1024 * 10, at(5000));
      expect(d.isSlow(at(10000)), isFalse);
    });
  });
}
