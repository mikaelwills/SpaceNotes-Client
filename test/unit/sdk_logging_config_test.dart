import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/main.dart';
import 'package:spacetimedb_sdk/protocol.dart' show SdkLogger, SdkLogLevel;

void main() {
  tearDown(() {
    SdkLogger.onLog = null;
    SdkLogger.level = SdkLogLevel.warning;
  });

  group('SdkLogger gating', () {
    test('info lines never reach onLog at the default warning level', () {
      final received = <String>[];
      SdkLogger.onLog = (level, msg) => received.add('[$level] $msg');

      SdkLogger.i('Re-subscribing to 3 query sets in place...');
      SdkLogger.d('RX_MSG: SubscribeApplied');

      expect(
        received,
        isEmpty,
        reason: 'the level gate runs before onLog, so I/D lines are dropped',
      );
    });
  });

  group('configureSdkLogging', () {
    test('opens the gate to debug in every build type', () {
      configureSdkLogging();

      expect(SdkLogger.level, SdkLogLevel.debug);
    });

    test('drops per-frame WS_RX and RX_MSG noise but keeps other debug lines',
        () {
      final printed = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) printed.add(message);
      };
      addTearDown(() => debugPrint = original);

      configureSdkLogging();
      SdkLogger.d('WS_RX: 412 bytes, head=01 02');
      SdkLogger.d('RX_MSG: SubscribeApplied');
      SdkLogger.d('Applying 3 tables for query set 1');

      expect(printed.any((l) => l.contains('WS_RX')), isFalse);
      expect(printed.any((l) => l.contains('RX_MSG')), isFalse);
      expect(
        printed.any((l) => l.contains('Applying 3 tables for query set 1')),
        isTrue,
        reason: 'non-noise debug lines must still reach the device log',
      );
    });

    test('routes SDK info lines into debugLogger', () {
      final printed = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) printed.add(message);
      };
      addTearDown(() => debugPrint = original);

      configureSdkLogging();
      SdkLogger.i('Re-subscribing to 3 query sets in place...');

      expect(
        printed.any((l) =>
            l.contains('[I][SDK] Re-subscribing to 3 query sets in place...')),
        isTrue,
        reason: 'info lines should now pass the gate and reach debugLogger, '
            'got: $printed',
      );
    });
  });
}
