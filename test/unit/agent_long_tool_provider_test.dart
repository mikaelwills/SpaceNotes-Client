import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/generated/agent_activity.dart';
import 'package:spacenotes_client/providers/chat_providers.dart';

const _agent = 'spacenotes@M1MAX';

final _state = StateProvider<String?>((ref) => null);

void _testLongTool(
  String description,
  Future<void> Function(
    WidgetTester tester,
    void Function(String state) set,
    bool Function() shown,
  ) body,
) {
  testWidgets(description, (tester) async {
    final container = ProviderContainer(overrides: [
      agentActivityProvider.overrideWith((ref, agentId) {
        final state = ref.watch(_state);
        if (state == null) return null;
        return AgentActivity(
          agentId: agentId,
          state: state,
          lastToolEvent: null,
          updatedAt: Int64(0),
        );
      }),
    ]);
    container.listen(agentLongToolProvider(_agent), (_, __) {});

    await body(
      tester,
      (state) => container.read(_state.notifier).state = state,
      () => container.read(agentLongToolProvider(_agent)),
    );

    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });
}

void main() {
  _testLongTool('stays hidden for a tool shorter than the delay',
      (tester, set, shown) async {
    set('tool_use');
    await tester.pump(const Duration(milliseconds: 500));
    set('thinking');
    await tester.pump(longToolDelay);

    expect(shown(), isFalse);
  });

  _testLongTool('shows once a tool has run for the delay',
      (tester, set, shown) async {
    set('tool_use');
    await tester.pump(const Duration(milliseconds: 999));
    expect(shown(), isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    expect(shown(), isTrue);
  });

  _testLongTool('each new tool restarts the delay',
      (tester, set, shown) async {
    set('tool_use');
    await tester.pump(const Duration(milliseconds: 700));
    set('thinking');
    await tester.pump(const Duration(milliseconds: 50));
    set('tool_use');
    await tester.pump(const Duration(milliseconds: 700));

    expect(shown(), isFalse);
  });

  _testLongTool('hides as soon as the tool ends', (tester, set, shown) async {
    set('tool_use');
    await tester.pump(longToolDelay);
    expect(shown(), isTrue);

    set('thinking');
    await tester.pump();
    expect(shown(), isFalse);
  });
}
