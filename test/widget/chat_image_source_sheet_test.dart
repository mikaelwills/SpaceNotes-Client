import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/widgets/chat_image_source_sheet.dart';

Future<ChatImageSource?> _openAndTap(WidgetTester tester, Key? option) async {
  ChatImageSource? result;
  var closed = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showChatImageSourceSheet(context);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (option == null) {
    await tester.tapAt(const Offset(10, 10));
  } else {
    await tester.tap(find.byKey(option));
  }
  await tester.pumpAndSettle();
  expect(closed, isTrue);
  return result;
}

void main() {
  testWidgets('sheet offers camera and photo library', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatImageSourceSheet())),
    );

    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Photo library'), findsOneWidget);
  });

  testWidgets('tapping Camera returns the camera source', (tester) async {
    final source = await _openAndTap(
      tester,
      const ValueKey('chat_image_source_camera'),
    );

    expect(source, ChatImageSource.camera);
  });

  testWidgets('tapping Photo library returns the library source',
      (tester) async {
    final source = await _openAndTap(
      tester,
      const ValueKey('chat_image_source_library'),
    );

    expect(source, ChatImageSource.library);
  });

  testWidgets('dismissing the sheet returns no source', (tester) async {
    final source = await _openAndTap(tester, null);

    expect(source, isNull);
  });
}
