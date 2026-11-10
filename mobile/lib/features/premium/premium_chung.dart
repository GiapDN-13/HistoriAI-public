import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Một gói Premium do máy chủ trả ở `GET /thanh-toan/goi`.
///
/// Giá và số ngày LẤY TỪ MÁY CHỦ chứ không viết cứng trong app: máy chủ mới là
/// nơi quyết số tiền được đối chiếu với tiền về — app hiện một số khác thì
/// người dùng chuyển sai mà không hay.
class GoiPremium {
  const GoiPremium({
    required this.ma,
    required this.ten,
    required this.soTien,
    required this.soNgay,
  });

  final String ma;
  final String ten;
  final int soTien;
  final int soNgay;

  /// Gói thử 2.000đ — máy chủ chỉ trả cho tài khoản quản trị, để thử luồng
  /// thanh toán thật mà không tốn 39.000đ mỗi lần.
  bool get laGoiThu => ma == 'thu';

  static GoiPremium? tuJson(Object? j) {
    if (j is! Map) return null;
    final ma = j['ma'];
    final soTien = j['so_tien'];
    if (ma is! String || soTien is! num) return null;
    return GoiPremium(
      ma: ma,
      ten: (j['ten'] as String?) ?? 'HistoriAI Premium',
      soTien: soTien.toInt(),
      soNgay: (j['so_ngay'] as num?)?.toInt() ?? 30,
    );
  }
}

/// 39000 -> "39.000" (không kèm chữ đ).
String dinhDangTien(num soTien) {
  final s = soTien.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Đọc mốc thời gian ISO từ máy chủ.
///
/// Máy chủ lưu giờ UTC; chuỗi không ghi múi giờ vẫn là UTC (cùng quy ước với
/// `lop_hoc.py`). `DateTime.parse` thiếu "Z" sẽ hiểu là giờ máy → lệch 7 tiếng,
/// đủ làm đếm ngược của một đơn sống 15 phút nhảy thành 7 tiếng.
DateTime? docThoiDiem(Object? v) {
  if (v is! String || v.isEmpty) return null;
  final coMuiGio = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(v);
  return DateTime.tryParse(coMuiGio ? v : '${v}Z')?.toLocal();
}

/// dd/MM/yyyy theo giờ máy.
String dinhDangNgay(DateTime d) {
  String hai(int n) => n.toString().padLeft(2, '0');
  return '${hai(d.day)}/${hai(d.month)}/${d.year}';
}

/// Tình trạng Premium của người dùng, đọc từ `/auth/me`.
class TinhTrangPremium {
  const TinhTrangPremium({required this.la, this.den});

  /// Chưa đăng nhập hoặc chưa mua.
  static const khong = TinhTrangPremium(la: false);

  final bool la;
  final DateTime? den;

  factory TinhTrangPremium.tuMe(Map? me) {
    if (me == null) return khong;
    return TinhTrangPremium(
      la: me['la_premium'] == true,
      den: docThoiDiem(me['premium_den']),
    );
  }

  /// Số ngày còn lại, làm tròn LÊN: còn 5 tiếng vẫn là "còn 1 ngày", không
  /// phải "còn 0 ngày" — nghe như đã hết trong khi vẫn dùng được.
  int ngayConLai([DateTime? bayGio]) {
    final d = den;
    if (!la || d == null) return 0;
    final phut = d.difference(bayGio ?? DateTime.now()).inMinutes;
    if (phut <= 0) return 0;
    return (phut / (60 * 24)).ceil();
  }

  /// Từ ngưỡng này trở đi (số ngày còn lại ≤ ngưỡng) thì nhắc gia hạn.
  static const ngayNhacGiaHan = 3;

  bool canNhacGiaHan([DateTime? bayGio]) {
    if (!la) return false;
    final n = ngayConLai(bayGio);
    return n >= 1 && n <= ngayNhacGiaHan;
  }
}

/// BỐN quyền lợi Premium nhóm đã chốt — màn Premium và thẻ hết lượt cùng dùng danh
/// sách này, để hai nơi không bao giờ nói hai điều khác nhau. Máy chủ mới là nơi thật
/// sự khoá/mở từng thứ (hỏi vĩ nhân: `han_muc_ngay.py`; bản tin: `ban_tin.py`; ôn câu
/// sai: `/me/cau-sai`; lộ trình: `/lo-trinh`). Thêm dòng ở đây mà máy chủ chưa giao
/// là hứa suông — thêm/bớt thì sửa cả hai phía.
///
/// Dùng widget riêng với `Icon` const chứ KHÔNG dùng record chứa `IconData`: bộ rút
/// gọn icon của Flutter web không lần ra được `IconData` nằm trong record và loại nó
/// khỏi font, icon hiện thành vòng tròn rỗng.
class DanhSachQuyenLoi extends StatelessWidget {
  const DanhSachQuyenLoi({super.key, this.gon = false});

  /// Gọn: dùng trong thẻ hết lượt (chữ nhỏ, khoảng cách hẹp).
  final bool gon;

  @override
  Widget build(BuildContext context) {
    final cach = SizedBox(height: gon ? 8 : 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DongQuyenLoi(
            gon: gon, icon: Icons.forum_rounded, chu: 'Hỏi vĩ nhân không giới hạn'),
        cach,
        _DongQuyenLoi(
            gon: gon, icon: Icons.mail_rounded, chu: 'Bản tin phụ huynh đầy đủ'),
        cach,
        _DongQuyenLoi(
            gon: gon, icon: Icons.replay_rounded, chu: 'Ôn toàn bộ câu sai'),
        cach,
        _DongQuyenLoi(
            gon: gon,
            icon: Icons.menu_book_rounded,
            chu: 'Trọn bài học theo lộ trình'),
      ],
    );
  }
}

