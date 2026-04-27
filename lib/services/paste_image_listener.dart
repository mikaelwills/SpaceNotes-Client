import 'dart:typed_data';

import 'paste_image_listener_io.dart'
    if (dart.library.js_interop) 'paste_image_listener_web.dart' as platform;

typedef PastedImageHandler = void Function(Uint8List bytes);

abstract class PasteImageListener {
  void register(PastedImageHandler handler);
  void unregister();
}

PasteImageListener createPasteImageListener() =>
    platform.createPasteImageListener();
