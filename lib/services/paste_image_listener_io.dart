import 'paste_image_listener.dart';

class _NoopListener implements PasteImageListener {
  @override
  void register(PastedImageHandler handler) {}

  @override
  void unregister() {}
}

PasteImageListener createPasteImageListener() => _NoopListener();
