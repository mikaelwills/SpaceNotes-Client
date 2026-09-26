import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:spacenotes_client/widgets/chat_file_card.dart';

List<md.Element> _cards(String markdown) {
  final doc = md.Document(
    blockSyntaxes: const [VaultCardSyntax()],
    encodeHtml: false,
  );
  final found = <md.Element>[];
  void walk(List<md.Node> nodes) {
    for (final node in nodes) {
      if (node is md.Element) {
        if (node.tag == vaultCardTag) found.add(node);
        walk(node.children ?? const []);
      }
    }
  }

  walk(doc.parseLines(markdown.split('\n')));
  return found;
}

void main() {
  group('VaultCardSyntax', () {
    test('a file link on its own line becomes a card', () {
      final cards = _cards('[Jeremy.md](spacenotes://file/8d30bafc)');
      expect(cards, hasLength(1));
      expect(cards.single.attributes['href'], 'spacenotes://file/8d30bafc');
      expect(cards.single.attributes['label'], 'Jeremy.md');
    });

    test('a bulleted file link becomes a card', () {
      expect(_cards('- [clip](spacenotes://file/abc)'), hasLength(1));
    });

    test('consecutive link lines give one card each', () {
      final cards = _cards(
        '[a](spacenotes://file/1)\n[b](spacenotes://file/2)\n[c](spacenotes://file/3)',
      );
      expect(cards.map((c) => c.attributes['label']), ['a', 'b', 'c']);
    });

    test('a file link inside a sentence stays a text link', () {
      expect(_cards('Have a look at [Jeremy.md](spacenotes://file/8d30bafc) later.'), isEmpty);
    });

    test('folder and web links on their own line stay text links', () {
      expect(_cards('[Masters](spacenotes://folder/Masters)'), isEmpty);
      expect(_cards('[pub](https://pub.dev)'), isEmpty);
    });
  });
}
