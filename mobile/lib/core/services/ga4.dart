import 'ga4_stub.dart' if (dart.library.js_interop) 'ga4_web.dart' as impl;

/// Gửi hành vi lên Google Analytics 4.
///
/// Chỉ chạy trên web, và chỉ khi build có truyền mã đo:
/// ```
/// flutter build web --dart-define=GA4_ID=G-XXXXXXXXXX
/// ```
/// Không truyền thì lớp này im lặng hoàn toàn — app vẫn đo bình thường qua
/// backend của nhóm. Trên Android/iOS: no-op (GA4 native cần Firebase SDK,
/// chưa nằm trong phạm vi kỳ này).
class Ga4 {
  /// Nạp gtag.js vào trang. Gọi một lần lúc mở app.
  static void khoiDong() => impl.khoiDong();

  /// True nếu gtag đã được nạp (có mã đo và đang chạy web).
  static bool get dangChay => impl.dangChay;

  static void gui(
    String ten, {
    String? target,
    int? value,
    Map<String, dynamic>? them,
  }) =>
      impl.gui(ten, target: target, value: value, them: them);
}
