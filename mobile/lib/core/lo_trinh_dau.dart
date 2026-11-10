import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics.dart';

/// Ba bước đầu cho người mới — thẻ "Bắt đầu từ đây" trên trang chủ.
///
/// VÌ SAO (góp ý 17/10): "lúc mới vào mình chưa biết nên xem video, làm quiz hay
/// chat trước". Trang chủ có bốn ô khám phá ngang hàng nhau và không chỉ lối nào
/// trước. Thẻ này xếp sẵn một thứ tự ngắn, cùng một trận (Bạch Đằng 938 — trận
/// duy nhất có phim): xem phim → hỏi vĩ nhân → làm quiz.
///
/// Bước tự đánh dấu khi người dùng làm thật (nghe sự kiện đo lường), lưu trên máy.
class LoTrinhDau {
  LoTrinhDau._();

  static const xemPhim = 'xem_phim';
  static const hoiViNhan = 'hoi_vi_nhan';
  static const lamQuiz = 'lam_quiz';
  static const cacBuoc = [xemPhim, hoiViNhan, lamQuiz];

  static const _khoaXong = 'lo_trinh_dau_xong_v1';
  static const _khoaAn = 'lo_trinh_dau_an_v1';

  static final daXong = ValueNotifier<Set<String>>(const {});
  static final daAn = ValueNotifier<bool>(false);

  static bool _daNghe = false;

  /// Đọc trạng thái trên máy + bắt đầu nghe hành vi. Gọi một lần lúc mở app.
  static Future<void> khoiDong() async {
    if (!_daNghe) {
      _daNghe = true;
      Analytics.instance.nghe((ten, _) {
        final buoc = switch (ten) {
          Ev.videoPlay => xemPhim,
          Ev.chatMessageSent => hoiViNhan,
          Ev.quizSubmit => lamQuiz,
          _ => null,
        };
        if (buoc != null) danhDau(buoc);
      });
    }
    try {
      final p = await SharedPreferences.getInstance();
      daXong.value = {...?p.getStringList(_khoaXong)};
      daAn.value = p.getBool(_khoaAn) ?? false;
    } catch (_) {}
  }

  static bool get xongHet => cacBuoc.every(daXong.value.contains);

  static Future<void> danhDau(String buoc) async {
    if (daXong.value.contains(buoc)) return;
    daXong.value = {...daXong.value, buoc};
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_khoaXong, daXong.value.toList());
    } catch (_) {}
  }

  static Future<void> an() async {
    daAn.value = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_khoaAn, true);
    } catch (_) {}
  }

  @visibleForTesting
  static void datLaiChoTest() {
    daXong.value = const {};
    daAn.value = false;
  }
}
