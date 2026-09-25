import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _card(String prefix, int i) => SizedBox(
      key: ValueKey('$prefix$i'),
      height: 80.0 + (i * 37 % 160),
      child: Text('$prefix$i'),
    );

Widget _lazySection(String prefix, int count) => SliverMasonryGrid.extent(
      maxCrossAxisExtent: 180,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childCount: count,
      itemBuilder: (context, i) => _card(prefix, i),
    );

Widget _eagerSection(String prefix, int count) => SliverToBoxAdapter(
      child: MasonryGridView.extent(
        shrinkWrap: true,
        primary: false,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        itemCount: count,
        itemBuilder: (context, i) => _card(prefix, i),
      ),
    );

Future<List<double>> _scrollDown(WidgetTester tester, Widget firstSection) async {
  final controller = ScrollController();
  await tester.binding.setSurfaceSize(const Size(400, 800));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        controller: controller,
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 30, child: Text('VIEWED'))),
          firstSection,
          const SliverToBoxAdapter(child: SizedBox(height: 30, child: Text('UPDATED'))),
          _lazySection('u', 50),
        ],
      ),
    ),
  ));

  final offsets = <double>[];
  for (var step = 0; step < 40; step++) {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pump();
    offsets.add(controller.offset);
  }
  return offsets;
}

bool _everMovedBackwards(List<double> offsets) {
  for (var i = 1; i < offsets.length; i++) {
    if (offsets[i] < offsets[i - 1] - 1) return true;
  }
  return false;
}

void main() {
  testWidgets('a lazy masonry section followed by another jumps back when it scrolls out of view', (tester) async {
    final offsets = await _scrollDown(tester, _lazySection('v', 20));
    expect(_everMovedBackwards(offsets), isTrue, reason: '$offsets');
  });

  testWidgets('an eager first section keeps scrolling down smoothly into the second', (tester) async {
    final offsets = await _scrollDown(tester, _eagerSection('v', 20));
    expect(_everMovedBackwards(offsets), isFalse, reason: '$offsets');
    expect(offsets.last, greaterThan(3000));
  });
}
