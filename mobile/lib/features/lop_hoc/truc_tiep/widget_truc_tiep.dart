import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../giao_dien/san_choi.dart';
import 'ket_noi_truc_tiep.dart';

/// Mảnh giao diện dùng chung cho ba màn trực tiếp (học sinh, điều khiển, chiếu).
///
/// Bốn đáp án mang bốn MÀU + bốn HÌNH (tam giác, thoi, tròn, vuông) như Kahoot: màn chiếu
/// ở cuối lớp nhìn không rõ chữ, và em mù màu vẫn nhận ra bằng hình. Màu lấy trong bộ
/// Imperial Light (đỏ son, vàng đậm, lục, nâu thẫm).
const mauDapAn = {
  'A': AppColors.red,
  'B': AppColors.goldDark,
  'C': AppColors.success,
  'D': AppColors.redDeepest,
};

const hinhDapAn = {
  'A': Icons.change_history_rounded,
  'B': Icons.diamond_rounded,
  'C': Icons.circle,
  'D': Icons.square_rounded,
};

const cacDapAn = ['A', 'B', 'C', 'D'];

/// Ô đáp án. [dung] = null khi chưa lộ đáp án.
class ODapAn extends StatelessWidget {
  const ODapAn({
    super.key,
    required this.k,
    required this.chu,
    this.onTap,
    this.daChon = false,
    this.dung,
    this.co = 1,
    this.caoO,
  });

  final String k;
  final String chu;
  final VoidCallback? onTap;
  final bool daChon;
  final bool? dung;
  final double co; // hệ số phóng chữ: 1 = điện thoại, ~2 = máy chiếu
  final double? caoO;

  @override
  Widget build(BuildContext context) {
    final mau = mauDapAn[k]!;
    // Đã lộ đáp án: câu đúng giữ màu, câu sai mờ đi
    final mo = dung == false ? .65 : 1.0;
    final noiDung = Text(chu,
        style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            color: Colors.white,
            fontSize: 16 * co,
            height: 1.25));
    return Semantics(
      button: onTap != null,
      label: 'Đáp án $k: $chu${daChon ? ', em đã chọn' : ''}',
      child: Opacity(
        opacity: mo,
        child: Material(
          color: mau,
          borderRadius: BorderRadius.circular(14 * co),
          child: InkWell(
            borderRadius: BorderRadius.circular(14 * co),
            onTap: onTap,
            child: Container(
              height: caoO,
              constraints: const BoxConstraints(minHeight: 64),
              padding:
                  EdgeInsets.symmetric(horizontal: 14 * co, vertical: 14 * co),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14 * co),
                border: Border.all(
                  color: daChon ? AppColors.goldBright : Colors.transparent,
                  width: 3 * co,
                ),
              ),
              child: Row(children: [
                Icon(hinhDapAn[k], color: Colors.white, size: 24 * co),
                SizedBox(width: 10 * co),
                Expanded(
                  child: caoO == null
                      ? noiDung
                      : LayoutBuilder(
                          builder: (context, rang) => FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                  width: rang.maxWidth, child: noiDung))),
                ),
                if (dung == true)
                  Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 26 * co),
                if (daChon && dung == false)
                  Icon(Icons.close_rounded, color: Colors.white, size: 26 * co),
                if (daChon && dung == null)
                  Icon(Icons.radio_button_checked,
                      color: AppColors.goldBright, size: 22 * co),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lưới 4 đáp án: 2 cột khi đủ rộng (máy chiếu, máy tính bảng), 1 cột trên điện thoại hẹp.
class LuoiDapAn extends StatelessWidget {
  const LuoiDapAn({
    super.key,
    required this.options,
    this.daChon,
    this.dapAn,
    this.dungDaChon,
    this.onChon,
    this.co = 1,
    this.caoO,
  });

  final Map<String, dynamic> options;
  final String? daChon;
  final String? dapAn;
  final bool? dungDaChon;
  final void Function(String k)? onChon;
  final double co;
  final double? caoO;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, rang) {
      final haiCot = rang.maxWidth >= 560;
      final o = [
        for (final k in cacDapAn)
          ODapAn(
            k: k,
            chu: '${options[k] ?? ''}',
            daChon: daChon == k,
            dung:
                dapAn == null ? (daChon == k ? dungDaChon : null) : dapAn == k,
            onTap: onChon == null ? null : () => onChon!(k),
            co: co,
            caoO: caoO,
          ),
      ];
      final khe = 10.0 * co;
      if (!haiCot) {
        return Column(children: [
          for (final w in o)
            Padding(padding: EdgeInsets.only(bottom: khe), child: w)
        ]);
      }
      return Column(children: [
        for (var i = 0; i < 4; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: khe),
            child: IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: o[i]),
                    SizedBox(width: khe),
                    Expanded(child: o[i + 1]),
                  ]),
            ),
          ),
      ]);
    });
  }
}

