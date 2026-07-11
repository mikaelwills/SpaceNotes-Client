import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('autoDispose.family: two watchers share one create, dispose on last', () {
    final subscribeCalls = <String>[];
    final unsubscribeCalls = <String>[];

    final provider = Provider.autoDispose.family<int, String>((ref, sessionId) {
      subscribeCalls.add(sessionId);
      final qsId = subscribeCalls.length;
      ref.onDispose(() => unsubscribeCalls.add('$sessionId:$qsId'));
      return qsId;
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final sub1 = container.listen(provider('A'), (_, __) {}, fireImmediately: true);
    final sub2 = container.listen(provider('A'), (_, __) {}, fireImmediately: true);

    expect(subscribeCalls, ['A'], reason: 'two watchers -> exactly ONE create');
    expect(unsubscribeCalls, isEmpty);

    sub1.close();
    expect(unsubscribeCalls, isEmpty,
        reason: 'first watcher gone, second still holds it -> no dispose');

    sub2.close();
    return Future(() {}).then((_) {
      expect(unsubscribeCalls, ['A:1'],
          reason: 'last watcher gone -> onDispose fires exactly once');
    });
  });

  test('autoDispose.family: distinct keys are independent subscriptions', () {
    final subscribeCalls = <String>[];
    final unsubscribeCalls = <String>[];

    final provider = Provider.autoDispose.family<int, String>((ref, sessionId) {
      subscribeCalls.add(sessionId);
      final qsId = subscribeCalls.length;
      ref.onDispose(() => unsubscribeCalls.add('$sessionId:$qsId'));
      return qsId;
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final subA = container.listen(provider('A'), (_, __) {}, fireImmediately: true);
    final subB = container.listen(provider('B'), (_, __) {}, fireImmediately: true);

    expect(subscribeCalls, ['A', 'B'], reason: 'distinct keys -> separate creates');

    subA.close();
    return Future(() {}).then((_) {
      expect(unsubscribeCalls, ['A:1'],
          reason: 'closing A disposes only A, not B');
    });
  });
}
