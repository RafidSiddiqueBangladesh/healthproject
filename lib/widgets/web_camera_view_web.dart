// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class WebCameraView extends StatefulWidget {
  const WebCameraView({
    super.key,
    required this.containerId,
  });

  final String containerId;

  @override
  State<WebCameraView> createState() => _WebCameraViewState();
}

class _WebCameraViewState extends State<WebCameraView> {
  static final Set<String> _registered = <String>{};

  @override
  void initState() {
    super.initState();
    if (!_registered.contains(widget.containerId)) {
      ui_web.platformViewRegistry.registerViewFactory(widget.containerId, (int viewId) {
        final div = html.DivElement()
          ..id = widget.containerId
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#000000';
        return div;
      });
      _registered.add(widget.containerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: widget.containerId);
  }
}
