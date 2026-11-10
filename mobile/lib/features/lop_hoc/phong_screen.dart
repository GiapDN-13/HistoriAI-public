import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'lop_hoc_api.dart';
import 'giao_dien/san_choi.dart';
import 'truc_tiep/widget_truc_tiep.dart';
import 'tai_tep_stub.dart' if (dart.library.js_interop) 'tai_tep_web.dart';

/// Màn của giáo viên cho MỘT phòng: mã + QR để chiếu lên máy chiếu, bảng theo dõi tự
/// làm mới 3 giây/lần khi phòng còn mở, đóng phòng, xuất bảng điểm.
///
/// Làm mới bằng hỏi lại định kỳ (không WebSocket): đủ cho chế độ bài tập, và chạy chắc
/// qua Cloudflare. Chế độ trực tiếp (giai đoạn 2) mới cần WebSocket.
class PhongScreen extends StatefulWidget {
  const PhongScreen({super.key, required this.ma, this.api});

  final String ma;
  final LopHocApi? api;

  @override
  State<PhongScreen> createState() => _PhongScreenState();
}

class _PhongScreenState extends State<PhongScreen> {
  late final LopHocApi _api = widget.api ?? LopHocApi();
  Map<String, dynamic>? _bang;
  Timer? _hen;
  String? _loi;
  bool _xemCau = false;

  @override
  void initState() {
    super.initState();
    _tai();
    _hen = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_bang?['phong']?['dang_mo'] == true) _tai();
    });
  }

  @override
  void dispose() {
    _hen?.cancel();
    super.dispose();
  }

  Future<void> _tai() async {
    try {
      final b = await _api.bang(widget.ma);
      if (mounted)
        setState(() {
          _bang = b;
          _loi = null;
        });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Mất kết nối — đang thử lại…');
    }
  }

  Future<void> _dong() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Đóng phòng?'),
        content: const Text(
            'Học sinh sẽ không vào mới và không trả lời thêm được nữa. '
            'Bài đang làm dở vẫn được chấm theo phần đã làm.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đóng phòng')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.dongPhong(widget.ma);
      await _tai();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _xuat() async {
    try {
      // Excel thật (.xlsx, 3 trang). Bản cài chưa lưu tệp được → chép bảng điểm dạng chữ.
      var daTai = await taiExcel('bang-diem-${widget.ma}.xlsx', await _api.excel(widget.ma));
      if (!daTai) daTai = await taiTep('phong-${widget.ma}.csv', await _api.csv(widget.ma));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(daTai
            ? 'Đã tải bảng điểm Excel: 3 trang Bảng điểm · Từng câu · Chi tiết.'
            : 'Đã chép bảng điểm — dán vào Excel hoặc Google Sheets.'),
      ));
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _bang;
    final p = (b?['phong'] as Map?)?.cast<String, dynamic>();
    return KhungLopHoc(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: Text(p == null ? 'PHÒNG ${widget.ma}' : '${p['tieu_de']}',
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              tooltip: 'Xuất bảng điểm',
              onPressed: b == null ? null : _xuat,
              icon: const Icon(Icons.download_rounded)),
        ],
      ),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                  onPressed: b == null ? null : _xuat,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Xuất bảng điểm')))),
      body: b == null
          ? Center(
              child: _loi != null
                  ? Text(_loi!)
                  : const CircularProgressIndicator(color: AppColors.red))
          : RefreshIndicator(
              onRefresh: _tai,
              color: AppColors.red,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _MaPhong(
                      phong: p!, onDong: p['dang_mo'] == true ? _dong : null),
                  if (_loi != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_loi!,
                          style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              color: AppColors.danger)),
                    ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: false,
                          label: Text('Học sinh'),
                          icon: Icon(Icons.people_alt_rounded)),
                      ButtonSegment(
                          value: true,
                          label: Text('Từng câu'),
                          icon: Icon(Icons.bar_chart_rounded)),
                    ],
                    selected: {_xemCau},
                    onSelectionChanged: (s) =>
                        setState(() => _xemCau = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (!_xemCau) ..._hocSinh(b) else ..._tungCau(b),
                ],
              ),
            ),
    );
  }

  List<Widget> _hocSinh(Map<String, dynamic> b) {
    final ds = (b['hoc_sinh'] as List).cast<Map<String, dynamic>>();
    if (ds.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
              'Chưa có em nào vào phòng. Chiếu mã QR lên để các em quét.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.inkSoft)),
        ),
      ];
    }
    return [
      for (final (i, h) in ds.indexed)
        Card(
          color: AppColors.card,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border)),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor:
                  h['da_nop'] == true ? AppColors.success : AppColors.bgAlt,
              child: Text('${i + 1}',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color:
                          h['da_nop'] == true ? Colors.white : AppColors.ink)),
            ),
            title: Text(
                '${h['ten']}${(h['lop'] ?? '').toString().isNotEmpty ? ' · ${h['lop']}' : ''}',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                )),
            subtitle: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (h['tong'] as num) == 0
                    ? 0
                    : (h['da_lam'] as num) / (h['tong'] as num),
                minHeight: 5,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(
                    h['da_nop'] == true ? AppColors.success : AppColors.cta),
              ),
            ),
            trailing: Text(
              h['da_nop'] == true
                  ? '${h['so_dung']}/${h['tong']}'
                  : (h['da_lam'] == h['tong']
                      ? 'Xong · chưa nộp'
                      : '${h['da_lam']}/${h['tong']} câu'),
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  color:
                      h['da_nop'] == true ? AppColors.ink : AppColors.inkSoft),
            ),
          ),
        ),
    ];
  }

  List<Widget> _tungCau(Map<String, dynamic> b) {
    final ds = (b['tung_cau'] as List).cast<Map<String, dynamic>>();
    // Câu sai nhiều lên đầu — thứ giáo viên cần giảng lại
    final xep = [...ds]..sort((a, c) => ((a['ti_le_dung'] ?? 101) as num)
        .compareTo((c['ti_le_dung'] ?? 101) as num));
    return [
      for (final c in xep)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${c['question']}',
                style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(
              c['ti_le_dung'] == null
                  ? 'Chưa em nào trả lời'
                  : '${c['ti_le_dung']}% đúng · ${c['so_tra_loi']} em đã trả lời'
                      '${c['nham_nhieu_nhat'] != null ? ' · hay nhầm sang ${c['nham_nhieu_nhat']}' : ''}',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: (c['ti_le_dung'] ?? 100) < 50
                      ? AppColors.danger
                      : AppColors.inkSoft,
                  fontSize: 13),
            ),
            const SizedBox(height: 6),
            for (final k in const ['A', 'B', 'C', 'D']) _thanh(c, k),
          ]),
        ),
    ];
  }

  Widget _thanh(Map<String, dynamic> c, String k) {
    final so = ((c['phan_bo'] as Map)[k] as num?)?.toInt() ?? 0;
    final tong = (c['so_tra_loi'] as num?)?.toInt() ?? 0;
    final dung = c['correct_option'] == k;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(children: [
        SizedBox(
            width: 28, child: Icon(hinhDapAn[k], size: 20, color: mauDapAn[k])),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: tong == 0 ? 0 : so / tong,
              minHeight: 12,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(mauDapAn[k]!),
            ),
          ),
        ),
        SizedBox(
            width: 30,
            child: Text(' $so',
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12))),
        if (dung)
          const Icon(Icons.check_rounded, size: 20, color: AppColors.success)
        else
          const SizedBox(width: 20),
      ]),
    );
  }
}

