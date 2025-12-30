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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'name': name,
      'content': content,
      'folderPath': folderPath,
      'depth': depth,
      'frontmatter': frontmatter,
      'size': size.toInt(),
      'createdTime': createdTime.toInt(),
      'modifiedTime': modifiedTime.toInt(),
      'dbUpdatedAt': dbUpdatedAt.toInt(),
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: (json['id'] as String?) ?? '',
      path: (json['path'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      folderPath: (json['folderPath'] as String?) ?? '',
      depth: (json['depth'] as int?) ?? 0,
      frontmatter: (json['frontmatter'] as String?) ?? '',
      size: Int64((json['size'] as int?) ?? 0),
      createdTime: Int64((json['createdTime'] as int?) ?? 0),
      modifiedTime: Int64((json['modifiedTime'] as int?) ?? 0),
      dbUpdatedAt: Int64((json['dbUpdatedAt'] as int?) ?? 0),
    );
  }

}

class NoteDecoder extends RowDecoder<Note> {
  @override
  Note decode(BsatnDecoder decoder) {
    return Note.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(Note row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(Note row) => row.toJson();

  @override
  Note? fromJson(Map<String, dynamic> json) => Note.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
