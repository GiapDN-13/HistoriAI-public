import 'package:flutter/foundation.dart' show visibleForTesting;

import '../core/api_client.dart';

/// Bài học theo lộ trình do nhóm soạn — `GET /lo-trinh`
/// (backend/app/services/lo_trinh.py, dữ liệu backend/data/lo_trinh.json).
///
/// VÌ SAO: góp ý lặp lại nhiều nhất là "nội dung còn ít". Tài liệu lộ trình của nhóm
/// (bám SGK) có đủ mục tiêu, bối cảnh, diễn biến, kết quả cho từng trận; app trước
/// đây chỉ dùng câu chốt. Máy chủ chỉ trả lộ trình nhóm đã duyệt.

/// Mục c) của tài liệu. Tiêu đề đổi theo trận ("Kế sách chủ chốt", "Vì sao quân
/// Nguyên phải rút?"…) nên giữ nguyên văn để hiện, không ghi cứng trong app.
class KienThucLoTrinh {
  const KienThucLoTrinh({required this.tieuDe, this.y = const []});
  final String tieuDe;
  final List<String> y;

  factory KienThucLoTrinh.fromJson(Map<String, dynamic> j) => KienThucLoTrinh(
        tieuDe: (j['tieu_de'] ?? '').toString(),
        y: _dsChu(j['y']),
      );
}

/// Bài học của một trận trong lộ trình.
class BaiHocLoTrinh {
  const BaiHocLoTrinh({
    required this.slug,
    required this.tenNgan,
    required this.mucTieu,
    this.ten = '',
    this.boiCanh = const [],
    this.kienThuc = const KienThucLoTrinh(tieuDe: ''),
    this.dienBien = const [],
    this.ketQua = const [],
    this.cauChot = '',
    this.khoa = false,
  });

  final String slug;
  final String ten;

  /// Tên ngắn cho dòng "Theo lộ trình: Bạch Đằng 938 → Chống Tống 981 → …".
  final String tenNgan;
  final String mucTieu;
  final List<String> boiCanh;
  final KienThucLoTrinh kienThuc;

  /// Theo đúng thứ tự trong tài liệu — app tự đánh số 1, 2, 3…
  final List<String> dienBien;
  final List<String> ketQua;
  final String cauChot;

  /// Máy chủ chỉ gửi Mục tiêu + câu chốt cho bài này (bản thường, bài thứ 2 trở đi
  /// của lộ trình): bối cảnh, diễn biến, kết quả đang RỖNG vì máy chủ không gửi chứ
  /// không phải vì tài liệu thiếu. Mở bằng Premium.
  final bool khoa;

  factory BaiHocLoTrinh.fromJson(Map<String, dynamic> j) => BaiHocLoTrinh(
        slug: (j['slug'] ?? '').toString(),
        ten: (j['ten'] ?? '').toString(),
        tenNgan: (j['ten_ngan'] ?? j['ten'] ?? '').toString(),
        mucTieu: (j['muc_tieu'] ?? '').toString(),
        boiCanh: _dsChu(j['boi_canh']),
        kienThuc: j['kien_thuc'] is Map
            ? KienThucLoTrinh.fromJson((j['kien_thuc'] as Map).cast<String, dynamic>())
            : const KienThucLoTrinh(tieuDe: ''),
        dienBien: _dsChu(j['dien_bien']),
        ketQua: _dsChu(j['ket_qua']),
        cauChot: (j['cau_chot'] ?? '').toString(),
        khoa: j['khoa'] == true,
      );
}

class LoTrinhHoc {
  const LoTrinhHoc({required this.ma, required this.ten, required this.suKien});
  final String ma;
  final String ten;
  final List<BaiHocLoTrinh> suKien;

  factory LoTrinhHoc.fromJson(Map<String, dynamic> j) => LoTrinhHoc(
        ma: (j['ma'] ?? '').toString(),
        ten: (j['ten'] ?? '').toString(),
        suKien: ((j['su_kien'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => BaiHocLoTrinh.fromJson(m.cast<String, dynamic>()))
            .where((b) => b.slug.isNotEmpty)
            .toList(),
      );
}

/// Bài học của một trận kèm chỗ của nó trong lộ trình ("bài 2/3").
class ViTriBaiHoc {
  const ViTriBaiHoc({required this.loTrinh, required this.chiSo});
  final LoTrinhHoc loTrinh;

  /// Vị trí tính từ 0 trong [LoTrinhHoc.suKien].
  final int chiSo;

  BaiHocLoTrinh get bai => loTrinh.suKien[chiSo];
  int get soBai => chiSo + 1;
  int get tongSoBai => loTrinh.suKien.length;
}

/// Tải `/lo-trinh` MỘT lần cho cả phiên: mở màn chi tiết của trận nào cũng cần cả
/// danh sách (để biết "bài mấy"), gọi lại mỗi lần mở màn là phí lượt mạng.
/// Tải hỏng thì không nhớ lỗi — lần mở màn sau thử lại.
///
/// NỘI DUNG ĐỔI THEO NGƯỜI DÙNG: máy chủ cắt bài khoá theo tài khoản (bản thường /
/// Premium), nên kho nhớ cả mã đăng nhập đã dùng khi tải. Đăng nhập, đăng xuất hay
/// đổi tài khoản là mã đổi → tự tải lại, khỏi để học sinh vừa đăng nhập Premium mà
/// vẫn thấy bản khách. Vừa mua Premium (token không đổi) thì gọi [lamMoi].
class KhoLoTrinh {
  KhoLoTrinh._();

  static Future<List<LoTrinhHoc>>? _dangTai;
  static String? _maDaTai;

  /// Bỏ bản nhớ, lần [tai] sau hỏi lại máy chủ.
  static void lamMoi() => _dangTai = null;

  static Future<List<LoTrinhHoc>> tai() {
    final ma = ApiClient().maDangNhap;
    if (_dangTai != null && _maDaTai != ma) _dangTai = null;
    _maDaTai = ma;
    final dang = _dangTai ??= _tai();
    // Hỏng thì quên lần tải này để lần sau thử lại; lỗi vẫn về tới người gọi.
    dang.catchError((Object _) {
      if (identical(_dangTai, dang)) _dangTai = null;
      return const <LoTrinhHoc>[];
    });
    return dang;
  }

  static Future<List<LoTrinhHoc>> _tai() async {
    final tho = await ApiClient().get('/lo-trinh');
    return ((tho as List?) ?? const [])
        .whereType<Map>()
        .map((m) => LoTrinhHoc.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// Bài học của sự kiện [slug]; null khi chưa có lộ trình nào chứa trận này,
  /// hoặc tải hỏng (mất mạng, máy chủ cũ chưa có /lo-trinh) — màn hình ẩn mục.
  static Future<ViTriBaiHoc?> timBai(String slug) async {
    final List<LoTrinhHoc> ds;
    try {
      ds = await tai();
    } catch (_) {
      return null;
    }
    for (final lt in ds) {
      final i = lt.suKien.indexWhere((b) => b.slug == slug);
      if (i >= 0) return ViTriBaiHoc(loTrinh: lt, chiSo: i);
    }
    return null;
  }

  /// Mỗi test tiêm máy chủ giả riêng — bỏ kết quả của test trước.
  @visibleForTesting
  static void datLaiChoTest() {
    _dangTai = null;
    _maDaTai = null;
  }
}

List<String> _dsChu(dynamic tho) => ((tho as List?) ?? const [])
    .map((e) => e?.toString().trim() ?? '')
    .where((s) => s.isNotEmpty)
    .toList();
