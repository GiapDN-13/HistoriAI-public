import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme.dart';
import '../giao_dien/san_choi.dart';
import '../giao_dien/toan_man_hinh_stub.dart'
    if (dart.library.js_interop) '../giao_dien/toan_man_hinh_web.dart';
import 'ket_noi_truc_tiep.dart';
import 'widget_truc_tiep.dart';

/// Nội dung phần "chiếu" của giáo viên — dùng cho cả màn điều khiển (cỡ thường) lẫn màn
/// chiếu (cỡ to, [co] ≈ 1,8). KHÔNG hiện đáp án khi câu còn mở: màn chiếu cả lớp nhìn thấy,
/// và máy chủ cũng chưa gửi đáp án xuống trước khi kết thúc câu.
class NoiDungGiaoVien extends StatelessWidget {
  const NoiDungGiaoVien({super.key, required this.kn, this.co = 1});

  final KetNoiTrucTiep kn;
  final double co;

  @override
  Widget build(BuildContext context) {
    final t = kn.trangThai;
    if (t == null) {
      return Center(
        child: kn.loiChet != null
            ? Text(kn.loiChet!,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 16 * co))
            : const CircularProgressIndicator(color: AppColors.red),
      );
    }
    if (co >= 1.5) return _chieu(t);
    switch (kn.pha) {
      case 'cho':
        return _sanh(t);
      case 'dang_hoi':
      case 'lo_dap_an':
        return _cau(t);
      case 'ket_thuc':
        return _chungCuoc(t);
    }
    return const SizedBox.shrink();
  }

  /// Vùng trái dành cho câu hỏi; vùng phải dành cho kết quả để cuối lớp nhìn đủ.
  Widget _chieu(Map<String, dynamic> t) {
    final cau = (t['cau'] as Map?)?.cast<String, dynamic>();
    final lo = kn.pha == 'lo_dap_an';
    final hs = (t['hoc_sinh'] as List?) ?? [];
    final bang = (t['bang_xep_hang'] as List?) ?? (t['top'] as List?) ?? [];
    return Padding(
        padding: const EdgeInsets.fromLTRB(48, 44, 48, 24),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: Text('${t['tieu_de'] ?? 'Sân chơi lịch sử'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headingMedium)),
            Text('Phòng ${t['ma'] ?? kn.ma}', style: AppTypography.labelMedium),
          ]),
          const SizedBox(height: 20),
          Expanded(
              child: kn.pha == 'cho'
                  ? Row(children: [
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Text('Cả lớp cùng thử tài',
                                style: AppTypography.headingLarge
                                    .copyWith(fontSize: 42)),
                            const SizedBox(height: 8),
                            FittedBox(
                                child: Text('${t['ma'] ?? kn.ma}',
                                    style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 96,
                                        letterSpacing: 12,
                                        color: AppColors.red))),
                            if (t['link'] != null)
                              QrImageView(
                                  data: '${t['link']}',
                                  size: 248,
                                  backgroundColor: Colors.white),
                            const SizedBox(height: 8),
                            Text('Quét mã hoặc vào historiai.org',
                                style: AppTypography.bodyLarge
                                    .copyWith(fontSize: 24)),
                          ])),
                      const SizedBox(width: 32),
                      Expanded(
                          child: Column(children: [
                        Text('${hs.length} em đã vào sảnh',
                            style: AppTypography.headingLarge),
                        const SizedBox(height: 16),
                        Expanded(
                            child: SingleChildScrollView(
                                child: Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                              for (final h in hs)
                                Chip(
                                    label: Text('${h['ten'] ?? 'Bạn'}',
                                        style: AppTypography.bodyLarge
                                            .copyWith(fontSize: 24)),
                                    avatar: AnhBan(
                                        ten: '${h['ten'] ?? 'Bạn'}',
                                        url: h['avatar_url'] as String?,
                                        ma: h['avatar'] as String?))
                            ]))),
                      ])),
                    ])
                  : kn.pha == 'ket_thuc'
                      ? Row(children: [
                          Expanded(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                Text('Bảng vàng chung cuộc',
                                    style: AppTypography.headingLarge
                                        .copyWith(fontSize: 40)),
                                const SizedBox(height: 16),
                                BucVinhDanh(bang: bang, co: 1.6),
                              ])),
                          const SizedBox(width: 32),
                          Expanded(
                              child: SingleChildScrollView(
                                  child: BangTop(top: bang, co: 1.5))),
                        ])
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                              Expanded(
                                  flex: lo ? 3 : 1,
                                  child: Column(children: [
                                    Row(children: [
                                      Text(
                                          'Câu ${(kn.cauSo ?? 0) + 1}/${chuDuLieu(t['tong_cau'])}',
                                          style: AppTypography.labelMedium
                                              .copyWith(fontSize: 24)),
                                      const Spacer(),
                                      if (!lo)
                                        DemNguoc(
                                            hanLuc: kn.hanLuc,
                                            tongGiay:
                                                (t['giay_moi_cau'] as num?)
                                                        ?.toInt() ??
                                                    30,
                                            co: 1.6),
                                    ]),
                                    Expanded(
                                        child: Center(
                                            child: SingleChildScrollView(
                                                child: Text(
                                                    '${cau?['question'] ?? ''}',
                                                    textAlign: TextAlign.center,
                                                    style: AppTypography
                                                        .headingLarge
                                                        .copyWith(
                                                            fontSize: 42))))),
                                    if (cau != null)
                                      LuoiDapAn(
                                          options: (cau['options'] as Map)
                                              .cast<String, dynamic>(),
                                          dapAn: lo
                                              ? t['dap_an'] as String?
                                              : null,
                                          co: lo ? 1.15 : 1.6),
                                    if (!lo)
                                      Text(
                                          '${chuDuLieu(t['so_da_tra_loi'])}/${chuDuLieu(t['so_hoc_sinh'])} em đã trả lời',
                                          style: AppTypography.labelMedium
                                              .copyWith(fontSize: 24)),
                                  ])),
                              if (lo) ...[
                                const SizedBox(width: 32),
                                Expanded(
                                    flex: 2,
                                    child: SingleChildScrollView(
                                        child: Column(children: [
                                      BieuDoPhanBo(
                                          phanBo: (t['phan_bo'] as Map? ?? {})
                                              .cast<String, dynamic>(),
                                          dapAn: t['dap_an'] as String?,
                                          co: 1.4),
                                      const SizedBox(height: 16),
                                      Text('Dẫn đầu sau câu này',
                                          style: AppTypography.headingMedium),
                                      const SizedBox(height: 12),
                                      BangTop(
                                          top: (t['top'] as List?) ?? [],
                                          co: 1.2),
                                      if (t['giai_thich'] != null)
                                        Text('${t['giai_thich']}',
                                            style: AppTypography.bodyLarge),
                                    ]))),
                              ],
                            ])),
        ]));
  }

  Widget _sanh(Map<String, dynamic> t) {
    final hs = ((t['hoc_sinh'] as List?) ?? const []).cast<Map>();
    final dangNoi = ((t['dang_noi'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toSet();
    final link = '${t['link'] ?? ''}';
    return ListView(padding: EdgeInsets.all(20 * co), children: [
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 28 * co,
        runSpacing: 12 * co,
        children: [
          if (link.isNotEmpty)
            QrImageView(
                data: link,
                size: 170 * co,
                backgroundColor: Colors.white,
                padding: EdgeInsets.all(8 * co)),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Vào historiai.org → "Vào phòng kiểm tra", nhập mã',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    color: AppColors.inkSoft,
                    fontSize: 14 * co)),
            SelectableText('${t['ma']}',
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 56 * co,
                    letterSpacing: 10 * co,
                    color: AppColors.red)),
            Text(
                '${t['tieu_de']} · ${t['tong_cau']} câu · ${t['giay_moi_cau']} giây mỗi câu',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 14 * co,
                    color: AppColors.ink)),
          ]),
        ],
      ),
      SizedBox(height: 20 * co),
      Text('${hs.length} em đã vào sảnh',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w700,
            fontSize: 22 * co,
          )),
      SizedBox(height: 10 * co),
      Wrap(
          alignment: WrapAlignment.center,
          spacing: 8 * co,
          runSpacing: 8 * co,
          children: [
            for (final h in hs)
              Chip(
                backgroundColor: AppColors.card,
                side: const BorderSide(color: AppColors.border),
                avatar: Icon(Icons.circle,
                    size: 10 * co,
                    color: dangNoi.contains(h['user_id'])
                        ? AppColors.success
                        : AppColors.disabledSurface),
                label: Text('${h['ten']}',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 14 * co)),
              ),
          ]),
    ]);
  }

  Widget _cau(Map<String, dynamic> t) {
    final cau = (t['cau'] as Map?)?.cast<String, dynamic>();
    final lo = kn.pha == 'lo_dap_an';
    return ListView(padding: EdgeInsets.all(18 * co), children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text('Câu ${(kn.cauSo ?? 0) + 1}/${t['tong_cau']}',
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 16 * co,
                    color: AppColors.inkSoft)),
            if (!lo) ...[
              Text(
                  '${t['so_da_tra_loi'] ?? 0}/${t['so_hoc_sinh']} em đã trả lời',
                  style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      fontSize: 16 * co,
                      color: AppColors.ink)),
              SizedBox(width: 16 * co),
              DemNguoc(
                  hanLuc: kn.hanLuc,
                  tongGiay: (t['giay_moi_cau'] as num?)?.toInt() ?? 30,
                  co: co),
            ],
          ]),
      SizedBox(height: 14 * co),
      if (cau != null) ...[
        Text('${cau['question']}',
            style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontWeight: FontWeight.w700,
                fontSize: 26 * co,
                color: AppColors.ink,
                height: 1.3)),
        SizedBox(height: 16 * co),
        LuoiDapAn(
            options: (cau['options'] as Map).cast<String, dynamic>(),
            dapAn: lo ? t['dap_an'] as String? : null,
            co: co),
      ],
      if (lo) ...[
        SizedBox(height: 8 * co),
        BieuDoPhanBo(
            phanBo:
                ((t['phan_bo'] as Map?) ?? const {}).cast<String, dynamic>(),
            dapAn: t['dap_an'] as String?,
            co: co),
        if ((t['giai_thich'] ?? '').toString().isNotEmpty) ...[
          SizedBox(height: 10 * co),
          Text('${t['giai_thich']}',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 14 * co,
                  color: AppColors.inkSoft,
                  height: 1.4)),
        ],
        SizedBox(height: 16 * co),
        Text('TOP 5',
            style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 14 * co,
                letterSpacing: 1,
                color: AppColors.inkSoft)),
        SizedBox(height: 6 * co),
        BangTop(top: (t['top'] as List?) ?? const [], co: co),
      ],
    ]);
  }

  Widget _chungCuoc(Map<String, dynamic> t) {
    final bang =
        (t['bang_xep_hang'] as List?) ?? (t['top'] as List?) ?? const [];
    return ListView(padding: EdgeInsets.all(18 * co), children: [
      Text('BẢNG XẾP HẠNG CHUNG CUỘC',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
              fontSize: 16 * co,
              letterSpacing: 1.2,
              color: AppColors.goldDark)),
      SizedBox(height: 4 * co),
      Text('${t['tieu_de']}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w700,
            fontSize: 24 * co,
          )),
      SizedBox(height: 16 * co),
      BucVinhDanh(bang: bang, co: co),
      SizedBox(height: 16 * co),
      if (bang.length > 3) BangTop(top: bang.sublist(3), co: co),
    ]);
  }
}

