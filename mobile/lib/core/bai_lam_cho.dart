import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Bài quiz CHƯA LƯU được lên máy chủ — giữ trên máy rồi gửi sau.
///
/// Hai trường hợp:
///   • Khách (chưa đăng nhập) chơi quiz. Trước đây bài làm mất hẳn khi đăng ký,
///     dù màn hình mời "đăng nhập để lưu tiến độ".
///   • Đã đăng nhập nhưng nộp hỏng (mất mạng). Trước đây lỗi bị nuốt im lặng,
///     màn kết quả trông như đã lưu.
/// AuthService gọi [guiHet] ngay sau mỗi lần đăng nhập/đăng ký; app gọi thêm lúc
/// mở nếu đang đăng nhập sẵn. Máy chủ chỉ cộng XP cho lần đầu trả lời đúng mỗi câu,
/// nên gửi lại một lượt đã lưu cũng không cộng XP hai lần.
class BaiLamCho {
  BaiLamCho._();

  static const _khoa = 'bai_lam_cho_v1';

  /// Giữ tối đa bấy nhiêu lượt — đủ cho một buổi chơi thử dài.
  static const toiDa = 30;

  static Future<List<List<Map<String, dynamic>>>> _doc(SharedPreferences p) async {
    try {
      final raw = p.getString(_khoa);
      if (raw == null) return [];
      final ds = jsonDecode(raw);
      if (ds is! List) return [];
      return [
        for (final luot in ds)
          if (luot is List)
            [
              for (final c in luot)
                if (c is Map && c['question_id'] is int)
                  {'question_id': c['question_id'], 'selected_option': '${c['selected_option'] ?? ''}'},
            ],
      ].where((l) => l.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> them(List<Map<String, dynamic>> luot) async {
    if (luot.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final ds = await _doc(p)..add(luot);
    final gon = ds.length > toiDa ? ds.sublist(ds.length - toiDa) : ds;
    await p.setString(_khoa, jsonEncode(gon));
  }

  static Future<int> soLuot() async =>
      (await _doc(await SharedPreferences.getInstance())).length;

  /// Gửi hết các lượt đang chờ. Trả về số lượt gửi được. Lượt nào lỗi mạng thì
  /// giữ lại lần sau; lượt máy chủ từ chối hẳn (4xx, không phải 401) thì bỏ.
  static Future<int>? _dangGui;

  static Future<int> guiHet(ApiClient api) {
    // Một lượt gửi mỗi lúc: hai nơi gọi cùng lúc (mở app + đăng nhập) mà cùng đọc
    // danh sách trước khi kịp xoá là mỗi bài bị gửi hai lần.
    return _dangGui ??= _guiHet(api).whenComplete(() => _dangGui = null);
  }

  static Future<int> _guiHet(ApiClient api) async {
    if (!api.isSignedIn) return 0;
    final p = await SharedPreferences.getInstance();
    final ds = await _doc(p);
    if (ds.isEmpty) return 0;
    final conLai = <List<Map<String, dynamic>>>[];
    var daGui = 0;
    for (final luot in ds) {
      try {
        await api.postJson('/quiz/submit', luot);
        daGui++;
      } on ApiException catch (e) {
        final ma = e.statusCode ?? 0;
        if (e.isConnectionError || ma == 401 || ma >= 500) conLai.add(luot);
      } catch (_) {
        conLai.add(luot);
      }
    }
    if (conLai.isEmpty) {
      await p.remove(_khoa);
    } else {
      await p.setString(_khoa, jsonEncode(conLai));
    }
    return daGui;
  }
}
