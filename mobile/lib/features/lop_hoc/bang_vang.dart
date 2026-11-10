import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import 'lop_hoc_api.dart';
import 'giao_dien/san_choi.dart';
import 'tai_tep_stub.dart' if (dart.library.js_interop) 'tai_tep_web.dart';

/// Bảng vàng của phòng thi cho HỌC SINH + giấy vinh danh lưu được thành ảnh.
///
/// Học sinh làm xong muốn biết mình đứng thứ mấy, và muốn có thứ để khoe bố mẹ / gửi
/// nhóm lớp. Bảng vàng lấy từ GET /phong/{ma}/xep-hang (chỉ sau khi nộp / hết trận).

const _vang = Color(0xFFD4AF37);
const _bac = Color(0xFFB8BEC6);
const _dong = Color(0xFFC07A3F);

Color mauHuyChuong(int? hang) =>
    switch (hang) { 1 => _vang, 2 => _bac, 3 => _dong, _ => AppColors.inkSoft };

/// Danh hiệu trên giấy vinh danh. Kèm lời thường để học sinh không phải đoán nghĩa
/// (góp ý 04/10: "Đồng Sinh", "binh pháp tiền nhân"… khó hiểu).
(String, String) danhHieu(int? hang, double diem10) {
  if (hang == 1) return ('Trạng Nguyên', 'Hạng nhất cả phòng');
  if (hang == 2) return ('Bảng Nhãn', 'Hạng nhì cả phòng');
  if (hang == 3) return ('Thám Hoa', 'Hạng ba cả phòng');
  if (diem10 >= 8) return ('Xuất sắc', 'Đạt từ 8 điểm trở lên');
  if (diem10 >= 6.5) return ('Giỏi', 'Đạt từ 6,5 điểm trở lên');
  if (diem10 >= 5) return ('Hoàn thành tốt', 'Đạt từ 5 điểm trở lên');
  return ('Đã hoàn thành', 'Cố lên, lần sau sẽ cao hơn!');
}

class BangVangPhong extends StatefulWidget {
  const BangVangPhong(
      {super.key, required this.ma, required this.api, this.coNutGiay = true});

  final String ma;
  final LopHocApi api;
  final bool coNutGiay;

  @override
  State<BangVangPhong> createState() => _BangVangPhongState();
}

class _BangVangPhongState extends State<BangVangPhong> {
  Map<String, dynamic>? _d;
  bool _loi = false;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    try {
      final d = await widget.api.bangVang(widget.ma);
      if (mounted) setState(() => _d = d);
    } catch (_) {
      if (mounted) setState(() => _loi = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loi)
      return TextButton.icon(
          onPressed: () {
            setState(() => _loi = false);
            _tai();
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tải lại bảng vàng'));
    final d = _d;
    if (d == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AppColors.red)),
      );
    }
    final top = (d['top'] as List? ?? []).cast<Map<String, dynamic>>();
    final toi = (d['cua_toi'] as Map? ?? {}).cast<String, dynamic>();
    final coToi = top.any((h) => h['la_toi'] == true);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _vang, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _vang.withValues(alpha: .18),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            gradient: imperialDarkGradient,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(children: [
            const Icon(Icons.emoji_events_rounded,
                color: AppColors.goldBright, size: 34),
            const SizedBox(height: 2),
            const Text('BẢNG VÀNG',
                style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: AppColors.goldBright,
                    letterSpacing: 2)),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                    '${d['tieu_de'] ?? 'Bài kiểm tra'} · ${chuDuLieu(d['tong_hoc_sinh'])} bạn đã làm',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        color: AppColors.onRed.withValues(alpha: .85),
                        fontSize: 12.5))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
          child: Column(children: [
            for (final h in top) _Dong(h: h, tongCau: d['tong_cau'] as int?),
            if (!coToi && toi.isNotEmpty) ...[
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2), child: Text('⋯')),
              _Dong(
                  h: {...toi, 'la_toi': true}, tongCau: d['tong_cau'] as int?),
            ],
          ]),
        ),
        if (widget.coNutGiay)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.decorativeOrange,
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GiayVinhDanhScreen(du: d),
                  fullscreenDialog: true)),
              icon: const Icon(Icons.workspace_premium_rounded,
                  color: AppColors.goldBright),
              label: const Text('Nhận giấy vinh danh của em'),
            ),
          ),
      ]),
    );
  }
}

class _Dong extends StatelessWidget {
  const _Dong({required this.h, required this.tongCau});

  final Map<String, dynamic> h;
  final int? tongCau;

