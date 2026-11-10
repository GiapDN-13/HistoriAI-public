import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../lop_hoc_api.dart';
import '../giao_dien/san_choi.dart';

/// Thống kê nhiều buổi của một lớp: điểm TB từng buổi, tiến bộ từng em, câu/sự kiện yếu.
///
/// Biểu đồ vẽ bằng thanh ngang tự dựng (Container) — đủ đọc cho giáo viên, không thêm
/// thư viện biểu đồ vào app chỉ vì một màn.
class ThongKeLopScreen extends StatefulWidget {
  const ThongKeLopScreen({super.key, required this.api, required this.lopId});

  final LopHocApi api;
  final int lopId;

  @override
  State<ThongKeLopScreen> createState() => _ThongKeLopScreenState();
}

String ngayNgan(String? iso) {
  final t = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  String h(int x) => x.toString().padLeft(2, '0');
  return '${h(t.day)}/${h(t.month)}';
}

/// 10 → "10", 7.5 → "7.5", 6.25 → "6.25" — đúng như sổ điểm, không làm tròn thêm.
String diemChu(num? d) {
  if (d == null) return '–';
  var s = d.toStringAsFixed(2);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

class _ThongKeLopScreenState extends State<ThongKeLopScreen> {
  Map<String, dynamic>? _tk;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    try {
      final tk = await widget.api.thongKeLop(widget.lopId);
      if (mounted) {
        setState(() {
          _tk = tk;
          _loi = null;
        });
      }
    } catch (e) {
      if (mounted)
        setState(
            () => _loi = e is ApiException ? e.message : 'Không kết nối được.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = _tk;
    return KhungLopHoc(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: Text(
            tk == null ? 'THỐNG KÊ' : 'THỐNG KÊ ${(tk['lop'] as Map)['ten']}'),
      ),
      body: _loi != null
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24), child: Text(_loi!)))
          : tk == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.red))
              : RefreshIndicator(
                  onRefresh: _tai, color: AppColors.red, child: _noiDung(tk)),
    );
  }

  Widget _noiDung(Map<String, dynamic> tk) {
    final buoi = (tk['buoi'] as List).cast<Map<String, dynamic>>();
    final hs = (tk['hoc_sinh'] as List).cast<Map<String, dynamic>>();
    final cauYeu = (tk['cau_yeu'] as List).cast<Map<String, dynamic>>();
    final skYeu = (tk['su_kien_yeu'] as List).cast<Map<String, dynamic>>();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const LoiChaoSanChoi(
            tieuDe: 'Cả lớp tiến bộ ra sao?',
            moTa: 'Xem điểm qua các buổi và những câu cần cùng ôn lại.'),
        const SizedBox(height: 20),
        if (buoi.isEmpty)
          const Text(
              'Lớp chưa có buổi kiểm tra nào. Mở một phòng và chọn lớp này để bắt đầu.',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.inkSoft)),
        if (buoi.isNotEmpty) ...[
          const _Muc('ĐIỂM TRUNG BÌNH TỪNG BUỔI (THANG 10)'),
          for (final b in buoi)
            _Thanh(
              nhan: '${ngayNgan(b['ngay'] as String?)} · ${b['tieu_de']}',
              phu:
                  '${b['so_tinh']}/${b['so_bai']} bài được tính${b['dang_mo'] == true ? ' · đang mở' : ''}',
              tiLe: ((b['diem_tb'] as num?) ?? 0) / 10,
              chu: diemChu(b['diem_tb'] as num?),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
                'Bài được tính: đã nộp, hoặc phòng đã đóng mà em có làm. Em vào phòng mà không '
                'làm câu nào coi như vắng buổi đó.',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    color: AppColors.inkMuted,
                    fontSize: 12)),
          ),
          const SizedBox(height: 22),
          const _Muc('TỪNG EM QUA CÁC BUỔI'),
          for (final h in hs) _DongHocSinh(h: h, soBuoi: buoi.length),
        ],
        if (skYeu.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _Muc('SỰ KIỆN CẢ LỚP LÀM ĐÚNG ÍT NHẤT'),
          for (final s in skYeu)
            _Thanh(
              nhan: '${s['su_kien']}',
              phu: '${s['so_tra_loi']} lượt trả lời',
              tiLe: (s['ti_le_dung'] as num) / 100,
              chu: '${s['ti_le_dung']}%',
            ),
        ],
        if (cauYeu.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _Muc('CÂU CẢ LỚP YẾU NHẤT'),
          for (final c in cauYeu)
            _Thanh(
              nhan: '${c['question']}',
              phu: [
                if (c['su_kien'] != null) '${c['su_kien']}',
                if (c['rieng'] == true) 'câu tự soạn',
                '${c['so_tra_loi']} lượt trả lời',
              ].join(' · '),
              tiLe: (c['ti_le_dung'] as num) / 100,
              chu: '${c['ti_le_dung']}%',
            ),
        ],
      ],
    );
  }
}

