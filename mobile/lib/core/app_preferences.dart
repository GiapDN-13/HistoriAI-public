import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences._();

  static const _emberEffectsKey = 'app_ember_effects_enabled';

  /// Hạt lửa trang trí MẶC ĐỊNH TẮT trên điện thoại (21/10): lớp này là một iframe
  /// CSS động phủ cả trang, đo trên bản dựng với CPU chậm 4× làm tụt từ ~46 xuống
  /// ~28 hình/giây — đúng loại máy học sinh hay dùng. Máy tính vẫn bật. Ai thích thì
  /// bật lại ở Tài khoản › Tuỳ chỉnh.
  static bool get _macDinhHatLua =>
      !(defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static final emberEffectsEnabled = ValueNotifier<bool>(_macDinhHatLua);

  static const _lopHocKey = 'app_lop_hoc';

  static const _tuDocKey = 'app_tu_doc_tra_loi';

  /// Tự đọc câu trả lời của vĩ nhân ngay khi chữ hiện ra. Tắt thì vẫn bấm
  /// nút loa trên từng câu để nghe như trước.
  static final tuDoc = ValueNotifier<bool>(true);

  /// Lớp đang học (6–12), null = chưa chọn. Lưu trên máy để khách chưa đăng
  /// nhập cũng có tóm tắt đúng cấp; đăng nhập rồi thì đồng bộ với máy chủ.
  static final lopHoc = ValueNotifier<int?>(null);

  static Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      emberEffectsEnabled.value =
          preferences.getBool(_emberEffectsKey) ?? _macDinhHatLua;
      tuDoc.value = preferences.getBool(_tuDocKey) ?? true;
      final lop = preferences.getInt(_lopHocKey);
      lopHoc.value = (lop != null && lop >= 6 && lop <= 12) ? lop : null;
    } catch (_) {
      emberEffectsEnabled.value = _macDinhHatLua;
    }
  }

  static Future<void> setEmberEffectsEnabled(bool enabled) async {
    emberEffectsEnabled.value = enabled;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_emberEffectsKey, enabled);
    } catch (_) {
      // The visual setting still applies for this session if storage is unavailable.
    }
  }

  static Future<void> setTuDoc(bool bat) async {
    tuDoc.value = bat;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_tuDocKey, bat);
    } catch (_) {}
  }

  static Future<void> setLopHoc(int? lop) async {
    lopHoc.value = lop;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (lop == null) {
        await preferences.remove(_lopHocKey);
      } else {
        await preferences.setInt(_lopHocKey, lop);
      }
    } catch (_) {
      // Vẫn dùng được trong phiên này nếu bộ nhớ trình duyệt bị chặn.
    }
  }
}
