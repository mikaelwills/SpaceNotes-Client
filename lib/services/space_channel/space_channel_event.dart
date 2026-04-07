enum SpaceChannelEventType { msg, edit, permissionRequest }

enum SpaceChannelSourceType { session, webhook, unknown }

class SpaceChannelEvent {
  final SpaceChannelEventType type;
  final String id;
  final String? from;
  final String? text;
  final int? ts;
  final String? replyTo;
  final SpaceChannelFile? file;
  final SpaceChannelSourceType? sourceType;
  final String? task;
  final String? session;
  final Map<String, dynamic>? permissionData;

  const SpaceChannelEvent({
    required this.type,
    required this.id,
    this.from,
    this.text,
    this.ts,
    this.replyTo,
    this.file,
    this.sourceType,
    this.task,
    this.session,
    this.permissionData,
  });

  factory SpaceChannelEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] ?? 'msg';

    SpaceChannelSourceType? sourceType;
    if (typeStr == 'webhook') {
      sourceType = SpaceChannelSourceType.webhook;
    } else {
      sourceType = SpaceChannelSourceType.session;
    }

    final eventType = (typeStr == 'edit')
        ? SpaceChannelEventType.edit
        : SpaceChannelEventType.msg;

    return SpaceChannelEvent(
      type: eventType,
      id: json['id'] ?? 'msg-${DateTime.now().millisecondsSinceEpoch}',
      from: json['from'] ?? '',
      text: json['text'] ?? '',
      ts: json['ts'],
      replyTo: json['replyTo'] ?? '',
      file: json['file'] != null
          ? SpaceChannelFile.fromJson(json['file'] ?? {})
          : null,
      sourceType: sourceType,
      task: json['task'] ?? '',
      session: json['session'] ?? '',
    );
  }
}

class SpaceChannelFile {
  final String url;
  final String name;

  const SpaceChannelFile({required this.url, required this.name});

  factory SpaceChannelFile.fromJson(Map<String, dynamic> json) {
    return SpaceChannelFile(
      url: json['url'] ?? '',
      name: json['name'] ?? '',
    );
  }
}