/// Màn CHIẾU: chữ to, nền kem, không nút rườm rà — để giáo viên đưa lên máy chiếu (mở trên
/// laptop nối máy chiếu, rồi điều khiển bằng điện thoại, hoặc bấm phím ngay trên laptop).
///
/// Phím tắt: Space / Enter / → = bước tiếp theo (bắt đầu → kết thúc câu → câu tiếp).
/// Nối bằng tài khoản giáo viên như màn điều khiển; hai màn cùng mở là hai kết nối, lệnh
/// ở màn nào máy chủ cũng phát cho cả hai (bấm cùng lúc cũng không nhảy hai câu).
class ManChieuScreen extends StatefulWidget {
  const ManChieuScreen({super.key, required this.ma, this.ketNoi});

  final String ma;
  final KetNoiTrucTiep? ketNoi;

  @override
  State<ManChieuScreen> createState() => _ManChieuScreenState();
}

class _ManChieuScreenState extends State<ManChieuScreen> {
  late final KetNoiTrucTiep _kn =
      widget.ketNoi ?? KetNoiTrucTiep(ma: widget.ma);
  final _tieuDiem = FocusNode();

  @override
  void initState() {
    super.initState();
    _kn.addListener(_doi);
    if (widget.ketNoi == null) _kn.batDau();
  }