  @override
  Widget build(BuildContext context) {
    final hang = h['hang'] as int?;
    final toi = h['la_toi'] == true;
    final mau = mauHuyChuong(hang);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: toi
            ? AppColors.gold.withValues(alpha: .18)
            : (hang != null && hang <= 3 ? mau.withValues(alpha: .08) : null),
        borderRadius: BorderRadius.circular(12),
        border: toi ? Border.all(color: AppColors.gold, width: 1.5) : null,
      ),
      child: Row(children: [
        SizedBox(
          width: 34,
          child: hang != null && hang <= 3
              ? Icon(Icons.military_tech_rounded, color: mau, size: 28)
              : Text(chuDuLieu(hang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft)),
        ),
        const SizedBox(width: 6),
        AnhBan(
            ten: '${h['ten'] ?? 'Em'}',
            url: h['avatar_url'] as String?,
            ma: h['avatar'] as String?,
            co: 32),
        const SizedBox(width: 8),
        Expanded(
          child: Text('${h['ten'] ?? 'Em'}${toi ? '  (em)' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.ink)),
        ),
        Text(
            h['diem'] != null
                ? '${h['diem']} điểm'
                : '${chuDuLieu(h['so_dung'])}/${chuDuLieu(tongCau)}',
            style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: hang == 1 ? const Color(0xFF9A7A12) : AppColors.ink)),
      ]),
    );
  }
}

/// Giấy vinh danh — vẽ trong RepaintBoundary để chụp thành ảnh PNG.
class GiayVinhDanhScreen extends StatefulWidget {
  const GiayVinhDanhScreen({super.key, required this.du});

  final Map<String, dynamic> du;

  @override
  State<GiayVinhDanhScreen> createState() => _GiayVinhDanhScreenState();
}

class _GiayVinhDanhScreenState extends State<GiayVinhDanhScreen> {
  final _khung = GlobalKey();
  bool _dangLuu = false;
  bool _story = false;

  Future<void> _luu() async {
    setState(() => _dangLuu = true);
    final tin = ScaffoldMessenger.of(context);
    try {
      final b =
          _khung.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final anh = await b.toImage(pixelRatio: 3);
      final png = (await anh.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      anh.dispose();
      // Giữ dấu tiếng Việt trong tên tệp; chỉ bỏ ký tự hệ điều hành cấm và khoảng trắng.
      final ten = '${(widget.du['cua_toi'] as Map?)?['ten'] ?? 'hoc-sinh'}'
          .trim()
          .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '-');
      final daTai =
          await taiAnh('vinh-danh-$ten-${_story ? '9x16' : '4x5'}.png', png);
      tin.showSnackBar(SnackBar(
          content: Text(daTai
              ? 'Đã lưu ảnh. Gửi cho bố mẹ hoặc đăng lên nhóm lớp nhé!'
              : 'Bản cài chưa lưu ảnh được — em chụp màn hình để lưu nhé.')));
    } catch (_) {
      tin.showSnackBar(const SnackBar(
          content: Text('Chưa lưu được ảnh — em chụp màn hình để lưu nhé.')));
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KhungLopHoc(
      backgroundColor: const Color(0xFF2B1410),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.goldBright,
        title: const Text('GIẤY VINH DANH'),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                // Boundary nằm TRONG FittedBox: ảnh không phụ thuộc cỡ màn điện thoại.
                child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(
                        key: _khung,
                        child: SizedBox(
                            width: _story ? 420 : 480,
                            height: _story ? 420 * 16 / 9 : 600,
                            child:
                                GiayVinhDanh(du: widget.du, story: _story)))),
              ),
            ),
          ),
          OutlinedButton.icon(
            style:
                OutlinedButton.styleFrom(foregroundColor: AppColors.goldBright),
            onPressed: _dangLuu ? null : () => setState(() => _story = !_story),
            icon: const Icon(Icons.aspect_ratio_rounded),
            label: Text(_story
                ? 'Story 9:16 · đổi sang bài đăng'
                : 'Bài đăng 4:5 · đổi sang story'),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.goldBright,
                foregroundColor: const Color(0xFF2B1410),
              ),
              onPressed: _dangLuu ? null : _luu,
              icon: const Icon(Icons.download_rounded),
              label: Text(_dangLuu ? 'Đang tạo ảnh…' : 'Lưu ảnh để khoe'),
            ),
          ),
        ]),
      ),
    );
  }
}

class GiayVinhDanh extends StatelessWidget {
  const GiayVinhDanh({super.key, required this.du, this.story = false});

  final Map<String, dynamic> du;
  final bool story;

