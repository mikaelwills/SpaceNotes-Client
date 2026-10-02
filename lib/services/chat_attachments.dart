import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../generated/client.dart';
import '../generated/space_file.dart';

const maxPendingChatImages = 10;
const chatAttachmentsRoot = 'Chat Attachments';
const _maxImageEdge = 2048;
const _jpegQuality = 85;
const _passThroughExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};

final vaultFileLinkLine = RegExp(
  r'^\s*(?:[-*+]\s+)?\[([^\]]*)\]\((spacenotes://file/[^)\s]+)\)\s*$',
);

class PendingChatImage {
  const PendingChatImage({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

class ChatAttachmentLink {
  const ChatAttachmentLink({required this.name, required this.fileId});

  final String name;
  final String fileId;
}

class VaultLinkSplit {
  const VaultLinkSplit({required this.text, required this.links});

  final String text;
  final List<({String label, String href})> links;
}

String chatAttachmentFolder(String agentId) {
  final at = agentId.indexOf('@');
  final base = at < 0 ? agentId : agentId.substring(0, at);
  return '$chatAttachmentsRoot/$base';
}

String chatAttachmentName(String messageId, int index, String extension) =>
    '$messageId-${index + 1}.$extension';

String buildChatMessageText(String caption, List<ChatAttachmentLink> links) {
  final lines = [
    for (final link in links) '[${link.name}](spacenotes://file/${link.fileId})',
  ];
  final trimmed = caption.trim();
  if (lines.isEmpty) return trimmed;
  if (trimmed.isEmpty) return lines.join('\n');
  return '$trimmed\n\n${lines.join('\n')}';
}

VaultLinkSplit splitVaultLinkLines(String text) {
  final kept = <String>[];
  final links = <({String label, String href})>[];
  for (final line in text.split('\n')) {
    final match = vaultFileLinkLine.firstMatch(line);
    if (match == null) {
      kept.add(line);
      continue;
    }
    links.add((label: match.group(1) ?? '', href: match.group(2)!));
  }
  return VaultLinkSplit(text: kept.join('\n').trim(), links: links);
}

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

PendingChatImage? normalizeChatImage((Uint8List, String) input) {
  final (bytes, name) = input;
  final extension = _extensionOf(name);
  image_lib.Image? decoded;
  try {
    decoded = image_lib.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    if (_passThroughExtensions.contains(extension)) {
      return PendingChatImage(bytes: bytes, extension: extension);
    }
    return null;
  }
  final oversized =
      decoded.width > _maxImageEdge || decoded.height > _maxImageEdge;
  if (_passThroughExtensions.contains(extension) && !oversized) {
    return PendingChatImage(
      bytes: bytes,
      extension: extension == 'jpeg' ? 'jpg' : extension,
    );
  }
  var image = decoded;
  if (oversized) {
    final landscape = decoded.width >= decoded.height;
    image = image_lib.copyResize(
      decoded,
      width: landscape ? _maxImageEdge : null,
      height: landscape ? null : _maxImageEdge,
    );
  }
  return PendingChatImage(
    bytes: Uint8List.fromList(image_lib.encodeJpg(image, quality: _jpegQuality)),
    extension: 'jpg',
  );
}

Future<List<PendingChatImage>> normalizeChatImages(
  List<(Uint8List, String)> inputs,
) async {
  final out = <PendingChatImage>[];
  for (final input in inputs) {
    final image = await compute(normalizeChatImage, input);
    if (image != null) out.add(image);
  }
  return out;
}

Future<List<PendingChatImage>> pickChatImages(
  ImagePicker picker, {
  required int limit,
}) async {
  if (limit <= 0) return const [];
  final picked = await picker.pickMultiImage(
    maxWidth: _maxImageEdge.toDouble(),
    maxHeight: _maxImageEdge.toDouble(),
    imageQuality: _jpegQuality,
  );
  final inputs = <(Uint8List, String)>[
    for (final file in picked.take(limit)) (await file.readAsBytes(), file.name),
  ];
  return normalizeChatImages(inputs);
}

Future<File> writeChatAttachmentTemp(String name, Uint8List bytes) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/chat-attachments');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

Future<String> waitForFileId(
  SpacetimeDbClient client,
  String path, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  SpaceFile? find() {
    for (final f in client.spaceFile.rows.value) {
      if (f.path == path) return f;
    }
    return null;
  }

  final existing = find();
  if (existing != null) return existing.id;

  final completer = Completer<String>();
  void listener() {
    final found = find();
    if (found != null && !completer.isCompleted) completer.complete(found.id);
  }

  client.spaceFile.rows.addListener(listener);
  try {
    return await completer.future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Uploaded $path but it did not appear in the vault',
        timeout,
      ),
    );
  } finally {
    client.spaceFile.rows.removeListener(listener);
  }
}
