// Web: nạp gtag.js rồi đẩy event lên Google Analytics 4.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Mã đo GA4, truyền lúc build:
/// `flutter build web --dart-define=GA4_ID=G-XXXXXXXXXX`.
/// Để trống thì cả nhánh GA4 nằm im.
const _ga4Id = String.fromEnvironment('GA4_ID');

/// Chỉ nhận đúng dạng mã đo của GA4. Chuỗi này được ghép thẳng vào một thẻ
/// script, nên phải chặn ở đây thay vì tin vào tham số build.
final _hopLe = RegExp(r'^G-[A-Z0-9]{4,20}$');

bool _daNap = false;

bool get dangChay => _daNap;

void khoiDong() {
  if (_daNap || _ga4Id.isEmpty) return;
  if (!_hopLe.hasMatch(_ga4Id)) {
    web.console.warn('GA4_ID sai định dạng, bỏ qua GA4.'.toJS);
    return;
  }

  try {
    final tai = web.HTMLScriptElement()
      ..async = true
      ..src = 'https://www.googletagmanager.com/gtag/js?id=$_ga4Id';
    web.document.head!.appendChild(tai);

    final khoiTao = web.HTMLScriptElement()
      ..text = 'window.dataLayer=window.dataLayer||[];'
          'function gtag(){dataLayer.push(arguments);}'
          "gtag('js',new Date());"
          // Màn hình do Flutter tự vẽ, GA4 không thấy được điều hướng nội bộ
          // nên tắt page_view tự động; app tự gửi event của mình.
          "gtag('config','$_ga4Id',{send_page_view:false});";
    web.document.head!.appendChild(khoiTao);

    _daNap = true;
  } catch (_) {
    // Trình chặn quảng cáo chặn googletagmanager là chuyện thường —
    // số liệu ở backend nhóm vẫn đủ, không cần báo gì.
  }
}

void gui(String ten, {String? target, int? value, Map<String, dynamic>? them}) {
  if (!_daNap) return;
  try {
    // gtag do script inline ở trên định nghĩa; nếu bị chặn thì không có.
    if (!globalContext.has('gtag')) return;
    final params = <String, dynamic>{
      if (target != null) 'target': target,
      if (value != null) 'value': value,
      ...?them,
    };
    globalContext.callMethod('gtag'.toJS, 'event'.toJS, ten.toJS, params.jsify());
  } catch (_) {
    // Đo lường hỏng thì im lặng, tuyệt đối không để nổi lên giao diện.
  }
}
