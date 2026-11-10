import 'package:web/web.dart' as web;

/// Địa chỉ trang đã dẫn người dùng tới (document.referrer). Rỗng nếu gõ thẳng,
/// hoặc trang trước chặn gửi referrer.
String trangTruoc() {
  try {
    return web.document.referrer;
  } catch (_) {
    return '';
  }
}
