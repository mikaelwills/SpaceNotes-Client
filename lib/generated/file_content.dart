// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class FileContent {
  FileContent({
    required this.fileId,
    required this.content,
  });

  factory FileContent.fromJson(Map<String, dynamic> json) {
    return FileContent(
      fileId: json['fileId'] ?? '',
      content: json['content'] ?? '',
    );
  }

  final String fileId;

  final String content;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(fileId);
    encoder.writeString(content);
  }

  static FileContent decodeBsatn(BsatnDecoder decoder) {
    return FileContent(
      fileId: decoder.readString(),
      content: decoder.readString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileId': fileId,
      'content': content,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FileContent &&
            fileId == other.fileId &&
            content == other.content;
  }

  @override
  int get hashCode {
    return Object.hashAll([fileId, content]);
  }

  @override
  String toString() {
    return 'FileContent(fileId: $fileId, content: $content)';
  }

  FileContent copyWith({
    String? fileId,
    String? content,
  }) {
    return FileContent(
      fileId: fileId ?? this.fileId,
      content: content ?? this.content,
    );
  }
}

class FileContentDecoder extends RowDecoder<FileContent> {
  @override
  FileContent decode(BsatnDecoder decoder) {
    return FileContent.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(FileContent row) {
    return row.fileId;
  }

  @override
  Map<String, dynamic>? toJson(FileContent row) {
    return row.toJson();
  }

  @override
  FileContent? fromJson(Map<String, dynamic> json) {
    return FileContent.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
