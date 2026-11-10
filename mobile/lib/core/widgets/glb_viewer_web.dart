// Web-only: nhúng viewer.html qua <iframe> bằng HtmlElementView.
import 'dart:js_interop' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'glb_viewer.dart' show GlbViewerController;

final Set<String> _registered = {};
final Map<String, web.HTMLIFrameElement> _khung = {};

/// Đăng ký 1 iframe cho mỗi URL (view-type duy nhất) rồi hiển thị qua
/// HtmlElementView. Iframe trỏ tới viewer.html?model=<slug>.
Widget buildGlbView({
  required String url,
  required Widget fallback,
  GlbViewerController? dieuKhien,
}) {
  final viewType = 'glb-${url.hashCode}';
  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'xr-spatial-tracking; fullscreen';
      _khung[viewType] = iframe;
      return iframe;
    });
  }
  dieuKhien?.noiVao((ten, motLan) {
    // Trang viewer nằm cùng tên miền nên gửi thẳng được; targetOrigin để '*'
    // vì iframe có thể trỏ sang tên miền khác khi đổi VIEWER_URL lúc dựng.
    _khung[viewType]?.contentWindow?.postMessage(
          {'cuDong': ten, 'motLan': motLan}.jsify(),
          '*'.toJS,
        );
  });
  return HtmlElementView(viewType: viewType);
}