class _DongQuyenLoi extends StatelessWidget {
  const _DongQuyenLoi({required this.icon, required this.chu, required this.gon});

  final IconData icon;
  final String chu;
  final bool gon;

  @override
  Widget build(BuildContext context) {
    final d = gon ? 30.0 : 38.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            color: AppColors.bgAlt,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: AppColors.primary, size: gon ? 16 : 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            chu,
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: AppColors.ink,
              fontSize: gon ? 14.5 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bảng so sánh ngắn Miễn phí / Premium cho đúng bốn quyền lợi trên.
///
/// Số "10 câu" và "5 câu" là hằng số của máy chủ (`CHAT_MIEN_PHI_NGAY`,
/// `TOI_DA_CAU_SAI_MIEN_PHI`); đổi bên đó thì đổi cả ở đây.
class BangSoSanhPremium extends StatelessWidget {
  const BangSoSanhPremium({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        children: [
          _HangSoSanh(
              dau: true, muc: '', mienPhi: 'Miễn phí', premium: 'Premium'),
          _HangSoSanh(
              muc: 'Hỏi vĩ nhân',
              mienPhi: '10 câu mỗi ngày',
              premium: 'Không giới hạn'),
          _HangSoSanh(
              muc: 'Bản tin phụ huynh',
              mienPhi: 'Tổng kết tuần',
              premium: 'Thêm câu sai và gợi ý bài tuần sau'),
          _HangSoSanh(
              muc: 'Ôn câu sai',
              mienPhi: '5 câu gần nhất',
              premium: 'Toàn bộ'),
          _HangSoSanh(
              muc: 'Bài học lộ trình',
              mienPhi: 'Bài đầu mỗi lộ trình',
              premium: 'Trọn bộ',
              cuoi: true),
        ],
      ),
    );
  }
}

class _HangSoSanh extends StatelessWidget {
  const _HangSoSanh({
    required this.muc,
    required this.mienPhi,
    required this.premium,
    this.dau = false,
    this.cuoi = false,
  });

  final String muc;
  final String mienPhi;
  final String premium;
  final bool dau;
  final bool cuoi;

  @override
  Widget build(BuildContext context) {
    TextStyle kieu(bool noiBat) => dau
        ? TextStyle(
            fontFamily: 'Montserrat',
            color: noiBat ? AppColors.primary : AppColors.inkMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          )
        : TextStyle(
            fontFamily: 'Inter',
            color: AppColors.ink,
            fontSize: 12.5,
            height: 1.35,
            fontWeight: noiBat ? FontWeight.w700 : FontWeight.w500,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dau ? AppColors.bgAlt : null,
        border: cuoi ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 9,
            child: Text(
              muc,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: AppColors.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(flex: 10, child: Text(mienPhi, style: kieu(false))),
          const SizedBox(width: 6),
          Expanded(flex: 11, child: Text(premium, style: kieu(true))),
        ],
      ),
    );
  }
}

/// Nút chính cam/đỏ dùng chung cho luồng Premium.
class NutPremium extends StatelessWidget {
  const NutPremium({
    super.key,
    required this.nhan,
    required this.onTap,
    this.dangXuLy = false,
    this.vienMo = false,
  });

  final String nhan;
  final VoidCallback? onTap;
  final bool dangXuLy;

  /// Nút phụ: nền kem, viền vàng.
  final bool vienMo;

  @override
  Widget build(BuildContext context) {
    final bat = onTap != null && !dangXuLy;
    return Semantics(
      button: true,
      label: nhan,
      child: InkWell(
        onTap: bat ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: vienMo || !bat ? null : ctaGradient,
            color: vienMo
                ? AppColors.bgAlt
                : (bat ? null : AppColors.disabledSurface),
            border: vienMo ? Border.all(color: AppColors.gold) : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: vienMo || !bat
                ? null
                : [
                    BoxShadow(
                      color: AppColors.cta.withValues(alpha: 0.32),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: dangXuLy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  nhan,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: vienMo ? AppColors.primary : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
