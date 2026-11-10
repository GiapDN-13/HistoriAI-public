import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

const _viewType = 'historiai-ember-background';
bool _registered = false;

Widget buildEmberLayer() {
  if (!_registered) {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      // Hạt nằm sẵn trong HTML tĩnh; Dart chỉ nhúng tài liệu, không tạo/animate hạt.
      return web.HTMLIFrameElement()
        ..src =
            Uri.parse(web.document.baseURI).resolve('embers.html').toString()
        ..title = 'Decorative embers'
        ..tabIndex = -1
        ..setAttribute('aria-hidden', 'true')
        ..style.position = 'absolute'
        ..style.inset = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0'
        ..style.background = 'transparent'
        ..style.pointerEvents = 'none';
    });
    _registered = true;
  }

  return const HtmlElementView(
    viewType: _viewType,
  );
}
