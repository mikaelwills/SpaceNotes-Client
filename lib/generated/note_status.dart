// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';

sealed class NoteStatus {
  const NoteStatus();

  factory NoteStatus.decode(BsatnDecoder decoder) {
    final tag = decoder.readU8();
    switch (tag) {
      case 0: return NoteStatusDraft.decode(decoder);
      case 1: return NoteStatusPublished.decode(decoder);
      case 2: return NoteStatusArchived.decode(decoder);
      default: throw Exception('Unknown NoteStatus variant: $tag');
    }
  }

  void encode(BsatnEncoder encoder);
}

class NoteStatusDraft extends NoteStatus {
  const NoteStatusDraft();

  factory NoteStatusDraft.decode(BsatnDecoder decoder) {
    return const NoteStatusDraft();
  }

  @override
  void encode(BsatnEncoder encoder) {
    encoder.writeU8(0);
  }
}

class NoteStatusPublished extends NoteStatus {
  final Int64 value;

  const NoteStatusPublished(this.value);

  factory NoteStatusPublished.decode(BsatnDecoder decoder) {
    return NoteStatusPublished(decoder.readU64());
  }

  @override
  void encode(BsatnEncoder encoder) {
    encoder.writeU8(1);
    encoder.writeU64(value);
  }
}

class NoteStatusArchived extends NoteStatus {
  const NoteStatusArchived();

  factory NoteStatusArchived.decode(BsatnDecoder decoder) {
    return const NoteStatusArchived();
  }

  @override
  void encode(BsatnEncoder encoder) {
    encoder.writeU8(2);
  }
}

