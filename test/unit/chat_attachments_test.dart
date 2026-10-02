import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:spacenotes_client/services/chat_attachments.dart';

void main() {
  group('chatAttachmentFolder', () {
    test('uses the agent base name before the host', () {
      expect(
        chatAttachmentFolder('spacenotes@M1MAX'),
        'Chat Attachments/spacenotes',
      );
    });

    test('keeps a bare agent id whole', () {
      expect(chatAttachmentFolder('setbean'), 'Chat Attachments/setbean');
    });
  });

  test('chatAttachmentName numbers from one', () {
    expect(chatAttachmentName('u123-4', 0, 'jpg'), 'u123-4-1.jpg');
    expect(chatAttachmentName('u123-4', 2, 'png'), 'u123-4-3.png');
  });

  group('buildChatMessageText', () {
    const links = [
      ChatAttachmentLink(name: 'u1-1.jpg', fileId: 'a'),
      ChatAttachmentLink(name: 'u1-2.png', fileId: 'b'),
    ];

    test('caption, blank line, then one link per line', () {
      expect(
        buildChatMessageText('  look at these  ', links),
        'look at these\n\n'
        '[u1-1.jpg](spacenotes://file/a)\n'
        '[u1-2.png](spacenotes://file/b)',
      );
    });

    test('links alone when there is no caption', () {
      expect(
        buildChatMessageText('', links),
        '[u1-1.jpg](spacenotes://file/a)\n[u1-2.png](spacenotes://file/b)',
      );
    });

    test('caption alone when there are no links', () {
      expect(buildChatMessageText(' hi ', const []), 'hi');
    });

    test('every link line matches the card syntax', () {
      final lines = buildChatMessageText('x', links).split('\n').skip(2);
      for (final line in lines) {
        expect(vaultFileLinkLine.hasMatch(line), isTrue, reason: line);
      }
    });
  });

  group('splitVaultLinkLines', () {
    test('round-trips what buildChatMessageText writes', () {
      final text = buildChatMessageText('look', const [
        ChatAttachmentLink(name: 'u1-1.jpg', fileId: 'a'),
        ChatAttachmentLink(name: 'u1-2.jpg', fileId: 'b'),
      ]);
      final split = splitVaultLinkLines(text);
      expect(split.text, 'look');
      expect(split.links.map((l) => l.href), [
        'spacenotes://file/a',
        'spacenotes://file/b',
      ]);
      expect(split.links.first.label, 'u1-1.jpg');
    });

    test('leaves inline links in the text', () {
      const text = 'see [this](spacenotes://file/a) here';
      final split = splitVaultLinkLines(text);
      expect(split.text, text);
      expect(split.links, isEmpty);
    });

    test('accepts a bulleted link line and ignores folder links', () {
      const text = '- [a](spacenotes://file/x)\n[f](spacenotes://folder/Gym)';
      final split = splitVaultLinkLines(text);
      expect(split.links.single.href, 'spacenotes://file/x');
      expect(split.text, '[f](spacenotes://folder/Gym)');
    });

    test('plain text is untouched', () {
      final split = splitVaultLinkLines('hello\nworld');
      expect(split.text, 'hello\nworld');
      expect(split.links, isEmpty);
    });
  });

  group('normalizeChatImage', () {
    Uint8List png(int w, int h) =>
        Uint8List.fromList(image_lib.encodePng(image_lib.Image(width: w, height: h)));

    test('small png passes through untouched', () {
      final bytes = png(10, 10);
      final out = normalizeChatImage((bytes, 'a.png'))!;
      expect(out.extension, 'png');
      expect(out.bytes, same(bytes));
    });

    test('jpeg extension is normalised to jpg', () {
      final bytes = Uint8List.fromList(
        image_lib.encodeJpg(image_lib.Image(width: 4, height: 4)),
      );
      expect(normalizeChatImage((bytes, 'a.JPEG'))!.extension, 'jpg');
    });

    test('oversized image is shrunk to 2048 on the long edge as jpg', () {
      final out = normalizeChatImage((png(3000, 1000), 'big.png'))!;
      expect(out.extension, 'jpg');
      final decoded = image_lib.decodeJpg(out.bytes)!;
      expect(decoded.width, 2048);
      expect(decoded.height, lessThan(1000));
    });

    test('unlisted format is re-encoded as jpg', () {
      final bmp = Uint8List.fromList(
        image_lib.encodeBmp(image_lib.Image(width: 5, height: 5)),
      );
      expect(normalizeChatImage((bmp, 'x.bmp'))!.extension, 'jpg');
    });

    test('undecodable unknown bytes are refused', () {
      expect(
        normalizeChatImage((Uint8List.fromList([1, 2, 3]), 'x.heic')),
        isNull,
      );
    });
  });
}
