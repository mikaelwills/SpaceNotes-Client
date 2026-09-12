import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/file_transfer_service.dart';
import 'package:spacenotes_client/widgets/download_progress.dart';
import 'package:flutter/material.dart';

void main() {
  group('resumeOffsetFor', () {
    /// This value is also what gets reported as progress before the network
    /// answers, which is the whole point: on bad signal the user must see how
    /// much is already downloaded rather than 0%.
    test('a partial file resumes from its current length', () {
      expect(resumeOffsetFor(4 * 1024 * 1024, 10 * 1024 * 1024), 4 * 1024 * 1024);
    });

    test('nothing on disk starts from zero', () {
      expect(resumeOffsetFor(0, 10 * 1024 * 1024), 0);
    });

    test('an unknown expected size starts from zero', () {
      expect(resumeOffsetFor(4 * 1024 * 1024, 0), 0);
    });

    /// A file already at or past full length cannot be resumed — asking for
    /// bytes from there is either pointless or a 416.
    test('a complete or oversized file starts from zero', () {
      expect(resumeOffsetFor(10 * 1024 * 1024, 10 * 1024 * 1024), 0);
      expect(resumeOffsetFor(11 * 1024 * 1024, 10 * 1024 * 1024), 0);
    });
  });

  group('DownloadProgress', () {
    Future<void> pump(
      WidgetTester tester, {
      required double progress,
      required int receivedBytes,
      required DateTime startedAt,
    }) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DownloadProgress(
            progress: progress,
            receivedBytes: receivedBytes,
            startedAt: startedAt,
          ),
        ),
      ));
    }

    testWidgets('shows the resumed percentage immediately', (tester) async {
      await pump(
        tester,
        progress: 0.4,
        receivedBytes: 4 * 1024 * 1024,
        startedAt: DateTime.now(),
      );

      expect(find.text('40%'), findsOneWidget);
    });

    /// Bytes already on disk are a starting position, not throughput. Counting
    /// them would divide a resumed file's whole size by a fraction of a second
    /// and report hundreds of MB/s before a single new byte arrived.
    testWidgets('does not report a speed for bytes it did not transfer',
        (tester) async {
      await pump(
        tester,
        progress: 0.4,
        receivedBytes: 4 * 1024 * 1024,
        startedAt: DateTime.now().subtract(const Duration(milliseconds: 200)),
      );

      expect(find.textContaining('MB/s'), findsNothing);
      expect(find.textContaining('KB/s'), findsNothing);
      expect(find.textContaining('B/s'), findsNothing);
    });

    testWidgets('reports a speed once new bytes actually arrive',
        (tester) async {
      final startedAt = DateTime.now().subtract(const Duration(seconds: 1));

      await pump(
        tester,
        progress: 0.4,
        receivedBytes: 4 * 1024 * 1024,
        startedAt: startedAt,
      );
      await pump(
        tester,
        progress: 0.5,
        receivedBytes: 5 * 1024 * 1024,
        startedAt: startedAt,
      );

      expect(find.textContaining('/s'), findsOneWidget);
    });
  });
}
