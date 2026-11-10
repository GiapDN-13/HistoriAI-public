import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../bang_vang.dart';
import '../giao_dien/san_choi.dart';
import '../lop_hoc_api.dart';
import 'ket_noi_truc_tiep.dart';
import 'widget_truc_tiep.dart';

/// Máy HỌC SINH trong phòng thi trực tiếp: sảnh chờ → câu hỏi (đồng hồ chung cả lớp) →
/// đúng/sai + điểm + hạng sau mỗi câu → hạng chung cuộc.
///
/// Màn này không tự chuyển câu: mọi thứ theo gói trạng thái máy chủ đẩy xuống (xem
/// KetNoiTrucTiep). Tắt trang rồi vào lại bằng tên + PIN là về đúng câu đang hỏi.
class ThiTrucTiepScreen extends StatefulWidget {
  const ThiTrucTiepScreen(
      {super.key,
      required this.ma,
      required this.tieuDe,
      this.ketNoi,
      this.api});

  final String ma;
  final String tieuDe;

  /// Truyền sẵn (test) — không thì màn tự tạo và tự đóng.
  final KetNoiTrucTiep? ketNoi;
  final LopHocApi? api;

  @override
  State<ThiTrucTiepScreen> createState() => _ThiTrucTiepScreenState();
}

