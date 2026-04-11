// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/codegen.dart';

class Folder {
  Folder({
    required this.path,
    required this.name,
    required this.depth,
  });

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      path: json['path'] ?? '',
      name: json['name'] ?? '',
      depth: json['depth'] ?? 0,
    );
  }

  final String path;

  final String name;

  final int depth;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(path);
    encoder.writeString(name);
    encoder.writeU32(depth);
  }

  static Folder decodeBsatn(BsatnDecoder decoder) {
    return Folder(
      path: decoder.readString(),
      name: decoder.readString(),
      depth: decoder.readU32(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'depth': depth,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Folder &&
            path == other.path &&
            name == other.name &&
            depth == other.depth;
  }

  @override
  int get hashCode {
    return Object.hash(path, name, depth);
  }

  @override
  String toString() {
    return 'Folder(path: $path, name: $name, depth: $depth)';
  }

  Folder copyWith({
    String? path,
    String? name,
    int? depth,
  }) {
    return Folder(
      path: path ?? this.path,
      name: name ?? this.name,
      depth: depth ?? this.depth,
    );
  }
}

class FolderDecoder extends RowDecoder<Folder> {
  @override
  Folder decode(BsatnDecoder decoder) {
    return Folder.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(Folder row) {
    return row.path;
  }

  @override
  Map<String, dynamic>? toJson(Folder row) {
    return row.toJson();
  }

  @override
  Folder? fromJson(Map<String, dynamic> json) {
    return Folder.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
