import '../models/message_part.dart';

/// Optimized utility for generating descriptive tool display names
/// with caching and performance optimizations
class ToolDisplayHelper {
  // Cache for computed display names to avoid recalculation on rebuilds
  static final Map<String, String> _cache = {};
  
  static const Map<String, String> _toolNameMap = {
    'read': 'read',
    'write': 'write',
    'bash': 'bash',
    'grep': 'search',
    'list': 'list',
    'glob': 'find',
    'obsidian-server_view': 'view',
    'obsidian-server_str_replace': 'edit',
    'obsidian-server_create': 'create',
    'storage.write': 'write',
  };

  static const List<String> _spaceNotesPrefixes = [
    'mcp__spacenotes-mcp__',
    'spacenotes-mcp_',
  ];

  static const Map<String, String> _spaceNotesActionMap = {
    'get_note': 'get',
    'create_note': 'create',
    'delete_note': 'delete',
    'move_note': 'move',
    'edit_note': 'edit',
    'append_to_note': 'append',
    'prepend_to_note': 'prepend',
    'search_notes': 'search',
    'list_notes_in_folder': 'list',
    'create_folder': 'create folder',
    'delete_folder': 'delete folder',
    'move_folder': 'move folder',
    'move_notes_to_folder': 'move notes',
  };

  /// Main entry point - gets display name with caching
  static String getDisplayName(MessagePart part) {
    // Create cache key based on part ID and metadata hash
    final metadataHash = part.metadata?.toString().hashCode ?? 0;
    final cacheKey = '${part.id}_$metadataHash';
    
    // Return cached result if available
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }
    
    // Compute and cache the display name
    final displayName = _computeDisplayName(part);
    _cache[cacheKey] = displayName;
    
    // Prevent cache from growing too large (keep last 100 entries)
    if (_cache.length > 100) {
      final keys = _cache.keys.toList();
      _cache.remove(keys.first);
    }
    
    return displayName;
  }

  /// Computes the display name with optimized logic
  static String _computeDisplayName(MessagePart part) {
    final metadata = part.metadata;
    if (metadata == null || metadata.isEmpty) {
      return 'tool';
    }

    // Extract tool name using optimized fallback chain
    final toolName = _extractToolName(metadata);
    if (toolName == null) {
      return 'tool';
    }

    // Try to get additional context for more descriptive names
    final contextualName = _getContextualName(toolName, metadata);
    if (contextualName != null) {
      return contextualName;
    }

    // Fall back to formatted tool name
    return _formatToolName(toolName);
  }

  /// Optimized tool name extraction with smart fallback chain
  static String? _extractToolName(Map<String, dynamic> metadata) {
    // Primary sources in order of preference
    return metadata['tool'] as String? ??
           metadata['name'] as String? ??
           metadata['tool_name'] as String? ??
           metadata['function_name'] as String?;
  }

  /// Gets contextual name by examining tool input parameters
  static String? _getContextualName(String toolName, Map<String, dynamic> metadata) {
    final state = metadata['state'] as Map<String, dynamic>?;
    final input = state?['input'] as Map<String, dynamic>?;
    
    if (input == null) return null;

    // File operations - show filename
    final filePath = input['path'] as String? ?? input['filePath'] as String?;
    if (filePath != null && filePath.isNotEmpty) {
      final fileName = _getFileName(filePath);
      final cleanToolName = _formatToolName(toolName);
      return '$cleanToolName $fileName';
    }

    // Bash commands - show command name
    final command = input['command'] as String?;
    if (command != null && command.isNotEmpty) {
      final commandName = _getFirstWord(command);
      return 'bash $commandName';
    }

    // Search operations - show pattern
    final pattern = input['pattern'] as String?;
    if (pattern != null && pattern.isNotEmpty) {
      // Truncate long patterns
      final displayPattern = pattern.length > 20 
          ? '${pattern.substring(0, 20)}...' 
          : pattern;
      return 'search "$displayPattern"';
    }

    return null;
  }

  /// Optimized filename extraction without creating array
  static String _getFileName(String path) {
    if (path.isEmpty) return path;
    
    final lastSlash = path.lastIndexOf('/');
    return lastSlash == -1 ? path : path.substring(lastSlash + 1);
  }

  /// Optimized first word extraction
  static String _getFirstWord(String text) {
    if (text.isEmpty) return text;
    
    final spaceIndex = text.indexOf(' ');
    return spaceIndex == -1 ? text : text.substring(0, spaceIndex);
  }

  static String _formatToolName(String toolName) {
    final lowerName = toolName.toLowerCase();
    if (_toolNameMap.containsKey(lowerName)) {
      return _toolNameMap[lowerName]!;
    }

    for (final prefix in _spaceNotesPrefixes) {
      if (toolName.startsWith(prefix)) {
        final action = toolName.substring(prefix.length);
        final actionDisplay = _spaceNotesActionMap[action] ?? action;
        return 'SpaceNotes $actionDisplay';
      }
    }

    if (toolName.contains('_')) {
      final lastPart = toolName.substring(toolName.lastIndexOf('_') + 1);
      return lastPart.isNotEmpty ? lastPart : toolName;
    }

    return toolName;
  }

  /// Clears the cache (useful for testing or memory management)
  static void clearCache() {
    _cache.clear();
  }

  /// Gets cache statistics for debugging
  static Map<String, int> getCacheStats() {
    return {
      'size': _cache.length,
      'maxSize': 100,
    };
  }
}