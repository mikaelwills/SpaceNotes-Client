// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/codegen.dart';

class Note {
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

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? '',
      path: json['path'] ?? '',
      name: json['name'] ?? '',
      content: json['content'] ?? '',
      folderPath: json['folderPath'] ?? '',
      depth: json['depth'] ?? 0,
      frontmatter: json['frontmatter'] ?? '',
      size: Int64(json['size'] ?? 0),
      createdTime: Int64(json['createdTime'] ?? 0),
      modifiedTime: Int64(json['modifiedTime'] ?? 0),
      dbUpdatedAt: Int64(json['dbUpdatedAt'] ?? 0),
    );
  }

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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Note &&
            id == other.id &&
            path == other.path &&
            name == other.name &&
            content == other.content &&
            folderPath == other.folderPath &&
            depth == other.depth &&
            frontmatter == other.frontmatter &&
            size == other.size &&
            createdTime == other.createdTime &&
            modifiedTime == other.modifiedTime &&
            dbUpdatedAt == other.dbUpdatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, path, name, content, folderPath, depth, frontmatter,
        size, createdTime, modifiedTime, dbUpdatedAt);
  }

  @override
  String toString() {
    return 'Note(id: $id, path: $path, name: $name, content: $content, folderPath: $folderPath, depth: $depth, frontmatter: $frontmatter, size: $size, createdTime: $createdTime, modifiedTime: $modifiedTime, dbUpdatedAt: $dbUpdatedAt)';
  }

  Note copyWith({
    String? id,
    String? path,
    String? name,
    String? content,
    String? folderPath,
    int? depth,
    String? frontmatter,
    Int64? size,
    Int64? createdTime,
    Int64? modifiedTime,
    Int64? dbUpdatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      content: content ?? this.content,
      folderPath: folderPath ?? this.folderPath,
      depth: depth ?? this.depth,
      frontmatter: frontmatter ?? this.frontmatter,
      size: size ?? this.size,
      createdTime: createdTime ?? this.createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      dbUpdatedAt: dbUpdatedAt ?? this.dbUpdatedAt,
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
  Map<String, dynamic>? toJson(Note row) {
    return row.toJson();
  }

  @override
  Note? fromJson(Map<String, dynamic> json) {
    return Note.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
