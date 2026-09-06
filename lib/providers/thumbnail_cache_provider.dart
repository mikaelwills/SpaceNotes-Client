import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/debug_logger.dart';
import '../services/file_transfer_service.dart';
import 'file_transfer_providers.dart';

const _maxCacheEntries = 500;
const _debounceDuration = Duration(milliseconds: 200);

class ThumbnailCache extends Notifier<Map<String, Uint8List>> {
  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  final Set<String> _pending = {};
  final Set<String> _inFlight = {};
  Timer? _debounceTimer;

  @override
  Map<String, Uint8List> build() {
    return _cache;
  }

  /// Touches `id` to the front of LRU order, then returns its cached bytes.
  Uint8List? touch(String id) {
    final bytes = _cache.remove(id);
    if (bytes == null) return null;
    _cache[id] = bytes;
    return bytes;
  }

  void request(String id) {
    if (_cache.containsKey(id) || _inFlight.contains(id) || _pending.contains(id)) {
      debugLogger.debug('THUMB', 'Request skipped (already cached/pending/in-flight)', id);
      return;
    }
    debugLogger.debug('THUMB', 'Request queued', id);
    _pending.add(id);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _flush);
  }

  Future<void> _flush() async {
    final ids = _pending.toList();
    _pending.clear();
    if (ids.isEmpty) return;

    debugLogger.info('THUMB', 'Flushing batch', 'count=${ids.length} ids=$ids');
    _inFlight.addAll(ids);
    final service = ref.read(fileTransferServiceProvider);

    await Future.wait(ids.map((id) => _fetchOne(service, id)));
  }

  Future<void> _fetchOne(FileTransferService service, String id) async {
    try {
      debugLogger.debug('THUMB', 'Fetching', id);
      final bytes = await service.fetchThumbnail(id);
      debugLogger.info('THUMB', 'Fetched OK', '$id bytes=${bytes.length}');
      _store(id, Uint8List.fromList(bytes));
    } catch (e) {
      debugLogger.error('THUMB', 'Fetch failed', '$id error=$e');
    } finally {
      _inFlight.remove(id);
    }
  }

  void _store(String id, Uint8List bytes) {
    _cache[id] = bytes;
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    debugLogger.debug('THUMB', 'Cache updated', 'size=${_cache.length}');
    state = Map.of(_cache);
  }
}

final thumbnailCacheProvider =
    NotifierProvider<ThumbnailCache, Map<String, Uint8List>>(ThumbnailCache.new);