class _MaPhong extends StatelessWidget {
  const _MaPhong({required this.phong, this.onDong});

  final Map<String, dynamic> phong;
  final VoidCallback? onDong;

  @override
  Widget build(BuildContext context) {
    final mo = phong['dang_mo'] == true;
    final link = '${phong['link'] ?? ''}';
    final thongTin = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(mo ? 'Mời các em vào phòng' : 'Phòng đã đóng',
          style: AppTypography.headingSmall),
      const SizedBox(height: 4),
      FittedBox(
          child: SelectableText('${phong['ma']}',
              style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  fontSize: 44,
                  letterSpacing: 8,
                  color: AppColors.red))),
      Text(
          '${chuDuLieu(phong['so_nop'])}/${chuDuLieu(phong['so_bai'])} em đã nộp · ${chuDuLieu(phong['so_cau'])} câu',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium),
      const SizedBox(height: 10),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã chép link phòng')));
                },
                icon: const Icon(Icons.link_rounded),
                label: const Text('Chép link')),
            if (onDong != null)
              OutlinedButton.icon(
                  onPressed: onDong,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.redDark),
                  icon: const Icon(Icons.lock_rounded),
                  label: const Text('Đóng phòng')),
          ]),
    ]);
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: AppColors.gold.withValues(alpha: .7), width: 1.5)),
        child: LayoutBuilder(builder: (context, rang) {
          final qr = QrImageView(
              data: link,
              size: rang.maxWidth >= 600 ? 160 : 180,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(10));
          if (rang.maxWidth >= 600 && mo) {
            return Row(children: [
              qr,
              const SizedBox(width: 24),
              Expanded(child: thongTin)
            ]);
          }
          return Column(children: [if (mo) qr, thongTin]);
        }));
  }
}