/// Đồng hồ đếm ngược tới [hanLuc] (giờ máy này — xem KetNoiTrucTiep.hanLuc).
class DemNguoc extends StatefulWidget {
  const DemNguoc(
      {super.key, required this.hanLuc, required this.tongGiay, this.co = 1});

  final DateTime? hanLuc;
  final int tongGiay;
  final double co;

  @override
  State<DemNguoc> createState() => _DemNguocState();
}

class _DemNguocState extends State<DemNguoc> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final han = widget.hanLuc;
    final conMs = han == null
        ? 0
        : han
            .difference(DateTime.now())
            .inMilliseconds
            .clamp(0, widget.tongGiay * 1000);
    final giay = (conMs / 1000).ceil();
    final gap = giay <= 5;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 34 * widget.co,
        height: 34 * widget.co,
        child: CircularProgressIndicator(
          value: widget.tongGiay == 0 ? 0 : conMs / (widget.tongGiay * 1000),
          strokeWidth: 4 * widget.co,
          backgroundColor: AppColors.border,
          valueColor: AlwaysStoppedAnimation(
              gap ? AppColors.danger : AppColors.goldDark),
        ),
      ),
      SizedBox(width: 8 * widget.co),
      Text('${giay}s',
          style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
              fontSize: 22 * widget.co,
              color: gap ? AppColors.danger : AppColors.ink)),
    ]);
  }
}

/// Bốn cột phân bố A/B/C/D sau khi lộ đáp án.
class BieuDoPhanBo extends StatelessWidget {
  const BieuDoPhanBo(
      {super.key, required this.phanBo, required this.dapAn, this.co = 1});

  final Map<String, dynamic> phanBo;
  final String? dapAn;
  final double co;

  @override
  Widget build(BuildContext context) {
    final so = {for (final k in cacDapAn) k: (phanBo[k] as num?)?.toInt() ?? 0};
    final lon = so.values.fold<int>(1, (a, b) => b > a ? b : a);
    return SizedBox(
      height: 130 * co,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final k in cacDapAn)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6 * co),
              child:
                  Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${so[k]}',
                    style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        fontSize: 18 * co,
                        color: AppColors.ink)),
                SizedBox(height: 4 * co),
                Container(
                  height: 8 * co + 72 * co * so[k]! / lon,
                  decoration: BoxDecoration(
                    color: mauDapAn[k]!.withValues(
                        alpha: dapAn == null || dapAn == k ? 1 : .35),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(6 * co)),
                  ),
                ),
                SizedBox(height: 4 * co),
                Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(hinhDapAn[k], size: 16 * co, color: mauDapAn[k]),
                      SizedBox(width: 3 * co),
                      Text(k,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w600,
                            fontSize: 15 * co,
                          )),
                      if (dapAn == k)
                        Icon(Icons.check_rounded,
                            size: 18 * co, color: AppColors.success),
                    ]),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// TOP N sau mỗi câu. [toi] = tên em đang xem, để tô đậm dòng của em.
class BangTop extends StatelessWidget {
  const BangTop({super.key, required this.top, this.toi, this.co = 1});

  final List<dynamic> top;
  final String? toi;
  final double co;

