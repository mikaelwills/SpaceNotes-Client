// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';

class Folder {
  final String path;
  final String name;
  final int depth;

  Folder({
    required this.path,
    required this.name,
    required this.depth,
  });

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

}

class FolderDecoder implements RowDecoder<Folder> {
  @override
  Folder decode(BsatnDecoder decoder) {
    return Folder.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(Folder row) {
    return row.path;
  }
}
