// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';

class Note {
  final String id;
  final String path;
  final String name;
  final String content;
  final String folderPath;
  final int depth;
  final String frontmatter;
  final Int64 size;
  final Int64 createdTime;
  final Int64 modifiedTime;
  final Int64 dbUpdatedAt;

  Note({
    required this.id,
    required this.path,
    required this.name,
    required this.content,
    required this.folderPath,
    required this.depth,
    required this.frontmatter,
    required this.size,
    required this.createdTime,
    required this.modifiedTime,
    required this.dbUpdatedAt,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(id);
    encoder.writeString(path);
    encoder.writeString(name);
    encoder.writeString(content);
    encoder.writeString(folderPath);
    encoder.writeU32(depth);
    encoder.writeString(frontmatter);
    encoder.writeU64(size);
    encoder.writeU64(createdTime);
    encoder.writeU64(modifiedTime);
    encoder.writeI64(dbUpdatedAt);
  }

  static Note decodeBsatn(BsatnDecoder decoder) {
    return Note(
      id: decoder.readString(),
      path: decoder.readString(),
      name: decoder.readString(),
      content: decoder.readString(),
      folderPath: decoder.readString(),
      depth: decoder.readU32(),
      frontmatter: decoder.readString(),
      size: decoder.readU64(),
      createdTime: decoder.readU64(),
      modifiedTime: decoder.readU64(),
      dbUpdatedAt: decoder.readI64(),
    );
  }

}

class NoteDecoder implements RowDecoder<Note> {
  @override
  Note decode(BsatnDecoder decoder) {
    return Note.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(Note row) {
    return row.id;
  }
}
