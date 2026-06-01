// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget buildWebViewer(String url) {
  ui_web.platformViewRegistry.registerViewFactory('rooom-iframe-$url', (
    int viewId,
  ) {
    return html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'xr-spatial-tracking';
  });
  return HtmlElementView(viewType: 'rooom-iframe-$url');
}
