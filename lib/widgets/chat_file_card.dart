import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;

import '../actions/vault_link_actions.dart';
import '../file_types/file_type_registry.dart';
import '../providers/notes_providers.dart';
import '../services/vault_link.dart';
import '../theme/spacenotes_theme.dart';

const vaultCardTag = 'vault-card';

class VaultCardSyntax extends md.BlockSyntax {
  const VaultCardSyntax();

  static final _line = RegExp(
    r'^\s*(?:[-*+]\s+)?\[([^\]]*)\]\((spacenotes://file/[^)\s]+)\)\s*$',
  );

  @override
  RegExp get pattern => _line;

  @override
  md.Node parse(md.BlockParser parser) {
    final match = _line.firstMatch(parser.current.content)!;
    parser.advance();
    final card = md.Element.empty(vaultCardTag)
      ..attributes['label'] = match.group(1) ?? ''
      ..attributes['href'] = match.group(2)!;
    return md.Element('p', [card]);
  }
}

class VaultCardBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return ChatFileCard(
      href: element.attributes['href']!,
      label: element.attributes['label'] ?? '',
    );
  }
}

class ChatFileCard extends ConsumerWidget {
  const ChatFileCard({super.key, required this.href, required this.label});

  final String href;
  final String label;

  static const width = 168.0;

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: width,
          child: FileTypeRegistry.forFile(file).buildLinkPreview(file, open),
        ),
      ),
    );
  }
}
