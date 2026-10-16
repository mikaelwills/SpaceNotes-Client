import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;

import '../actions/vault_link_actions.dart';
import '../file_types/file_type_registry.dart';
import '../providers/notes_providers.dart';
import '../services/chat_attachments.dart';
import '../services/vault_link.dart';
import '../theme/spacenotes_theme.dart';

const vaultCardTag = 'vault-card';

typedef VaultCardLink = ({String label, String href});

List<VaultCardLink> vaultCardLinks(md.Element element) {
  final decoded = jsonDecode(element.attributes['links'] ?? '[]') as List;
  return [
    for (final entry in decoded.cast<Map<String, dynamic>>())
      (label: entry['label'] as String, href: entry['href'] as String),
  ];
}

class VaultCardSyntax extends md.BlockSyntax {
  const VaultCardSyntax();

  static final _line = vaultFileLinkLine;

  @override
  RegExp get pattern => _line;

  @override
  md.Node parse(md.BlockParser parser) {
    final links = <Map<String, String>>[];
    while (!parser.isDone) {
      final match = _line.firstMatch(parser.current.content);
      if (match != null) {
        links.add({'label': match.group(1) ?? '', 'href': match.group(2)!});
        parser.advance();
        continue;
      }
      if (parser.current.content.trim().isNotEmpty) break;
      final next = parser.peek(1);
      if (next == null || !_line.hasMatch(next.content)) break;
      parser.advance();
    }
    final card = md.Element.empty(vaultCardTag)..attributes['links'] = jsonEncode(links);
    return md.Element('p', [card]);
  }
}

class VaultCardBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return ChatFileCardGroup(links: vaultCardLinks(element));
  }
}

class ChatFileCardGroup extends StatelessWidget {
  const ChatFileCardGroup({
    super.key,
    required this.links,
    this.alignment = WrapAlignment.start,
  });

  final List<VaultCardLink> links;
  final WrapAlignment alignment;

  static const thumbSize = 80.0;
  static const gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final width = links.length == 1 ? ChatFileCard.defaultWidth : thumbSize;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        alignment: alignment,
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final link in links) ChatFileCard(href: link.href, label: link.label, width: width),
        ],
      ),
    );
  }
}

class ChatFileCard extends ConsumerWidget {
  const ChatFileCard({
    super.key,
    required this.href,
    required this.label,
    this.width = defaultWidth,
  });

  final String href;
  final String label;
  final double width;

  static const defaultWidth = 168.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = parseVaultLink(href);
    final file = link is FileLink ? ref.watch(fileByIdProvider(link.id)) : null;
    void open() => openVaultLink(context, ref, href);

    if (file == null) {
      return GestureDetector(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label.isEmpty ? href : label,
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontSans,
              fontSize: 15,
              color: SpaceNotesTheme.accent,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: FileTypeRegistry.forFile(file).buildLinkPreview(file, open),
    );
  }
}