  @override
  Widget build(BuildContext context) {
    return NhipSanChoi(
        key: ValueKey(
            top.map((h) => '${h['hang']}:${h['ten']}:${h['diem']}').join('|')),
        child: Column(children: [
          for (final h in top.cast<Map>())
            Container(
              margin: EdgeInsets.only(bottom: 6 * co),
              padding:
                  EdgeInsets.symmetric(horizontal: 12 * co, vertical: 8 * co),
              decoration: BoxDecoration(
                color: h['ten'] == toi
                    ? AppColors.goldBright.withValues(alpha: .35)
                    : AppColors.card,
                borderRadius: BorderRadius.circular(10 * co),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                SizedBox(
                  width: 34 * co,
                  child: Text(chuDuLieu(h['hang']),
                      style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 18 * co,
                          color: AppColors.redDark)),
                ),
                AnhBan(
                    ten: '${h['ten'] ?? 'Bạn'}',
                    url: h['avatar_url'] as String?,
                    ma: h['avatar'] as String?,
                    co: 32 * co),
                SizedBox(width: 8 * co),
                Expanded(
                  child: Text('${h['ten'] ?? 'Bạn'}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 16 * co,
                          color: AppColors.ink)),
                ),
                Text(chuDuLieu(h['diem']),
                    style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        fontSize: 16 * co,
                        color: AppColors.ink)),
              ]),
            ),
        ]));
  }
}

/// Bục 1-2-3 chung cuộc: hạng 2 bên trái, hạng 1 giữa (cao nhất), hạng 3 bên phải.
class BucVinhDanh extends StatelessWidget {
  const BucVinhDanh({super.key, required this.bang, this.co = 1});

  final List<dynamic> bang;
  final double co;

  @override
  Widget build(BuildContext context) {
    final ds = bang.cast<Map>();
    Widget cot(int i, double cao, Color mau) {
      if (i >= ds.length) return const Expanded(child: SizedBox());
      final h = ds[i];
      return Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          AnhBan(
              ten: '${h['ten'] ?? 'Bạn'}',
              url: h['avatar_url'] as String?,
              ma: h['avatar'] as String?,
              co: 40 * co),
          SizedBox(height: 4 * co),
          Flexible(
              child: Text('${h['ten'] ?? 'Bạn'}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 16 * co,
                      color: AppColors.ink))),
          Text('${chuDuLieu(h['diem'])} điểm',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 13 * co,
                  color: AppColors.inkSoft)),
          SizedBox(height: 6 * co),
          Container(
            height: cao * co,
            margin: EdgeInsets.symmetric(horizontal: 6 * co),
            decoration: BoxDecoration(
              color: mau,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10 * co)),
            ),
            alignment: Alignment.topCenter,
            padding: EdgeInsets.only(top: 8 * co),
            child: Text(chuDuLieu(h['hang']),
                style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontWeight: FontWeight.w700,
                    fontSize: 30 * co,
                    color: Colors.white)),
          ),
        ]),
      );
    }

    return SizedBox(
      height: 280 * co,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        cot(1, 100, AppColors.inkMuted),
        cot(0, 140, AppColors.gold),
        cot(2, 72, AppColors.goldDark),
      ]),
    );
  }
}

/// Dải báo đường nối khi KHÔNG phải WebSocket (đang nối / hỏi định kỳ).
class DaiKetNoi extends StatelessWidget {
  const DaiKetNoi({super.key, required this.kn});

  final KetNoiTrucTiep kn;

  @override
  Widget build(BuildContext context) {
    if (kn.duong == DuongNoi.websocket && kn.trangThai != null)
      return const SizedBox.shrink();
    final chu = kn.duong == DuongNoi.dangNoi
        ? 'Đang vào phòng…'
        : 'Mất kết nối — đang thử lại… Câu mới có thể chậm vài giây.';
    return Container(
      width: double.infinity,
      color: AppColors.goldBright.withValues(alpha: .35),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(chu,
          style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 12.5,
              color: AppColors.ink)),
    );
  }
}
