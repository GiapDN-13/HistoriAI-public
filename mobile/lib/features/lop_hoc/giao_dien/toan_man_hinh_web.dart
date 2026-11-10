import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> doiToanManHinh() async {
  try {
    if (web.document.fullscreenElement != null) {
      await web.document.exitFullscreen().toDart;
    } else {
      await web.document.documentElement!.requestFullscreen().toDart;
    }
    return true;
  } catch (_) {
    // Một số máy chiếu dùng trình duyệt chặn API, thầy cô vẫn dùng được F11.
    return false;
  }
}
