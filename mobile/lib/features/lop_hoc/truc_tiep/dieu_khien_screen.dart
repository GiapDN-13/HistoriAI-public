import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../phong_screen.dart';
import '../giao_dien/san_choi.dart';
import 'ket_noi_truc_tiep.dart';
import 'man_chieu_screen.dart';
import 'widget_truc_tiep.dart';

/// Màn ĐIỀU KHIỂN của giáo viên cho một phòng thi trực tiếp: xem sảnh, bấm Bắt đầu /
/// Kết thúc câu / Câu tiếp, mở màn chiếu. Nút bước tiếp theo luôn nằm cố định ở đáy màn
/// — giáo viên cầm điện thoại đi giữa lớp vẫn bấm được bằng một tay.
class DieuKhienTrucTiepScreen extends StatefulWidget {
  const DieuKhienTrucTiepScreen({super.key, required this.ma, this.ketNoi});

  final String ma;
  final KetNoiTrucTiep? ketNoi;

  @override
  State<DieuKhienTrucTiepScreen> createState() =>
      _DieuKhienTrucTiepScreenState();
}

class _DieuKhienTrucTiepScreenState extends State<DieuKhienTrucTiepScreen> {
  late final KetNoiTrucTiep _kn =
      widget.ketNoi ?? KetNoiTrucTiep(ma: widget.ma);

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

  Future<void> _ketThucSom() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Kết thúc trận ngay?'),
        content: const Text(
            'Các câu còn lại sẽ bỏ qua. Điểm các em giữ nguyên theo những câu đã làm, '
            'bài được nộp và phòng đóng lại.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kết thúc')),
        ],
      ),
    );
    if (ok == true) await _kn.dieuKhien('ket_thuc');
  }

  @override
  Widget build(BuildContext context) {
    final t = _kn.trangThai;
    final buoc = lenhTiepTheo(_kn);
    final hetTran = _kn.pha == 'ket_thuc';
    return KhungLopHoc(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: Text(t == null ? 'PHÒNG ${widget.ma}' : '${t['tieu_de']}',
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Mở màn chiếu',
            icon: const Icon(Icons.cast_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ManChieuScreen(ma: widget.ma, ketNoi: _kn))),
          ),
          if (t != null && !hetTran)
            PopupMenuButton<String>(
              onSelected: (_) => _ketThucSom(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'ket_thuc', child: Text('Kết thúc trận sớm'))
              ],
            ),
        ],
      ),
      body: Column(children: [
        DaiKetNoi(kn: _kn),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        ManChieuScreen(ma: widget.ma, ketNoi: _kn))),
                icon: const Icon(Icons.cast_rounded),
                label: const Text('Mở màn chiếu cho cả lớp'))),
        Expanded(child: NoiDungGiaoVien(kn: _kn)),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_kn.thongBao != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(_kn.thongBao!,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        color: AppColors.danger)),
              ),
            if (hetTran)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (_) => PhongScreen(ma: widget.ma))),
                icon: const Icon(Icons.table_chart_rounded),
                label: const Text('Bảng điểm từng em · xuất Excel'),
              )
            else
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                onPressed: buoc == null ? null : () => _kn.dieuKhien(buoc.$1),
                child: Text(
                  buoc?.$2 ??
                      (_kn.pha == 'cho' ? 'Chờ học sinh vào phòng…' : '…'),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
