// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class MessageImage {
  MessageImage({
    required this.messageId,
    required this.bytes,
  });

  factory MessageImage.fromJson(Map<String, dynamic> json) {
    return MessageImage(
      messageId: json['messageId'] ?? '',
      bytes: json['bytes'],
    );
  }

  final String messageId;

  final List<int> bytes;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(messageId);
    encoder.writeByteArray(bytes);
  }

  static MessageImage decodeBsatn(BsatnDecoder decoder) {
    return MessageImage(
      messageId: decoder.readString(),
      bytes: decoder.readByteArray(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'bytes': bytes,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MessageImage &&
            messageId == other.messageId &&
            bytes == other.bytes;
  }

  @override
  int get hashCode {
    return Object.hashAll([messageId, bytes]);
  }

  @override
  String toString() {
    return 'MessageImage(messageId: $messageId, bytes: $bytes)';
  }

  MessageImage copyWith({
    String? messageId,
    List<int>? bytes,
  }) {
    return MessageImage(
      messageId: messageId ?? this.messageId,
      bytes: bytes ?? this.bytes,
    );
  }
}

class MessageImageDecoder extends RowDecoder<MessageImage> {
  @override
  MessageImage decode(BsatnDecoder decoder) {
    return MessageImage.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(MessageImage row) {
    return row.messageId;
  }

  @override
  Map<String, dynamic>? toJson(MessageImage row) {
    return row.toJson();
  }

  @override
  MessageImage? fromJson(Map<String, dynamic> json) {
    return MessageImage.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
