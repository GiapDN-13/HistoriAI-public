import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'nguon_trang_truoc_stub.dart'
    if (dart.library.js_interop) 'nguon_trang_truoc_web.dart' as trang_truoc;

/// Khách tới từ đâu: Facebook, Zalo, Google Form, mã QR trên poster…
///
/// CÁCH GẮN NHÃN
///     Mỗi kênh dùng một đường dẫn riêng, vd
///       https://historiai.org/?utm_source=facebook&utm_campaign=ra-mat
///     hoặc gọn cho mã QR:  https://historiai.org/?ref=qr
///     Không có nhãn thì lấy tên miền trang đã dẫn tới (facebook.com → facebook).
///     Không có cả hai → "truc-tiep" (gõ thẳng, bấm dấu trang, mở từ app).
///
/// NGUỒN ĐẦU TIÊN
///     Máy nào lần đầu tới từ Facebook thì mãi tính là khách của Facebook, kể cả
///     hôm sau gõ thẳng địa chỉ quay lại. Đó mới là câu trả lời cho "kênh nào
///     mang người dùng về" — nếu tính theo lần gần nhất thì kênh "trực tiếp" sẽ
///     nuốt hết công của các kênh khác.
///
/// Chỉ lưu tên nguồn (vd "facebook"), không lưu cả địa chỉ trang trước — trong
/// đó có thể có mã định danh riêng của người dùng.
class NguonTruyCap {
  const NguonTruyCap({required this.nguon, this.kenh, this.chienDich, this.noiDung});

  final String nguon;
  final String? kenh;
  final String? chienDich;
  final String? noiDung;

  static const trucTiep = 'truc-tiep';
  static const _khoaDauTien = 'nguon_truy_cap_dau_tien';

  /// Viết tắt cho mã QR / link ngắn: ?ref=fb thay vì ?utm_source=facebook
  static const _vietTat = {
    'fb': 'facebook',
    'zl': 'zalo',
    'gg': 'google',
    'form': 'google-form',
    'gf': 'google-form',
    'tt': 'tiktok',
    'ig': 'instagram',
    'yt': 'youtube',
    'qr': 'qr',
    'mail': 'email',
  };

  Map<String, dynamic> thanhParams() => {
        'nguon': nguon,
        if (kenh != null) 'kenh': kenh,
        if (chienDich != null) 'chien_dich': chienDich,
        if (noiDung != null) 'noi_dung': noiDung,
      };

  Map<String, dynamic> _json() => thanhParams();

  static NguonTruyCap? _tuJson(Map<String, dynamic> j) {
    final n = j['nguon'];
    if (n is! String || n.isEmpty) return null;
    return NguonTruyCap(
      nguon: n,
      kenh: j['kenh'] as String?,
      chienDich: j['chien_dich'] as String?,
      noiDung: j['noi_dung'] as String?,
    );
  }

  /// Chuẩn hoá nhãn: chữ thường, chỉ a-z 0-9 - _, tối đa 40 ký tự.
  /// Ai đó gõ "Facebook Page!!" vẫn gộp chung với "facebook-page".
  static String? lamSach(String? s) {
    if (s == null) return null;
    var t = s.trim().toLowerCase();
    t = t.replaceAll(RegExp(r'\s+'), '-').replaceAll(RegExp(r'[^a-z0-9_-]'), '');
    t = t.replaceAll(RegExp(r'-{2,}'), '-');
    if (t.isEmpty) return null;
    return t.length > 40 ? t.substring(0, 40) : t;
  }

  /// Đọc nguồn của lần mở này từ địa chỉ trang và trang trước đó.
  static NguonTruyCap tuDiaChi(Uri diaChi, String trangTruoc) {
    final q = diaChi.queryParameters;
    var nguon = lamSach(q['utm_source']);
    final ref = lamSach(q['ref']);
    if (nguon == null && ref != null) nguon = _vietTat[ref] ?? ref;
    if (nguon != null) {
      return NguonTruyCap(
        nguon: nguon,
        kenh: lamSach(q['utm_medium']),
        chienDich: lamSach(q['utm_campaign']),
        noiDung: lamSach(q['utm_content']),
      );
    }
    final tuTrang = nguonTuTrangTruoc(trangTruoc, diaChi.host);
    return tuTrang != null
        ? NguonTruyCap(nguon: tuTrang, kenh: 'gioi-thieu')
        : const NguonTruyCap(nguon: trucTiep);
  }

  /// facebook.com, l.facebook.com, m.facebook.com → "facebook"; trang của chính
  /// app (chuyển trang nội bộ, tên miền cũ chuyển hướng) → không tính.
  static String? nguonTuTrangTruoc(String trangTruoc, String hostCuaApp) {
    if (trangTruoc.isEmpty) return null;
    final host = Uri.tryParse(trangTruoc)?.host.toLowerCase() ?? '';
    if (host.isEmpty) return null;
    if (host == hostCuaApp || host.contains('historiai')) return null;
    const bang = [
      (['facebook.', 'fb.com', 'fb.me', 'messenger.'], 'facebook'),
      (['zalo.'], 'zalo'),
      (['forms.gle', 'docs.google.'], 'google-form'),
      (['google.'], 'google'),
      (['tiktok.'], 'tiktok'),
      (['instagram.'], 'instagram'),
      (['youtube.', 'youtu.be'], 'youtube'),
      (['bing.'], 'bing'),
      (['coccoc.'], 'coccoc'),
      (['t.co', 'twitter.', 'x.com'], 'x'),
    ];
    for (final (mau, ten) in bang) {
      if (mau.any((m) => host == m || host.contains(m))) return ten;
    }
    return lamSach(host.replaceFirst(RegExp(r'^(www|m|l|lm)\.'), ''));
  }

  /// Nguồn của lần mở này + nguồn đầu tiên đã nhớ (lần đầu thì nhớ luôn).
  static Future<({NguonTruyCap hienTai, NguonTruyCap dauTien, bool lanDau})> docVaNho() async {
    // Bản cài Android không mở từ đường dẫn nào nên không có nhãn để đọc; ghi rõ
    // là khách của bản cài thay vì để lẫn vào "trực tiếp".
    final hienTai = kIsWeb
        ? tuDiaChi(Uri.base, trang_truoc.trangTruoc())
        : const NguonTruyCap(nguon: 'ban-cai-android', kenh: 'app');
    try {
      final prefs = await SharedPreferences.getInstance();
      final cu = prefs.getString(_khoaDauTien);
      if (cu != null) {
        final dauTien = _tuJson((jsonDecode(cu) as Map).cast<String, dynamic>());
        if (dauTien != null) return (hienTai: hienTai, dauTien: dauTien, lanDau: false);
      }
      await prefs.setString(_khoaDauTien, jsonEncode(hienTai._json()));
    } catch (_) {
      // Bộ nhớ trình duyệt bị chặn — dùng nguồn của lần này
    }
    return (hienTai: hienTai, dauTien: hienTai, lanDau: true);
  }

  /// Nguồn đầu tiên đã nhớ, dùng khi đăng ký. null nếu chưa từng ghi.
  static Future<NguonTruyCap?> dauTienDaNho() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cu = prefs.getString(_khoaDauTien);
      if (cu == null) return null;
      return _tuJson((jsonDecode(cu) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }
}