class _Muc extends StatelessWidget {
  const _Muc(this.chu);
  final String chu;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(chu,
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
                fontSize: 12,
                letterSpacing: .7)),
      );
}

/// Màu theo mức: dưới 5/10 đỏ, 5–8 vàng đậm, từ 8 xanh — giáo viên liếc là thấy chỗ cần ôn.
Color mauMuc(double tiLe) => tiLe < .5
    ? AppColors.red
    : (tiLe < .8 ? AppColors.goldDark : AppColors.success);

class _Thanh extends StatelessWidget {
  const _Thanh(
      {required this.nhan,
      required this.phu,
      required this.tiLe,
      required this.chu});
  final String nhan, phu, chu;
  final double tiLe;

  @override
  Widget build(BuildContext context) {
    final t = tiLe.clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(nhan,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5))),
          const SizedBox(width: 8),
          Text(chu,
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  color: mauMuc(t))),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(children: [
            Container(height: 10, color: AppColors.divider),
            FractionallySizedBox(
                widthFactor: t, child: Container(height: 10, color: mauMuc(t))),
          ]),
        ),
        const SizedBox(height: 2),
        Text(phu,
            style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                color: AppColors.inkMuted,
                fontSize: 12)),
      ]),
    );
  }
}

/// Một em: các cột nhỏ theo buổi (trống = vắng), điểm TB và thay đổi so với buổi đầu.
class _DongHocSinh extends StatelessWidget {
  const _DongHocSinh({required this.h, required this.soBuoi});
  final Map<String, dynamic> h;
  final int soBuoi;

  @override
  Widget build(BuildContext context) {
    final diem = (h['diem'] as List).cast<num?>();
    final doi = h['thay_doi'] as num?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${h['ten']}',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                )),
            Text(
              h['so_buoi'] == 0
                  ? 'Chưa có bài được tính'
                  : 'TB ${diemChu(h['diem_tb'] as num?)} · ${h['so_buoi']}/$soBuoi buổi',
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.inkMuted,
                  fontSize: 12),
            ),
          ]),
        ),
        SizedBox(
          width: 88,
          height: 30,
          child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final d in diem)
                  Tooltip(
                    message: d == null ? 'Vắng' : '${diemChu(d)}/10',
                    child: Container(
                      width: 8,
                      margin: const EdgeInsets.only(left: 3),
                      height: d == null
                          ? 3
                          : 4 + 26 * (d / 10).clamp(0, 1).toDouble(),
                      color: d == null ? AppColors.divider : mauMuc(d / 10),
                    ),
                  ),
              ])),
        ),
        SizedBox(
          width: 52,
          child: Text(
            doi == null
                ? ''
                : '${doi > 0 ? '▲' : (doi < 0 ? '▼' : '=')} ${diemChu(doi.abs())}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              color: doi == null || doi == 0
                  ? AppColors.inkMuted
                  : (doi > 0 ? AppColors.success : AppColors.red),
            ),
          ),
        ),
      ]),
    );
  }
}
