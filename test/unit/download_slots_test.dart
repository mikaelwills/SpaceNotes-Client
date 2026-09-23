import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/file_transfer_service.dart';

void main() {
  group('DownloadSlots', () {
    test('a second request for the same file cancels the first', () async {
      final slots = DownloadSlots();
      final first = await slots.acquire('a.wav');

      final second = slots.acquire('a.wav');
      await Future<void>.delayed(Duration.zero);

      expect(first.isSuperseded, isTrue);
      first.release();
      final acquired = await second;
      expect(acquired.isSuperseded, isFalse);
      acquired.release();
    });

    test('the second request waits until the first has released', () async {
      final slots = DownloadSlots();
      final first = await slots.acquire('a.wav');

      var secondStarted = false;
      final second = slots.acquire('a.wav').then((slot) {
        secondStarted = true;
        return slot;
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(secondStarted, isFalse);

      first.release();
      (await second).release();
      expect(secondStarted, isTrue);
    });

    test('different files do not interfere', () async {
      final slots = DownloadSlots();
      final a = await slots.acquire('a.wav');
      final b = await slots.acquire('b.wav');

      expect(a.isSuperseded, isFalse);
      expect(b.isSuperseded, isFalse);
      a.release();
      b.release();
    });

    test('a third request supersedes one still waiting on the first', () async {
      final slots = DownloadSlots();
      final first = await slots.acquire('a.wav');
      final second = slots.acquire('a.wav');
      final third = slots.acquire('a.wav');
      await Future<void>.delayed(Duration.zero);

      first.release();
      final secondSlot = await second;
      expect(secondSlot.isSuperseded, isTrue);
      secondSlot.release();

      final thirdSlot = await third;
      expect(thirdSlot.isSuperseded, isFalse);
      thirdSlot.release();
    });

    test('releasing frees the key for a fresh request', () async {
      final slots = DownloadSlots();
      (await slots.acquire('a.wav')).release();

      final next = await slots.acquire('a.wav')
          .timeout(const Duration(milliseconds: 100));
      expect(next.isSuperseded, isFalse);
      next.release();
    });
  });

  group('resumeAccepted', () {
    test('a 206 to a ranged request appends', () {
      expect(resumeAccepted(4096, 206), isTrue);
    });

    test('a 200 to a ranged request restarts from zero', () {
      expect(resumeAccepted(4096, 200), isFalse);
    });

    test('an unranged request never appends', () {
      expect(resumeAccepted(0, 206), isFalse);
      expect(resumeAccepted(0, 200), isFalse);
    });
  });
}
