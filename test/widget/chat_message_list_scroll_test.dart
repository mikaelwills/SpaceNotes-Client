import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/widgets/chat_message_list.dart';

class _Row {
  const _Row(this.id, this.height);
  final String id;
  final double height;
}

Widget _harness(List<_Row> rows, ScrollController controller) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 400,
        child: ChatMessageList<_Row>(
          items: rows,
          scrollController: controller,
          padding: EdgeInsets.zero,
          showScrollToBottom: false,
          keyBuilder: (r) => ValueKey(r.id),
          itemBuilder: (context, r) => SizedBox(height: r.height, child: Text(r.id)),
        ),
      ),
    ),
  );
}

List<_Row> _rows(int count) => [for (var i = 0; i < count; i++) _Row('m$i', 50)];

void main() {
  testWidgets('scrolled up: a new message does not move the text being read', (tester) async {
    final controller = ScrollController();
    final rows = _rows(30);
    await tester.pumpWidget(_harness(rows, controller));
    controller.jumpTo(500);
    await tester.pump();
    final before = tester.getTopLeft(find.text('m15')).dy;

    await tester.pumpWidget(_harness([...rows, const _Row('new', 120)], controller));
    await tester.pump();

    expect(tester.getTopLeft(find.text('m15')).dy, before);
  });

  testWidgets('scrolled up: a growing last message does not move the text being read', (tester) async {
    final controller = ScrollController();
    final rows = _rows(30);
    await tester.pumpWidget(_harness(rows, controller));
    controller.jumpTo(500);
    await tester.pump();
    final before = tester.getTopLeft(find.text('m15')).dy;

    final grown = [...rows.take(29), const _Row('m29', 300)];
    await tester.pumpWidget(_harness(grown, controller));
    await tester.pump();

    expect(tester.getTopLeft(find.text('m15')).dy, before);
  });

  testWidgets('at the bottom: a new message is followed', (tester) async {
    final controller = ScrollController();
    final rows = _rows(30);
    await tester.pumpWidget(_harness(rows, controller));
    expect(controller.offset, 0);

    await tester.pumpWidget(_harness([...rows, const _Row('new', 120)], controller));
    await tester.pump();

    expect(controller.offset, 0);
    expect(find.text('new'), findsOneWidget);
  });

  testWidgets('a smaller viewport alone does not shift a scrolled-up reader', (tester) async {
    final controller = ScrollController();
    final rows = _rows(30);
    await tester.pumpWidget(_harness(rows, controller));
    controller.jumpTo(500);
    await tester.pump();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 250,
          child: ChatMessageList<_Row>(
            items: rows,
            scrollController: controller,
            padding: EdgeInsets.zero,
            showScrollToBottom: false,
            keyBuilder: (r) => ValueKey(r.id),
            itemBuilder: (context, r) => SizedBox(height: r.height, child: Text(r.id)),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(controller.offset, 500);
  });
}
