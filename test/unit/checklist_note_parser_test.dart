import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/checklist_note_parser.dart';

void main() {
  group('ChecklistNoteParser.findBlock', () {
    test('returns null when no checklist lines present', () {
      expect(ChecklistNoteParser.findBlock(''), isNull);
      expect(ChecklistNoteParser.findBlock('just prose\nmore prose'), isNull);
      expect(ChecklistNoteParser.findBlock('- plain bullet\n- another'), isNull);
    });

    test('parses a whole-note checklist', () {
      const body = '- [ ] one\n- [x] two\n- [ ] three\n';
      final block = ChecklistNoteParser.findBlock(body)!;
      expect(block.items.length, 3);
      expect(block.items[0].text, 'one');
      expect(block.items[0].checked, isFalse);
      expect(block.items[1].text, 'two');
      expect(block.items[1].checked, isTrue);
      expect(block.start, 0);
      expect(block.end, body.length);
    });

    test('is case-insensitive on the x marker', () {
      const body = '- [X] done\n';
      final block = ChecklistNoteParser.findBlock(body)!;
      expect(block.items.single.checked, isTrue);
    });

    test('parses one level of nesting via 4-space indent', () {
      const body = '- [ ] parent\n    - [ ] child\n';
      final block = ChecklistNoteParser.findBlock(body)!;
      expect(block.items[0].depth, 0);
      expect(block.items[1].depth, 1);
    });

    test('finds only the first contiguous run, ignoring prose before/after', () {
      const body = 'Some notes\n\n- [ ] a\n- [x] b\n\nMore prose after\n';
      final block = ChecklistNoteParser.findBlock(body)!;
      expect(block.items.length, 2);
      expect(body.substring(block.start, block.end), '- [ ] a\n- [x] b\n');
    });

    test('a second checklist run further down is not included', () {
      const body = '- [ ] a\n\ntext\n\n- [ ] b\n';
      final block = ChecklistNoteParser.findBlock(body)!;
      expect(block.items.length, 1);
      expect(block.items.single.text, 'a');
    });
  });

  group('ChecklistNoteParser.serialize', () {
    test('round-trips checked state and nesting', () {
      const items = [
        ChecklistItem(text: 'a', checked: false),
        ChecklistItem(text: 'b', checked: true),
        ChecklistItem(text: 'c', checked: false, depth: 1),
      ];
      final markdown = ChecklistNoteParser.serialize(items);
      expect(markdown, '- [ ] a\n- [x] b\n    - [ ] c\n');

      final reparsed = ChecklistNoteParser.findBlock(markdown)!;
      expect(reparsed.items.map((i) => i.text), ['a', 'b', 'c']);
      expect(reparsed.items.map((i) => i.checked), [false, true, false]);
      expect(reparsed.items.map((i) => i.depth), [0, 0, 1]);
    });
  });

  group('ChecklistNoteParser.replaceBlock', () {
    test('preserves prose before and after the block', () {
      const body = 'Title\n\n- [ ] a\n- [x] b\n\nFooter\n';
      final block = ChecklistNoteParser.findBlock(body)!;
      final updated = ChecklistNoteParser.replaceBlock(
        body,
        block,
        [
          block.items[0].copyWith(checked: true),
          block.items[1],
        ],
      );
      expect(updated, 'Title\n\n- [x] a\n- [x] b\n\nFooter\n');
    });
  });

  group('ChecklistNoteParser.toPlainText', () {
    test('drops checkbox markers and checked state', () {
      const items = [
        ChecklistItem(text: 'a', checked: false),
        ChecklistItem(text: 'b', checked: true),
      ];
      expect(ChecklistNoteParser.toPlainText(items), 'a\nb');
    });
  });
}
