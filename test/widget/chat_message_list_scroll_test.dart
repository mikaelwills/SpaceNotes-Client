import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/widgets/chat_message_list.dart';

class _Row {
  const _Row(this.id, this.height);
  final String id;
  final double height;
}

Widget _harness(List<_Row> rows, {double height = 400}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: height,
        child: ChatMessageList<_Row>(
          items: rows,
          padding: EdgeInsets.zero,
          showScrollToBottom: false,
          keyBuilder: (r) => ValueKey(r.id),
          itemBuilder: (context, r) => SizedBox(height: r.height, child: Text(r.id)),
        ),
      ),
    ),
  );
}

List<_Row> _rows(int count) =>
    [for (var i = 0; i < count; i++) _Row('m$i', 40.0 + (i * 37) % 160)];

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

Future<void> _scrollUp(WidgetTester tester, double by) async {
  await tester.drag(find.byType(Scrollable), Offset(0, by));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens at the newest message', (tester) async {
    await tester.pumpWidget(_harness(_rows(60)));
    await tester.pumpAndSettle();

    expect(find.text('m59'), findsOneWidget);
    final bottom = tester.getBottomLeft(find.text('m59')).dy;
    expect(bottom, closeTo(400, 1));
  });

  testWidgets('dragging up through rows of mixed heights moves smoothly', (tester) async {
    await tester.pumpWidget(_harness(_rows(200)));
    await tester.pumpAndSettle();

    var previous = _position(tester).pixels;
    for (var i = 0; i < 40; i++) {
      await tester.drag(find.byType(Scrollable), const Offset(0, 120));
      await tester.pump();
      final now = _position(tester).pixels;
      expect(now - previous, closeTo(120, 25), reason: 'drag $i jumped');
      previous = now;
    }
  });

  testWidgets('scrolled up: a new message does not move the text being read', (tester) async {
    final rows = _rows(60);
    await tester.pumpWidget(_harness(rows));
    await tester.pumpAndSettle();
    await _scrollUp(tester, 900);
    final reading = find.byType(Text).evaluate().map((e) => (e.widget as Text).data!).toList()[1];
    final before = tester.getTopLeft(find.text(reading)).dy;

    await tester.pumpWidget(_harness([...rows, const _Row('new', 120)]));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text(reading)).dy, before);
  });

  testWidgets('scrolled up: the newest message growing does not move the text being read', (tester) async {
    final rows = _rows(60);
    await tester.pumpWidget(_harness(rows));
    await tester.pumpAndSettle();
    await _scrollUp(tester, 900);
    final reading = find.byType(Text).evaluate().map((e) => (e.widget as Text).data!).toList()[1];
    final before = tester.getTopLeft(find.text(reading)).dy;

    for (var h = 100.0; h <= 600; h += 100) {
      await tester.pumpWidget(_harness([...rows.take(59), _Row('m59', h)]));
      await tester.pump();
      expect(tester.getTopLeft(find.text(reading)).dy, before);
    }
  });

  testWidgets('scrolled up: several arrivals then scroll to bottom shows the newest', (tester) async {
    final rows = _rows(60);
    await tester.pumpWidget(_harness(rows));
    await tester.pumpAndSettle();
    await _scrollUp(tester, 900);

    final more = [...rows, const _Row('a', 80), const _Row('b', 80), const _Row('c', 80)];
    await tester.pumpWidget(_harness(more));
    await tester.pumpAndSettle();
    expect(find.text('c'), findsNothing);

    final state = tester.state<ChatMessageListState<_Row>>(find.byType(ChatMessageList<_Row>));
    state.scrollToBottom();
    await tester.pumpAndSettle();

    expect(tester.getBottomLeft(find.text('c')).dy, closeTo(400, 1));

    await tester.pumpWidget(_harness([...more, const _Row('d', 80)]));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.text('d')).dy, closeTo(400, 1));
  });

  testWidgets('at the bottom: new and growing messages are followed', (tester) async {
    final rows = _rows(60);
    await tester.pumpWidget(_harness(rows));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_harness([...rows, const _Row('new', 120)]));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.text('new')).dy, closeTo(400, 1));

    await tester.pumpWidget(_harness([...rows, const _Row('new', 300)]));
    await tester.pump();
    expect(tester.getBottomLeft(find.text('new')).dy, closeTo(400, 1));
  });

  testWidgets('scrolled up: the keyboard opening keeps the scroll position', (tester) async {
    final rows = _rows(60);
    await tester.pumpWidget(_harness(rows));
    await tester.pumpAndSettle();
    await _scrollUp(tester, 900);
    final before = _position(tester).pixels;

    await tester.pumpWidget(_harness(rows, height: 300));
    await tester.pump();

    expect(_position(tester).pixels, before);
  });
}
