// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Space app smoke test', (WidgetTester tester) async {
    // Create a mock Space client

    // Build our app and trigger a frame.

    // Verify that our app shows the Space title.
    expect(find.text('Space Mobile'), findsOneWidget);
    expect(find.text('Space Mobile Client'), findsOneWidget);
  });
}
