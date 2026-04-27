import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'debug_logger.dart';
import 'paste_image_listener.dart';

class _WebPasteListener implements PasteImageListener {
  PastedImageHandler? _handler;
  JSFunction? _wrapped;

  @override
  void register(PastedImageHandler handler) {
    _handler = handler;
    _wrapped ??= ((web.Event event) {
      _onPaste(event as web.ClipboardEvent);
    }).toJS;
    web.document.addEventListener('paste', _wrapped);
  }

  @override
  void unregister() {
    if (_wrapped != null) {
      web.document.removeEventListener('paste', _wrapped);
    }
    _handler = null;
  }

  void _onPaste(web.ClipboardEvent event) {
    final handler = _handler;
    if (handler == null) return;
    final data = event.clipboardData;
    if (data == null) return;
    final items = data.items;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.kind != 'file') continue;
      if (!item.type.startsWith('image/')) continue;
      final file = item.getAsFile();
      if (file == null) continue;

      event.preventDefault();
      _readBlob(file, handler);
      return;
    }
  }

  Future<void> _readBlob(web.Blob blob, PastedImageHandler handler) async {
    try {
      final buffer = await blob.arrayBuffer().toDart;
      final bytes = buffer.toDart.asUint8List();
      handler(bytes);
    } catch (e) {
      debugLogger.error('PASTE', 'blob read failed: $e');
    }
  }
}

PasteImageListener createPasteImageListener() => _WebPasteListener();
