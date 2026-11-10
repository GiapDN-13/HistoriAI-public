// Không phải web: nhúng viewer.html bằng WebView của hệ điều hành.
//
// Vì sao dùng lại chính viewer.html của bản web thay vì một gói Flutter 3D:
// trang đó đã chạy ổn định trên thật, nên phần render không phải kiểm thử lại
// từ đầu. `model_viewer_plus` nhúng trực tiếp từng cho ra ô trống (xem ghi chú
// trong glb_viewer.dart), mà nó cũng chỉ là WebView bọc đúng model-viewer này.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'glb_viewer.dart' show GlbViewerController;

/// Chỉ Android và iOS có WebView. Trên Windows/Linux và trong test chạy bằng
/// máy ảo Dart thì không — gọi WebViewController ở đó là ném ngoại lệ, nên
/// phải chặn từ đây chứ không để tới lúc dựng widget.
bool get _coWebView {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

Widget buildGlbView({
  required String url,
  required Widget fallback,
  GlbViewerController? dieuKhien,
}) =>
    _coWebView
        ? _GlbWebView(url: url, fallback: fallback, dieuKhien: dieuKhien)
        : fallback;

class _GlbWebView extends StatefulWidget {
  const _GlbWebView({
    required this.url,
    required this.fallback,
    this.dieuKhien,
  });

  final String url;
  final Widget fallback;
  final GlbViewerController? dieuKhien;

  @override
  State<_GlbWebView> createState() => _GlbWebViewState();
}

class _GlbWebViewState extends State<_GlbWebView> {
  WebViewController? _dieuKhien;
  bool _hong = false;

  @override
  void initState() {
    super.initState();
    _dungWebView();
    widget.dieuKhien?.noiVao((ten, motLan) {
      // Nuốt lỗi có chủ đích: trang có thể chưa nạp xong, và một cái vẫy tay
      // lỡ nhịp thì không đáng làm hỏng cuộc trò chuyện.
      _dieuKhien?.runJavaScript(
          "window.doiCuDong && window.doiCuDong('$ten', $motLan)");
    });
  }

  @override
  void dispose() {
    widget.dieuKhien?.noiVao(null);
    super.dispose();
  }

  @override
  void didUpdateWidget(_GlbWebView cu) {
    super.didUpdateWidget(cu);
    // Đổi cổ vật thì nạp lại chính WebView đang có, đừng dựng cái mới — mỗi
    // WebView là một tiến trình con, dựng lại liên tục là tốn bộ nhớ và chớp
    // trắng mỗi lần người dùng chuyển hiện vật.
    if (cu.url != widget.url) {
      _dieuKhien?.loadRequest(Uri.parse(widget.url));
    }
  }

  void _dungWebView() {
    try {
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        // Nền kem thay vì trắng: model-viewer mất một nhịp mới vẽ xong, trong
        // nhịp đó một ô trắng giữa giao diện kem nhìn như lỗi.
        ..setBackgroundColor(const Color(0xFFFDF9F4))
        ..setNavigationDelegate(NavigationDelegate(
          onWebResourceError: (loi) {
            // Chỉ coi là hỏng khi chính trang chủ không nạp được. Một tệp phụ
            // lỗi (ảnh môi trường chẳng hạn) thì model vẫn hiện bình thường.
            if (loi.isForMainFrame ?? true) {
              if (mounted) setState(() => _hong = true);
            }
          },
        ))
        ..loadRequest(Uri.parse(widget.url));
      _dieuKhien = c;
    } catch (_) {
      _hong = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _dieuKhien;
    if (_hong || c == null) return widget.fallback;
    return WebViewWidget(controller: c);
  }
}