class _ThiTrucTiepScreenState extends State<ThiTrucTiepScreen> {
  late final LopHocApi _api = widget.api ?? LopHocApi();
  late final KetNoiTrucTiep _kn =
      widget.ketNoi ?? KetNoiTrucTiep(ma: widget.ma, api: _api);
  Map<String, dynamic>? _xemLai;
  bool _dangTaiXemLai = false;

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
    super.dispose();
  }

  void _doi() {
    if (mounted) setState(() {});
  }

  Future<void> _taiXemLai() async {
    setState(() => _dangTaiXemLai = true);
    try {
      final kq = await _api.nop(
          widget.ma); // hết trận: máy chủ đã nộp sẵn, gọi lại chỉ để xem đáp án
      if (mounted) setState(() => _xemLai = kq);
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _dangTaiXemLai = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KhungLopHoc(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: Text(widget.tieuDe, overflow: TextOverflow.ellipsis),
      ),
      body: Column(children: [
        DaiKetNoi(kn: _kn),
        Expanded(child: _than()),
      ]),
    );
  }

  Widget _than() {
    if (_kn.loiChet != null) {
      return _Giua(children: [
        Text(_kn.loiChet!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 16)),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Quay lại')),
      ]);
    }
    final t = _kn.trangThai;
    if (t == null)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.red));
    final toi = (t['cua_toi'] as Map?)?.cast<String, dynamic>() ?? const {};
    switch (_kn.pha) {
      case 'cho':
        return _Giua(children: [
          const Icon(Icons.hourglass_top_rounded,
              size: 54, color: AppColors.goldDark),
          const SizedBox(height: 12),
          Text('Chào ${toi['ten'] ?? 'em'}!',
              style: const TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontWeight: FontWeight.w700,
                fontSize: 26,
              )),
          const SizedBox(height: 8),
          const Text('Em đã vào phòng. Chờ thầy cô bắt đầu nhé.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.inkSoft,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text(
              '${t['so_hoc_sinh']} bạn trong phòng · ${t['tong_cau']} câu · ${t['giay_moi_cau']} giây mỗi câu',
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.inkMuted)),
        ]);
      case 'dang_hoi':
        return _cauHoi(t, toi);
      case 'lo_dap_an':
        return _loDapAn(t, toi);
      case 'ket_thuc':
        return _ketThuc(t, toi);
    }
    return const SizedBox.shrink();
  }

  Widget _dauCau(Map<String, dynamic> t) => Row(children: [
        Text('Câu ${(_kn.cauSo ?? 0) + 1}/${t['tong_cau']}',
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft)),
        const Spacer(),
        if (_kn.pha == 'dang_hoi')
          DemNguoc(
              hanLuc: _kn.hanLuc,
              tongGiay: (t['giay_moi_cau'] as num?)?.toInt() ?? 30),
      ]);

  Widget _cauHoi(Map<String, dynamic> t, Map<String, dynamic> toi) {
    final cau = (t['cau'] as Map).cast<String, dynamic>();
    final chon = _kn.daChon(_kn.cauSo);
    return KhungCauHoi(
      dau: _dauCau(t),
      cauHoi: '${cau['question']}',
      dapAn: (caoO) => LuoiDapAn(
        caoO: caoO,
        options: (cau['options'] as Map).cast<String, dynamic>(),
        daChon: chon,
        onChon: chon == null ? (k) => _kn.traLoi(_kn.cauSo!, k) : null,
      ),
      phanHoi: _kn.thongBao != null
          ? Text(_kn.thongBao!,
              textAlign: TextAlign.center, style: AppTypography.bodySmall)
          : chon == null
              ? null
              : Text('Em đã chọn $chon. Chờ thầy cô công bố đáp án…',
                  textAlign: TextAlign.center, style: AppTypography.bodySmall),
    );
  }

  Widget _loDapAn(Map<String, dynamic> t, Map<String, dynamic> toi) {
    final cau = (t['cau'] as Map?)?.cast<String, dynamic>();
    final dung = toi['dung'] == true;
    final boTrong = toi['da_chon'] == null;
    return ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: dung
                  ? AppColors.success
                  : (boTrong ? AppColors.inkMuted : AppColors.red),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              Text(
                  dung
                      ? 'Chính xác!'
                      : (boTrong ? 'Chưa kịp trả lời' : 'Chưa đúng'),
                  style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontWeight: FontWeight.w700,
                      fontSize: 26,
                      color: Colors.white)),
              const SizedBox(height: 4),
              NhipSanChoi(
                  key: ValueKey('${_kn.cauSo}:${toi['diem_cau']}'),
                  diemBay: true,
                  child: Text(
                      dung ? '+${chuDuLieu(toi['diem_cau'])} điểm' : '+0 điểm',
                      style: AppTypography.labelMedium
                          .copyWith(color: Colors.white, fontSize: 22))),
              const SizedBox(height: 6),
              Text(
                  'Tổng ${chuDuLieu(toi['tong_diem'])} điểm'
                  '${nenKhoeHang(toi, t['so_hoc_sinh'] as num?) ? ' · hạng ${toi['hang']}/${t['so_hoc_sinh']}' : ''}',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: .9),
                      fontSize: 15)),
            ]),
          ),
          const SizedBox(height: 16),
          _dauCau(t),
          if (cau != null) ...[
            const SizedBox(height: 8),
            Text('${cau['question']}',
                style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            const SizedBox(height: 10),
            LuoiDapAn(
              options: (cau['options'] as Map).cast<String, dynamic>(),
              daChon: toi['da_chon'] as String?,
              dapAn: t['dap_an'] as String?,
            ),
          ],
          if ((t['giai_thich'] ?? '').toString().isNotEmpty)
            Text('${t['giai_thich']}',
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    color: AppColors.inkSoft,
                    height: 1.4)),
          const SizedBox(height: 16),
          const Text('TOP 5',
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: AppColors.inkSoft)),
          const SizedBox(height: 6),
          BangTop(
              top: (t['top'] as List?) ?? const [], toi: toi['ten'] as String?),
        ]);
  }

  Future<void> _moGiayVinhDanh() async {
    final tin = ScaffoldMessenger.of(context);
    try {
      final d = await _api.bangVang(widget.ma);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GiayVinhDanhScreen(du: d), fullscreenDialog: true));
    } catch (_) {
      tin.showSnackBar(const SnackBar(
          content:
              Text('Chưa tải được giấy vinh danh — thử lại sau giây lát.')));
    }
  }

  Widget _ketThuc(Map<String, dynamic> t, Map<String, dynamic> toi) {
    final xem = _xemLai;
    return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: imperialDarkGradient,
                borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              const Text('KẾT THÚC',
                  style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      color: AppColors.goldBright,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text(
                  nenKhoeHang(toi, t['so_hoc_sinh'] as num?)
                      ? 'Hạng ${toi['hang']}/${t['so_hoc_sinh']}'
                      : 'Em đã hoàn thành!',
                  style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                      color: AppColors.onRed)),
              const SizedBox(height: 4),
              Text(
                  '${toi['tong_diem'] ?? 0} điểm · đúng ${toi['so_dung'] ?? 0}/${t['tong_cau']} câu',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      color: AppColors.onRed.withValues(alpha: .9),
                      fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                  'Kết quả đã gửi cho thầy cô. Câu sai đã vào mục "Ôn câu sai" trong Hồ sơ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      color: AppColors.onRed.withValues(alpha: .8),
                      fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 16),
          BucVinhDanh(bang: (t['top'] as List?) ?? const []),
          const SizedBox(height: 16),
          BangVangPhong(ma: widget.ma, api: _api, coNutGiay: false),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.decorativeOrange),
            onPressed: _moGiayVinhDanh,
            icon: const Icon(Icons.workspace_premium_rounded,
                color: AppColors.goldBright),
            label: const Text('Nhận giấy vinh danh của em'),
          ),
          const SizedBox(height: 12),
          if (xem == null)
            OutlinedButton.icon(
              onPressed: _dangTaiXemLai ? null : _taiXemLai,
              icon: const Icon(Icons.fact_check_rounded),
              label: Text(
                  _dangTaiXemLai ? 'Đang tải…' : 'Xem lại đáp án từng câu'),
            )
          else
            for (final c in (xem['cau'] as List).cast<Map>())
              _XemLai(c: c.cast<String, dynamic>()),
        ]);
  }
}

class _Giua extends StatelessWidget {
  const _Giua({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
              child:
                  Column(mainAxisSize: MainAxisSize.min, children: children)),
        ),
      );
}

class _XemLai extends StatelessWidget {
  const _XemLai({required this.c});

  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    final pa = (c['options'] as Map).cast<String, dynamic>();
    final dung = c['dung'] == true;
    final chon = '${c['chon'] ?? ''}';
    final dapAn = '${c['correct_option']}';
    final mau = dung ? AppColors.success : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mau.withValues(alpha: .35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${c['question']}',
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: AppColors.ink)),
        const SizedBox(height: 6),
        Text(
            'Em chọn: ${chon.isEmpty ? '(không trả lời)' : '$chon. ${pa[chon]}'}',
            style: TextStyle(
                fontFamily: 'Inter', fontWeight: FontWeight.w400, color: mau)),
        if (!dung)
          Text('Đáp án: $dapAn. ${pa[dapAn]}',
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.success)),
        if ((c['explanation'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${c['explanation']}',
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.inkSoft,
                  fontSize: 13,
                  height: 1.4)),
        ],
      ]),
    );
  }
}