  @override
  Widget build(BuildContext context) {
    final toi = (du['cua_toi'] as Map? ?? {}).cast<String, dynamic>();
    final hang = toi['hang'] as int?;
    final diem10 = (toi['diem_10'] as num?)?.toDouble() ?? 0;
    final (ten, nghia) = danhHieu(hang, diem10);
    // Giấy để khoe: chỉ in thứ hạng khi đáng khoe (top 3 hoặc nửa trên của phòng).
    // "Hạng 7/7" in to giữa giấy chỉ làm em ngại, không ai muốn gửi cho bố mẹ.
    final vuot = (toi['vuot_pct'] as num?) ?? 0;
    final khoeHang = hang != null && (hang <= 3 || vuot >= 50);
    final mau = hang != null && hang <= 3 ? mauHuyChuong(hang) : _vang;
    final ngay = DateTime.tryParse('${du['ngay']}')?.toLocal();
    final chuNgay = ngay == null
        ? ''
        : 'Ngày ${ngay.day} tháng ${ngay.month} năm ${ngay.year}';
    final diemChu = diem10 == diem10.roundToDouble()
        ? diem10.toStringAsFixed(0)
        : diem10.toStringAsFixed(1);

    // Dựng ở khổ cố định rồi thu phóng: máy nào cũng giống hệt, ảnh lưu ra luôn đúng
    // tỉ lệ 7:10, và chữ không bao giờ tràn trên điện thoại hẹp.
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: story ? 420 : 480,
        height: story ? 420 * 16 / 9 : 600,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFDF9F4), Color(0xFFFBF3E6)],
            ),
            border: Border.all(color: AppColors.red, width: 6),
          ),
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration:
                BoxDecoration(border: Border.all(color: _vang, width: 2)),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const ChimLacMotif(size: 46, color: AppColors.red),
                const SizedBox(width: 8),
                Text('HISTORIAI',
                    style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.red.withValues(alpha: .9),
                        letterSpacing: 3)),
                const SizedBox(width: 8),
                Transform.flip(
                    flipX: true,
                    child: const ChimLacMotif(size: 46, color: AppColors.red)),
              ]),
              const Text('GIẤY VINH DANH',
                  style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontWeight: FontWeight.w700,
                      fontSize: 26,
                      color: Color(0xFF7A2218),
                      letterSpacing: 1.5)),
              const SizedBox(height: 2),
              const Text('trân trọng ghi nhận',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF7C5A4A),
                      fontSize: 12.5)),
              const Spacer(),
              Text('${toi['ten'] ?? 'Em'}',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontWeight: FontWeight.w700,
                      fontSize: 27,
                      color: Color(0xFF2B1410),
                      height: 1.15)),
              if ('${toi['lop'] ?? ''}'.isNotEmpty)
                Text('Lớp ${toi['lop']}',
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF7C5A4A),
                        fontSize: 14)),
              const Spacer(),
              // Huy hiệu danh hiệu
              Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    mau.withValues(alpha: .95),
                    Color.lerp(mau, Colors.black, .25)!
                  ]),
                  border: Border.all(color: AppColors.red, width: 4),
                  boxShadow: [
                    BoxShadow(color: mau.withValues(alpha: .45), blurRadius: 16)
                  ],
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          hang != null && hang <= 3
                              ? Icons.emoji_events_rounded
                              : Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 30),
                      if (khoeHang) ...[
                        Text('Hạng $hang',
                            style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 17)),
                        Text('/${chuDuLieu(du['tong_hoc_sinh'])} bạn',
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                                fontSize: 11.5)),
                      ] else ...[
                        Text(
                            '${chuDuLieu(toi['so_dung'])}/${chuDuLieu(du['tong_cau'])}',
                            style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 19)),
                        const Text('câu đúng',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                                fontSize: 11.5)),
                      ],
                    ]),
              ),
              const SizedBox(height: 8),
              Text(ten.toUpperCase(),
                  style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: AppColors.red,
                      letterSpacing: 1.2)),
              Text(nghia,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF7C5A4A),
                      fontSize: 12.5)),
              const Spacer(),
              Text('Bài kiểm tra «${du['tieu_de'] ?? 'Lịch sử Việt Nam'}»',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2B1410),
                    fontSize: 14,
                  )),
              const SizedBox(height: 4),
              Text(
                  'Đúng ${chuDuLieu(toi['so_dung'])}/${chuDuLieu(du['tong_cau'])} câu · Điểm ${toi['diem_10'] == null ? '—' : diemChu}/10'
                  '${toi['diem'] != null ? ' · ${toi['diem']} điểm thi' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF2B1410),
                      fontSize: 13.5)),
              if (khoeHang &&
                  toi['vuot_pct'] != null &&
                  (toi['vuot_pct'] as num) > 0)
                Text('Vượt ${toi['vuot_pct']}% các bạn cùng làm bài',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9A7A12),
                      fontSize: 13,
                    )),
              const Spacer(),
              const DongSonWaveDivider(color: _vang, height: 10, opacity: .7),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(chuNgay,
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF7C5A4A),
                                fontSize: 11)),
                        if (du['giao_vien'] != null)
                          Text('Giáo viên: ${du['giao_vien']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF7C5A4A),
                                  fontSize: 11)),
                      ]),
                ),
                const Text('historiai.org',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      color: AppColors.red,
                      fontSize: 12,
                    )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
