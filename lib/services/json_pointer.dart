/// Minimal RFC 6901 JSON Pointer reader/writer.
///
/// Supports the subset we need for A2UI-style value bindings:
/// "/foo", "/items/0/price", "/" (whole doc), "" (whole doc).
/// Escape sequences: ~0 → ~, ~1 → /.
class JsonPointer {
  static List<String> parse(String pointer) {
    if (pointer.isEmpty) return const [];
    if (!pointer.startsWith('/')) {
      throw FormatException('JSON Pointer must start with /: $pointer');
    }
    return pointer
        .substring(1)
        .split('/')
        .map((s) => s.replaceAll('~1', '/').replaceAll('~0', '~'))
        .toList();
  }

  static dynamic read(dynamic root, String pointer) {
    final tokens = parse(pointer);
    dynamic current = root;
    for (final token in tokens) {
      if (current is Map) {
        current = current[token];
      } else if (current is List) {
        final idx = int.tryParse(token);
        if (idx == null || idx < 0 || idx >= current.length) return null;
        current = current[idx];
      } else {
        return null;
      }
      if (current == null) return null;
    }
    return current;
  }

  /// Returns a new root with `value` written at `pointer`. Creates
  /// intermediate maps as needed; list indices must already exist.
  static dynamic write(dynamic root, String pointer, dynamic value) {
    final tokens = parse(pointer);
    if (tokens.isEmpty) return value;
    return _writeInner(root, tokens, 0, value);
  }

  static dynamic _writeInner(
      dynamic current, List<String> tokens, int i, dynamic value) {
    final token = tokens[i];
    final last = i == tokens.length - 1;

    if (current is List) {
      final idx = int.tryParse(token);
      if (idx == null || idx < 0 || idx >= current.length) return current;
      final newList = List<dynamic>.from(current);
      newList[idx] =
          last ? value : _writeInner(newList[idx], tokens, i + 1, value);
      return newList;
    }

    final asMap = current is Map<String, dynamic>
        ? Map<String, dynamic>.from(current)
        : <String, dynamic>{};
    asMap[token] =
        last ? value : _writeInner(asMap[token], tokens, i + 1, value);
    return asMap;
  }
}
