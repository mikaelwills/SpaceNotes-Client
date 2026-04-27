import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../theme/spacenotes_theme.dart';

class SpaceMarkdownStyles {
  static MarkdownStyleSheet chatAssistant(BuildContext context) {
    const bodyStyle = TextStyle(
      fontFamily: SpaceNotesTheme.fontSans,
      fontSize: 15,
      color: SpaceNotesTheme.fg,
      height: 1.55,
    );
    const mutedStyle = TextStyle(
      fontFamily: SpaceNotesTheme.fontSans,
      fontSize: 15,
      color: SpaceNotesTheme.muted,
      height: 1.55,
      fontStyle: FontStyle.italic,
    );
    const codeInline = TextStyle(
      fontFamily: SpaceNotesTheme.fontMono,
      fontSize: 13.5,
      color: SpaceNotesTheme.fg,
      backgroundColor: SpaceNotesTheme.bgAlt,
    );

    return MarkdownStyleSheet(
      p: bodyStyle,
      h1: bodyStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      h2: bodyStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      h3: bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      h4: bodyStyle.copyWith(fontWeight: FontWeight.w600),
      h5: bodyStyle.copyWith(fontWeight: FontWeight.w600),
      h6: bodyStyle.copyWith(fontWeight: FontWeight.w600),
      em: bodyStyle.copyWith(fontStyle: FontStyle.italic),
      strong: bodyStyle.copyWith(fontWeight: FontWeight.w700),
      del: bodyStyle.copyWith(decoration: TextDecoration.lineThrough),
      a: bodyStyle.copyWith(
        color: SpaceNotesTheme.accent,
        decoration: TextDecoration.underline,
      ),
      code: codeInline,
      codeblockDecoration: BoxDecoration(
        color: SpaceNotesTheme.card,
        border: Border.all(color: SpaceNotesTheme.hairline),
      ),
      codeblockPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      blockquote: mutedStyle,
      blockquoteDecoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: SpaceNotesTheme.accent2, width: 2),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      listBullet: bodyStyle.copyWith(color: SpaceNotesTheme.accent),
      listBulletPadding: const EdgeInsets.only(right: 8),
      listIndent: 20,
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      tableBody: bodyStyle,
      tableHead: bodyStyle.copyWith(fontWeight: FontWeight.w600),
      h1Padding: const EdgeInsets.only(top: 16, bottom: 6),
      h2Padding: const EdgeInsets.only(top: 14, bottom: 6),
      h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
      pPadding: const EdgeInsets.only(bottom: 2),
      codeblockAlign: WrapAlignment.start,
      textScaler: MediaQuery.maybeTextScalerOf(context),
    );
  }
}

class TableAsBulletsBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final headers = <String>[];
    final rows = <List<String>>[];

    for (final child in element.children ?? const <md.Node>[]) {
      if (child is! md.Element) continue;
      if (child.tag == 'thead') {
        for (final tr in child.children ?? const <md.Node>[]) {
          if (tr is! md.Element || tr.tag != 'tr') continue;
          for (final cell in tr.children ?? const <md.Node>[]) {
            if (cell is md.Element) {
              headers.add(cell.textContent.trim());
            }
          }
        }
      } else if (child.tag == 'tbody') {
        for (final tr in child.children ?? const <md.Node>[]) {
          if (tr is! md.Element || tr.tag != 'tr') continue;
          final row = <String>[];
          for (final cell in tr.children ?? const <md.Node>[]) {
            if (cell is md.Element) {
              row.add(cell.textContent.trim());
            }
          }
          if (row.isNotEmpty) rows.add(row);
        }
      }
    }

    if (rows.isEmpty) return null;

    const labelStyle = TextStyle(
      fontFamily: SpaceNotesTheme.fontMono,
      fontSize: 11,
      color: SpaceNotesTheme.dim,
      letterSpacing: 1.2,
    );
    const keyStyle = TextStyle(
      fontFamily: SpaceNotesTheme.fontSans,
      fontSize: 14,
      color: SpaceNotesTheme.muted,
    );
    const valueStyle = TextStyle(
      fontFamily: SpaceNotesTheme.fontSans,
      fontSize: 15,
      color: SpaceNotesTheme.fg,
      height: 1.45,
    );

    final rowWidgets = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowLabel = row.isNotEmpty ? row.first : '';
      final pairs = <Widget>[];
      for (var c = 1; c < row.length; c++) {
        final key = c < headers.length ? headers[c] : '';
        pairs.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 12),
            child: RichText(
              text: TextSpan(
                style: valueStyle,
                children: [
                  if (key.isNotEmpty) TextSpan(text: '$key: ', style: keyStyle),
                  TextSpan(text: row[c]),
                ],
              ),
            ),
          ),
        );
      }

      rowWidgets.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rowLabel.isEmpty ? '—' : rowLabel,
                style: labelStyle,
              ),
              ...pairs,
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowWidgets,
      ),
    );
  }
}
