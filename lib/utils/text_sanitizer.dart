class TextSanitizer {
  static final RegExp _plainTextControlCharsRegex = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  // Cache for sanitized strings to avoid re-processing
  static final Map<String, String> _cache = {};
  static const int _maxCacheSize = 200;

  static String sanitize(String text, {bool preserveMarkdown = true}) {
    if (text.isEmpty) return text;

    final cacheKey = '${preserveMarkdown ? 'md' : 'txt'}_${text.hashCode}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    String result;
    try {
      result = _sanitizeCodeUnits(text);
      if (!preserveMarkdown) {
        result = result.replaceAll(_plainTextControlCharsRegex, '');
      }
    } catch (e) {
      result = sanitizeToAscii(text);
    }

    _cacheResult(cacheKey, result);
    return result;
  }

  static String _sanitizeCodeUnits(String text) {
    final buffer = StringBuffer();
    final codeUnits = text.codeUnits;
    int i = 0;
    while (i < codeUnits.length) {
      final unit = codeUnits[i];
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (i + 1 < codeUnits.length) {
          final nextUnit = codeUnits[i + 1];
          if (nextUnit >= 0xDC00 && nextUnit <= 0xDFFF) {
            buffer.writeCharCode(unit);
            buffer.writeCharCode(nextUnit);
            i += 2;
            continue;
          }
        }
        i++;
        continue;
      }
      if (unit >= 0xDC00 && unit <= 0xDFFF) {
        i++;
        continue;
      }
      if (unit < 0x20 && unit != 0x09 && unit != 0x0A && unit != 0x0D) {
        i++;
        continue;
      }
      if (unit == 0xFFFE || unit == 0xFFFF) {
        i++;
        continue;
      }
      buffer.writeCharCode(unit);
      i++;
    }
    return buffer.toString();
  }

  /// Caches result with size management
  static void _cacheResult(String key, String value) {
    _cache[key] = value;
    
    // Prevent cache from growing too large
    if (_cache.length > _maxCacheSize) {
      final keys = _cache.keys.toList();
      _cache.remove(keys.first);
    }
  }

  static String sanitizeForStreaming(String fullText, int currentIndex, {bool preserveMarkdown = true}) {
    if (fullText.isEmpty || currentIndex <= 0) return '';
    if (currentIndex >= fullText.length) return sanitize(fullText, preserveMarkdown: preserveMarkdown);

    try {
      final codeUnits = fullText.codeUnits;
      final safeIndex = currentIndex.clamp(0, codeUnits.length);
      if (safeIndex > 0 && _isHighSurrogate(codeUnits[safeIndex - 1])) {
        return String.fromCharCodes(codeUnits.sublist(0, safeIndex));
      }
      return sanitize(String.fromCharCodes(codeUnits.sublist(0, safeIndex)), preserveMarkdown: preserveMarkdown);
    } catch (e) {
      return _sanitizeCodeUnits(fullText);
    }
  }

  /// Checks if a code unit is a high surrogate
  static bool _isHighSurrogate(int codeUnit) {
    return codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
  }

  static String sanitizeToAscii(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    final codeUnits = text.codeUnits;
    for (int i = 0; i < codeUnits.length; i++) {
      final unit = codeUnits[i];
      if (unit >= 0x20 && unit <= 0x7E) {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }

  /// Clears the cache (useful for testing or memory management)
  static void clearCache() {
    _cache.clear();
  }

  /// Gets cache statistics for debugging
  static Map<String, dynamic> getCacheStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
      'hitRate': _cache.isNotEmpty ? 'Available' : 'No data',
    };
  }

  /// Validates if a string is safe for UTF-16 rendering
  static bool isValidUtf16(String text) {
    try {
      text.runes.toList();
      return true;
    } catch (e) {
      return false;
    }
  }
}