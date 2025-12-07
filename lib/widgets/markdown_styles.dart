import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/spacenotes_theme.dart';

class OpenCodeMarkdownStyles {
  static MarkdownStyleSheet get standard => MarkdownStyleSheet(
        p: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 14,
          color: SpaceNotesTheme.text,
          height: 1.6,
        ),
        h1: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 24,
          color: SpaceNotesTheme.primary,
          fontWeight: FontWeight.bold,
        ),
        h2: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 20,
          color: SpaceNotesTheme.primary,
          fontWeight: FontWeight.bold,
        ),
        h3: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 16,
          color: SpaceNotesTheme.primary,
          fontWeight: FontWeight.bold,
        ),
        code: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 13,
          color: SpaceNotesTheme.success,
          backgroundColor: SpaceNotesTheme.background,
        ),
        codeblockDecoration: const BoxDecoration(
          color: SpaceNotesTheme.background,
          border: Border(
            left: BorderSide(
              color: SpaceNotesTheme.primary,
              width: 4,
            ),
          ),
        ),
        blockquote: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 14,
          color: SpaceNotesTheme.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        listBullet: const TextStyle(
          color: SpaceNotesTheme.primary,
        ),
      );
}