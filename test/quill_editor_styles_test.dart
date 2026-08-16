import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/theme/spacenotes_theme.dart';
import 'package:spacenotes_client/widgets/quill_note_editor.dart';

void main() {
  testWidgets('style parity with original customisations', (t) async {
    late DefaultStyles applied;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: QuillNoteEditor(
            initialContent: '1. one\n',
            onContentChanged: (_) {},
            showToolbar: false,
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();
    final markerCtx = t.element(find.text('1.'));
    applied = QuillStyles.getStyles(markerCtx, true)!;

    void check(String name, DefaultTextBlockStyle? s, {
      required double size, double? height, FontWeight? weight,
      Color? color, Color? bg, FontStyle? fontStyle,
      required double vsTop, required double vsBottom,
      bool hasDecoration = false,
    }) {
      expect(s, isNotNull, reason: '$name null');
      expect(s!.style.fontFamily, 'FiraCode', reason: '$name fontFamily');
      expect(s.style.fontSize, size, reason: '$name fontSize');
      expect(s.style.height, height, reason: '$name height');
      if (weight != null) expect(s.style.fontWeight, weight, reason: '$name weight');
      expect(s.style.color, color ?? SpaceNotesTheme.text, reason: '$name color');
      if (bg != null) expect(s.style.backgroundColor, bg, reason: '$name bg');
      if (fontStyle != null) expect(s.style.fontStyle, fontStyle, reason: '$name fontStyle');
      expect(s.verticalSpacing.top, vsTop, reason: '$name vsTop');
      expect(s.verticalSpacing.bottom, vsBottom, reason: '$name vsBottom');
      expect(s.decoration != null, hasDecoration, reason: '$name decoration');
    }

    check('paragraph', applied.paragraph, size: 14, height: 1.6, vsTop: 0, vsBottom: 8);
    check('h1', applied.h1, size: 28, height: 1.4, weight: FontWeight.bold, vsTop: 16, vsBottom: 8);
    check('h2', applied.h2, size: 22, height: 1.4, weight: FontWeight.bold, vsTop: 12, vsBottom: 6);
    check('h3', applied.h3, size: 18, height: 1.4, weight: FontWeight.bold, vsTop: 8, vsBottom: 4);
    check('code', applied.code, size: 13, color: SpaceNotesTheme.primary,
        bg: SpaceNotesTheme.inputSurface, vsTop: 8, vsBottom: 8, hasDecoration: true);
    check('quote', applied.quote, size: 14,
        color: SpaceNotesTheme.text.withValues(alpha: 0.8),
        fontStyle: FontStyle.italic, vsTop: 8, vsBottom: 8, hasDecoration: true);
    check('placeHolder', applied.placeHolder, size: 14,
        color: SpaceNotesTheme.textSecondary, vsTop: 0, vsBottom: 0);

    final lists = applied.lists!;
    expect(lists.style.fontFamily, 'FiraCode', reason: 'lists fontFamily');
    expect(lists.style.fontSize, 14, reason: 'lists fontSize');
    expect(lists.style.height, isNull, reason: 'lists height must stay null (alignment fix)');
    expect(applied.code!.style.height, isNull, reason: 'code height');
    expect(applied.quote!.style.height, isNull, reason: 'quote height');
    expect(lists.style.color, SpaceNotesTheme.text, reason: 'lists color');
    expect(lists.verticalSpacing.top, 0, reason: 'lists vsTop');
    expect(lists.verticalSpacing.bottom, 4, reason: 'lists vsBottom');
    expect(lists.lineSpacing.top, 0, reason: 'lists lsTop');
    expect(lists.lineSpacing.bottom, 0, reason: 'lists lsBottom');

    final inline = applied.inlineCode!.style;
    expect(inline.fontFamily, 'FiraCode', reason: 'inlineCode fontFamily');
    expect(inline.fontSize, 13, reason: 'inlineCode fontSize');
    expect(inline.color, SpaceNotesTheme.primary, reason: 'inlineCode color');
    expect(inline.backgroundColor, SpaceNotesTheme.inputSurface, reason: 'inlineCode bg');

    expect(applied.link!.color, SpaceNotesTheme.primary, reason: 'link color');
    expect(applied.link!.decoration, TextDecoration.underline, reason: 'link decoration');

    final leading = applied.leading!;
    expect(leading.style.fontFamily, 'FiraCode', reason: 'leading fontFamily');
    expect(leading.style.fontSize, 14, reason: 'leading fontSize');
    expect(leading.style.height, isNull, reason: 'leading height');
  });
}