  @override
  void dispose() {
    _kn.removeListener(_doi);
    if (widget.ketNoi == null) _kn.dispose();
    _tieuDiem.dispose();
    super.dispose();
  }

  void _doi() {
    if (mounted) setState(() {});
  }

  KeyEventResult _phim(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.space ||
        e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.arrowRight) {
      final lenh = lenhTiepTheo(_kn);
      if (lenh != null) _kn.dieuKhien(lenh.$1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rong = MediaQuery.sizeOf(context).width;
    // Phóng chữ theo bề ngang: máy chiếu 1280–1920 px → hệ số ~1,6–2,2
    final co = (rong / 800).clamp(1.0, 2.4);
    return Focus(
      focusNode: _tieuDiem,
      autofocus: true,
      onKeyEvent: _phim,
      child: KhungLopHoc(
        manChieu: true,
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Stack(children: [
            Column(children: [
              DaiKetNoi(kn: _kn),
              Expanded(child: NoiDungGiaoVien(kn: _kn, co: co)),
            ]),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                  tooltip: 'Toàn màn hình',
                  icon: const Icon(Icons.fullscreen_rounded),
                  onPressed: () async {
                    final duoc = await doiToanManHinh();
                    if (!duoc && context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('Thầy cô bấm F11 để mở toàn màn hình.')));
                  }),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: 'Thoát màn chiếu',
                onPressed: () => Navigator.of(context).maybePop(),
                icon:
                    const Icon(Icons.close_rounded, color: AppColors.inkMuted),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Bước kế tiếp giáo viên hay bấm ở pha hiện tại: (lệnh, nhãn nút). null = không còn bước.
(String, String)? lenhTiepTheo(KetNoiTrucTiep kn) {
  final t = kn.trangThai;
  if (t == null) return null;
  final cuoi = (kn.cauSo ?? 0) + 1 >= ((t['tong_cau'] as num?)?.toInt() ?? 0);
  return switch (kn.pha) {
    'cho' =>
      ((t['so_hoc_sinh'] as num?) ?? 0) > 0 ? ('bat_dau', 'Bắt đầu') : null,
    'dang_hoi' => ('ket_thuc_cau', 'Kết thúc câu'),
    'lo_dap_an' => ('cau_tiep', cuoi ? 'Xem xếp hạng chung cuộc' : 'Câu tiếp'),
    _ => null,
  };
}
