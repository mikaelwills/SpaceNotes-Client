import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:spacenotes_client/widgets/quill_note_editor.dart';

class _KeepEmptyLineBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^(?:[ \t]*)$');
  const _KeepEmptyLineBlockSyntax();
  @override
  md.Node? parse(md.BlockParser parser) {
    parser.advance();
    return md.Element.text('p', '');
  }
}

const pillars = '''## The pillars

1. **[[Morality of God]]** — the Euthyphro dilemma, and the classical-vs-evolving-God trap. If God is
   immutable you own the Old Testament; if God evolves, "God said so" stops meaning "it is right".
   **The strongest philosophical attack — it needs no textual criticism at all.**
2. **[[The Bible as a Human Document]]** — two creation accounts, NT authors quoting selectively,
   anonymous redactors, forged epistles, a canon voted on by regional synods. **The strongest historical
   attack.**
3. **[[Motivated Literalism]]** — the selective reading that holds the whole thing together, and the
   discovery that **it is happening inside the Bible itself**, not just in modern believers.
4. **[[Divine Violence]]** — 1 Samuel 15:3 and the ḥerem problem. Either God commanded child-killing or
   the text misreports God. Both are fatal to inerrancy.
''';

int countListLines(Delta delta, String kind) {
  var n = 0;
  for (final op in delta.toList()) {
    if (op.attributes?['list'] == kind) n++;
  }
  return n;
}

void main() {
  final mdToDelta = MarkdownToDelta(
    markdownDocument: md.Document(
      encodeHtml: false,
      blockSyntaxes: [const _KeepEmptyLineBlockSyntax()],
    ),
    softLineBreak: true,
  );

  Delta convert(String src) => mdToDelta.convert(joinWrappedListItems(src));

  group('joinWrappedListItems', () {
    test('4 wrapped ordered items stay 4 items', () {
      expect(countListLines(convert(pillars), 'ordered'), 4);
    });

    test('continuation text is joined into its item, not split', () {
      final delta = convert(pillars);
      final text = delta.toList().map((op) => op.data).whereType<String>().join();
      expect(text, contains('The strongest historical attack.'));
      expect(text, contains('needs no textual criticism at all.'));
    });

    test('tight lists are untouched', () {
      expect(countListLines(convert('1. one\n2. two\n3. three\n'), 'ordered'), 3);
    });

    test('bullet lists wrap-join too', () {
      const src = '- first item that is\n  wrapped over lines\n- second item\n';
      expect(countListLines(convert(src), 'bullet'), 2);
    });

    test('paragraph soft line breaks are preserved', () {
      const src = 'Line one of an address\nLine two of an address\nLine three\n';
      expect(joinWrappedListItems(src), src);
      final delta = convert(src);
      final newlines = delta
          .toList()
          .map((op) => op.data)
          .whereType<String>()
          .join()
          .split('\n')
          .length;
      expect(newlines, greaterThan(2));
    });

    test('nested list items keep their nesting', () {
      const src = '1. one\n   1. nested a\n   2. nested b\n2. two\n';
      expect(joinWrappedListItems(src), src);
    });

    test('indented code blocks are not joined', () {
      const src = '1. item\n\n       code line one\n       code line two\n';
      expect(joinWrappedListItems(src), src);
    });

    test('fenced code inside a list item is preserved verbatim', () {
      const src = '1. item\n   ```\n   a = 1\n\n   b = 2\n   ```\n';
      expect(joinWrappedListItems(src), src);
    });

    test('blank line ends the item, following text is not absorbed', () {
      const src = '1. one\n\nA new paragraph that follows\n';
      expect(joinWrappedListItems(src), src);
    });

    test('a continuation line that starts a new list is not joined', () {
      const src = '- alpha\n- beta\n';
      expect(joinWrappedListItems(src), src);
    });

    test('empty input is safe', () {
      expect(joinWrappedListItems(''), '');
    });

    test('CRLF line endings are handled', () {
      const src = '1. one that is\r\n   wrapped\r\n2. two\r\n';
      expect(countListLines(convert(src), 'ordered'), 2);
    });
  });

}
