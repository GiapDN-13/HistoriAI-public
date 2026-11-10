import 'package:web/web.dart' as web;

/// Web đã được "Thêm vào màn hình chính" và đang mở từ biểu tượng đó (PWA).
bool dangChayNhuApp() {
  try {
    return web.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}
