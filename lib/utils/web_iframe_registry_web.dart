import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

void registerIFrame({
  required String viewType,
  required String src,
}) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final iframe = html.IFrameElement()
      ..src = src
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true;
    return iframe;
  });
}
