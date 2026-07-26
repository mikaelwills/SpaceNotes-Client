// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class QuestionRequest {
  QuestionRequest({
    required this.id,
    required this.agentId,
    required this.question,
    required this.header,
    required this.options,
    required this.multiSelect,
    required this.status,
    required this.response,
    required this.createdAt,
    required this.resolvedAt,
  });

  factory QuestionRequest.fromJson(Map<String, dynamic> json) {
    return QuestionRequest(
      id: json['id'] ?? '',
      agentId: json['agentId'] ?? '',
      question: json['question'] ?? '',
      header: json['header'] ?? '',
      options: json['options'] ?? '',
      multiSelect: json['multiSelect'] ?? false,
      status: json['status'] ?? '',
      response: json['response'],
      createdAt: Int64(json['createdAt'] ?? 0),
      resolvedAt: json['resolvedAt'] == null ? null : Int64(json['resolvedAt']),
    );
  }

  final String id;

  final String agentId;

  final String question;

  final String header;

  final String options;

  final bool multiSelect;

  final String status;

  final String? response;

  final Int64 createdAt;

  final Int64? resolvedAt;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(id);
    encoder.writeString(agentId);
    encoder.writeString(question);
    encoder.writeString(header);
    encoder.writeString(options);
    encoder.writeBool(multiSelect);
    encoder.writeString(status);
    encoder.writeOption<String>(
        response, (value) => encoder.writeString(value));
    encoder.writeI64(createdAt);
    encoder.writeOption<Int64>(resolvedAt, (value) => encoder.writeI64(value));
  }

  static QuestionRequest decodeBsatn(BsatnDecoder decoder) {
    return QuestionRequest(
      id: decoder.readString(),
      agentId: decoder.readString(),
      question: decoder.readString(),
      header: decoder.readString(),
      options: decoder.readString(),
      multiSelect: decoder.readBool(),
      status: decoder.readString(),
      response: decoder.readOption<String>(() => decoder.readString()),
      createdAt: decoder.readI64(),
      resolvedAt: decoder.readOption<Int64>(() => decoder.readI64()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agentId': agentId,
      'question': question,
      'header': header,
      'options': options,
      'multiSelect': multiSelect,
      'status': status,
      'response': response,
      'createdAt': createdAt.toInt(),
      'resolvedAt': resolvedAt?.toInt(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is QuestionRequest &&
            id == other.id &&
            agentId == other.agentId &&
            question == other.question &&
            header == other.header &&
            options == other.options &&
            multiSelect == other.multiSelect &&
            status == other.status &&
            response == other.response &&
            createdAt == other.createdAt &&
            resolvedAt == other.resolvedAt;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      agentId,
      question,
      header,
      options,
      multiSelect,
      status,
      response,
      createdAt,
      resolvedAt
    ]);
  }

  @override
  String toString() {
    return 'QuestionRequest(id: $id, agentId: $agentId, question: $question, header: $header, options: $options, multiSelect: $multiSelect, status: $status, response: $response, createdAt: $createdAt, resolvedAt: $resolvedAt)';
  }

  QuestionRequest copyWith({
    String? id,
    String? agentId,
    String? question,
    String? header,
    String? options,
    bool? multiSelect,
    String? status,
    String? response,
    Int64? createdAt,
    Int64? resolvedAt,
  }) {
    return QuestionRequest(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      question: question ?? this.question,
      header: header ?? this.header,
      options: options ?? this.options,
      multiSelect: multiSelect ?? this.multiSelect,
      status: status ?? this.status,
      response: response ?? this.response,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

class QuestionRequestDecoder extends RowDecoder<QuestionRequest> {
  @override
  QuestionRequest decode(BsatnDecoder decoder) {
    return QuestionRequest.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(QuestionRequest row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(QuestionRequest row) {
    return row.toJson();
  }

  @override
  QuestionRequest? fromJson(Map<String, dynamic> json) {
    return QuestionRequest.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
