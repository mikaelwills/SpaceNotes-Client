// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class SpaceFile {
  SpaceFile({
    required this.id,
    required this.path,
    required this.name,
    required this.content,
    required this.folderPath,
    required this.depth,
    required this.extension,
    required this.size,
    required this.createdTime,
    required this.modifiedTime,
    required this.dbUpdatedAt,
  });

  factory SpaceFile.fromJson(Map<String, dynamic> json) {
    return SpaceFile(
      id: json['id'] ?? '',
      path: json['path'] ?? '',
      name: json['name'] ?? '',
      content: json['content'] ?? '',
      folderPath: json['folderPath'] ?? '',
      depth: json['depth'] ?? 0,
      extension: json['extension'] ?? '',
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

  final String extension;

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
    encoder.writeString(extension);
    encoder.writeU64(size);
    encoder.writeU64(createdTime);
    encoder.writeU64(modifiedTime);
    encoder.writeI64(dbUpdatedAt);
  }

  static SpaceFile decodeBsatn(BsatnDecoder decoder) {
    return SpaceFile(
      id: decoder.readString(),
      path: decoder.readString(),
      name: decoder.readString(),
      content: decoder.readString(),
      folderPath: decoder.readString(),
      depth: decoder.readU32(),
      extension: decoder.readString(),
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
      'extension': extension,
      'size': size.toInt(),
      'createdTime': createdTime.toInt(),
      'modifiedTime': modifiedTime.toInt(),
      'dbUpdatedAt': dbUpdatedAt.toInt(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SpaceFile &&
            id == other.id &&
            path == other.path &&
            name == other.name &&
            content == other.content &&
            folderPath == other.folderPath &&
            depth == other.depth &&
            extension == other.extension &&
            size == other.size &&
            createdTime == other.createdTime &&
            modifiedTime == other.modifiedTime &&
            dbUpdatedAt == other.dbUpdatedAt;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      path,
      name,
      content,
      folderPath,
      depth,
      extension,
      size,
      createdTime,
      modifiedTime,
      dbUpdatedAt
    ]);
  }

  @override
  String toString() {
    return 'SpaceFile(id: $id, path: $path, name: $name, content: $content, folderPath: $folderPath, depth: $depth, extension: $extension, size: $size, createdTime: $createdTime, modifiedTime: $modifiedTime, dbUpdatedAt: $dbUpdatedAt)';
  }

  SpaceFile copyWith({
    String? id,
    String? path,
    String? name,
    String? content,
    String? folderPath,
    int? depth,
    String? extension,
    Int64? size,
    Int64? createdTime,
    Int64? modifiedTime,
    Int64? dbUpdatedAt,
  }) {
    return SpaceFile(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      content: content ?? this.content,
      folderPath: folderPath ?? this.folderPath,
      depth: depth ?? this.depth,
      extension: extension ?? this.extension,
      size: size ?? this.size,
      createdTime: createdTime ?? this.createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      dbUpdatedAt: dbUpdatedAt ?? this.dbUpdatedAt,
    );
  }
}

class SpaceFileDecoder extends RowDecoder<SpaceFile> {
  @override
  SpaceFile decode(BsatnDecoder decoder) {
    return SpaceFile.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(SpaceFile row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(SpaceFile row) {
    return row.toJson();
  }

  @override
  SpaceFile? fromJson(Map<String, dynamic> json) {
    return SpaceFile.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
