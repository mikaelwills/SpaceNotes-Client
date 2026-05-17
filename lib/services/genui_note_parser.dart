import 'dart:convert';

class GenuiNote {
  final Map<String, dynamic> schema;
  final String markdown;

  const GenuiNote({required this.schema, required this.markdown});

  GenuiNote copyWith({Map<String, dynamic>? schema, String? markdown}) {
    return GenuiNote(
      schema: schema ?? this.schema,
      markdown: markdown ?? this.markdown,
    );
  }
}

/// Pure parser/serializer for genui-in-markdown notes.
///
/// Note body layout (when `genui: true` in frontmatter):
///
///     ```genui
///     {"components":[...],"data":{...}}
///     ```
///
///     (optional markdown body below)
///
/// The genui fenced block must appear before the markdown body.
/// Canonical serialization is pretty-printed JSON with 2-space indent.
class GenuiNoteParser {
  static final RegExp _genuiBlock =
      RegExp(r'^```genui\r?\n([\s\S]*?)\r?\n```\r?\n?', multiLine: false);

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Parse a note body into its genui schema + markdown body.
  /// Returns null if no genui block is found at the start.
  static GenuiNote? parse(String body) {
    final match = _genuiBlock.firstMatch(body);
    if (match == null) return null;

    final jsonText = match.group(1)!;
    final Map<String, dynamic> schema;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) return null;
      schema = decoded;
    } on FormatException {
      return null;
    }

    var markdown = body.substring(match.end);
    if (markdown.startsWith('\n')) markdown = markdown.substring(1);
    if (markdown.startsWith('\r\n')) markdown = markdown.substring(2);

    return GenuiNote(schema: schema, markdown: markdown);
  }

  /// Serialize a parsed note back to a string.
  /// Always emits canonical form: pretty-printed JSON, one blank line
  /// between the genui block and the markdown body (if any).
  static String serialize(GenuiNote note) {
    final jsonText = _encoder.convert(note.schema);
    final buffer = StringBuffer()
      ..write('```genui\n')
      ..write(jsonText)
      ..write('\n```');

    if (note.markdown.isNotEmpty) {
      buffer.write('\n\n');
      buffer.write(note.markdown);
    }

    return buffer.toString();
  }

  /// Read or initialize a data value at the given binding key.
  static dynamic readData(Map<String, dynamic> schema, String key) {
    final data = schema['data'];
    if (data is Map<String, dynamic>) return data[key];
    return null;
  }

  /// Write a data value at the given binding key, creating the data map
  /// if needed. Returns a NEW schema map (immutable update).
  static Map<String, dynamic> writeData(
      Map<String, dynamic> schema, String key, dynamic value) {
    final newSchema = Map<String, dynamic>.from(schema);
    final existingData = newSchema['data'];
    final newData = existingData is Map<String, dynamic>
        ? Map<String, dynamic>.from(existingData)
        : <String, dynamic>{};
    newData[key] = value;
    newSchema['data'] = newData;
    return newSchema;
  }
}
