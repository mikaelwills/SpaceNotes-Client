import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/debug_logger.dart';

void main() {
  late List<String> printed;

  setUp(() {
    printed = [];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };
    addTearDown(() => debugPrint = original);
  });

  group('LogSpan', () {
    test('logs a start line through the standard log format', () {
      debugLogger.span('CONN', 'resume-hydration');

      expect(
        printed.any((l) => l.contains('[I][CONN] resume-hydration: span start')),
        isTrue,
        reason: 'span creation should emit a start line, got: $printed',
      );
    });

    test('lap logs the label with elapsed ms', () {
      final span = debugLogger.span('CONN', 'resume-hydration');

      span.lap('SubscribeApplied querySetId=1 tables=4');

      final lapLine = printed.lastWhere(
        (l) => l.contains('SubscribeApplied querySetId=1 tables=4'),
        orElse: () => fail('no lap line emitted, got: $printed'),
      );
      expect(
        RegExp(r'\+\d+ms').hasMatch(lapLine),
        isTrue,
        reason: 'lap line should carry +Nms elapsed, got: $lapLine',
      );
    });

    test('end logs total duration no smaller than the last lap', () {
      final span = debugLogger.span('CONN', 'resume-hydration');

      span.lap('SubscribeApplied querySetId=2 tables=8');
      span.end();

      final lapLine =
          printed.lastWhere((l) => l.contains('querySetId=2 tables=8'));
      final endLine =
          printed.lastWhere((l) => l.contains('resume-hydration: complete'));
      final lapMs =
          int.parse(RegExp(r'\+(\d+)ms').firstMatch(lapLine)!.group(1)!);
      final endMs = int.parse(
          RegExp(r'complete (\d+)ms').firstMatch(endLine)!.group(1)!);
      expect(endMs, greaterThanOrEqualTo(lapMs));
    });

    test('end appends details after the duration', () {
      final span = debugLogger.span('CONN', 'resume-hydration');

      span.end('aborted: Disconnected');

      final endLine =
          printed.lastWhere((l) => l.contains('resume-hydration:'));
      expect(endLine, contains('| aborted: Disconnected'));
    });

    test('an aborted span reads abandoned, not complete', () {
      final span = debugLogger.span('CONN', 'resume-hydration');

      span.end('aborted: Reconnecting...');

      final endLine =
          printed.lastWhere((l) => l.contains('resume-hydration:'));
      expect(endLine, contains('abandoned after'));
      expect(
        endLine,
        isNot(contains('complete')),
        reason: 'an aborted span never did complete — saying so misreads as a '
            'duration of real work',
      );
    });

    test('a successful span still reads complete', () {
      final span = debugLogger.span('CONN', 'resume-hydration');

      span.end('subscriptionsReady');

      final endLine =
          printed.lastWhere((l) => l.contains('resume-hydration:'));
      expect(endLine, contains('complete'));
      expect(endLine, isNot(contains('abandoned')));
    });

    test('paused time is excluded from the duration and flagged', () {
      final span = debugLogger.span('CONN', 'resume-hydration');

      span.pause();
      span.resume();
      span.end('subscriptionsReady');

      final endLine =
          printed.lastWhere((l) => l.contains('resume-hydration:'));
      expect(endLine, contains('(excludes background time)'));
    });

    test('a span that never paused carries no background-time caveat', () {
      final span = debugLogger.span('CONN', 'resume-hydration');

      span.end('subscriptionsReady');

      final endLine =
          printed.lastWhere((l) => l.contains('resume-hydration:'));
      expect(endLine, isNot(contains('excludes background time')));
    });
  });
}
