import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

class WebH264View extends StatefulWidget {
  const WebH264View({super.key});

  @override
  State<WebH264View> createState() => _WebH264ViewState();
}

class _WebH264ViewState extends State<WebH264View> {
  static bool _registered = false;

  @override
  void initState() {
    super.initState();
    if (!_registered) {
      ui_web.platformViewRegistry.registerViewFactory(
        'spacenotes-h264-decoder-view',
        (int viewId) {
          final existing = web.document.getElementById('spacenotes-h264-decoder');
          if (existing != null) {
            final el = existing as web.HTMLElement;
            el.style.display = 'block';
            el.style.width = '100%';
            el.style.height = '100%';
            (el as web.HTMLCanvasElement).style.objectFit = 'cover';
            return el;
          }
          final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
          canvas.id = 'spacenotes-h264-decoder';
          canvas.style.width = '100%';
          canvas.style.height = '100%';
          canvas.style.objectFit = 'cover';
          return canvas;
        },
      );
      _registered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: 'spacenotes-h264-decoder-view');
  }
}
