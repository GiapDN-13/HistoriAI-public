import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Một lượt trong cuộc trò chuyện đã lưu.
class LuotDaLuu {
  const LuotDaLuu({
    required this.laNguoiDung,
    required this.noiDung,
    this.nguon = const [],
  });

  final bool laNguoiDung;
  final String noiDung;

  /// Nguồn sử liệu của câu trả lời (chỉ lượt của vĩ nhân).
  final List<String> nguon;

  Map<String, dynamic> toJson() =>
      {'u': laNguoiDung, 't': noiDung, if (nguon.isNotEmpty) 'n': nguon};

  static LuotDaLuu? tuJson(Object? j) {
    if (j is! Map) return null;
    final t = j['t'];
    if (t is! String || t.trim().isEmpty) return null;
    final n = j['n'];
    return LuotDaLuu(
      laNguoiDung: j['u'] == true,
      noiDung: t,
      nguon: n is List ? n.whereType<String>().toList() : const [],
    );
  }

  /// Dạng máy chủ cần để vĩ nhân nhớ ngữ cảnh (xem backend/app/schemas/chat.py).
  Map<String, String> choMayChu() =>
      {'role': laNguoiDung ? 'user' : 'assistant', 'content': noiDung};
}

/// Lưu cuộc trò chuyện với từng vĩ nhân NGAY TRÊN MÁY.
///
/// Trước đây thoát màn là mất sạch. Cố ý không lưu lên máy chủ: đây là chữ học
/// sinh tự gõ, có thể có thông tin cá nhân — giữ trên máy thì chỉ người cầm máy
/// thấy, và nút thùng rác "Xoá cuộc trò chuyện" là xoá hẳn.
class LichSuChat {
  LichSuChat._();

  /// Giữ tối đa bấy nhiêu lượt gần nhất cho mỗi vĩ nhân.
  static const toiDa = 60;

  static String _khoa(String slug) => 'chat_lich_su_$slug';

  static Future<List<LuotDaLuu>> doc(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_khoa(slug));
      if (raw == null) return const [];
      final ds = jsonDecode(raw);
      if (ds is! List) return const [];
      return ds.map(LuotDaLuu.tuJson).whereType<LuotDaLuu>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> ghi(String slug, List<LuotDaLuu> ds) async {
    final gon = ds.length > toiDa ? ds.sublist(ds.length - toiDa) : ds;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _khoa(slug), jsonEncode(gon.map((l) => l.toJson()).toList()));
    } catch (_) {}
  }

  static Future<void> xoa(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_khoa(slug));
    } catch (_) {}
  }

  /// Xoá trò chuyện với MỌI vĩ nhân trên máy này. Trả số cuộc đã xoá.
  static Future<int> xoaHet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final khoa = prefs.getKeys().where((k) => k.startsWith(_khoa(''))).toList();
      for (final k in khoa) {
        await prefs.remove(k);
      }
      return khoa.length;
    } catch (_) {
      return 0;
    }
  }
}
