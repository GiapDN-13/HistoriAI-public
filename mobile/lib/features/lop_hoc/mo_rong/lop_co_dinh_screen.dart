import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../lop_hoc_api.dart';
import '../giao_dien/san_choi.dart';
import 'thong_ke_lop_screen.dart';

/// Kết quả hộp chọn lớp khi mở phòng: [huy] = giáo viên bấm ra ngoài (không mở phòng).
class ChonLop {
  const ChonLop._(this.lopId, this.huy);
  const ChonLop.lop(int? id) : this._(id, false);
  static const huyBo = ChonLop._(null, true);

  final int? lopId;
  final bool huy;
}

/// Hỏi mở phòng cho lớp nào. Chưa có lớp nào thì khỏi hỏi (phòng lẻ, như giai đoạn 1).
Future<ChonLop> chonLopChoPhong(BuildContext context, LopHocApi api) async {
  List<Map<String, dynamic>> ds;
  try {
    ds = await api.dsLop();
  } catch (_) {
    return const ChonLop.lop(null); // không tải được lớp: vẫn cho mở phòng lẻ
  }
  if (ds.isEmpty || !context.mounted) return const ChonLop.lop(null);
  final chon = await showDialog<ChonLop>(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: AppColors.card,
      title: const Text('Mở cho lớp nào?'),
      children: [
        for (final l in ds)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ChonLop.lop(l['id'] as int)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('${l['ten']} · ${l['si_so']} em'),
            ),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, const ChonLop.lop(null)),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Không gắn lớp',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    color: AppColors.inkSoft)),
          ),
        ),
      ],
    ),
  );
  return chon ?? ChonLop.huyBo;
}

Future<String?> _hoiTen(BuildContext context,
    {required String tieuDe, required String nhan, String? cu}) async {
  final ctl = TextEditingController(text: cu);
  final ten = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(tieuDe),
      content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(labelText: nhan)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('Lưu')),
      ],
    ),
  );
  ctl.dispose();
  return (ten == null || ten.isEmpty) ? null : ten;
}

/// Danh sách lớp cố định của giáo viên (8A2, 9B…) + sĩ số + số buổi đã kiểm tra.
class DsLopScreen extends StatefulWidget {
  const DsLopScreen({super.key, this.api});

  final LopHocApi? api;

  @override
  State<DsLopScreen> createState() => _DsLopScreenState();
}

class _DsLopScreenState extends State<DsLopScreen> {
  late final LopHocApi _api = widget.api ?? LopHocApi();
  List<Map<String, dynamic>> _lop = [];
  bool _dangTai = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final l = await _api.dsLop();
      if (mounted) {
        setState(() {
          _lop = l;
          _dangTai = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loi = e is ApiException
              ? e.message
              : 'Không kết nối được. Kéo xuống để thử lại.';
          _dangTai = false;
        });
      }
    }
  }

  Future<void> _taoLop() async {
    final ten =
        await _hoiTen(context, tieuDe: 'Tạo lớp', nhan: 'Tên lớp (vd "8A2")');
    if (ten == null) return;
    try {
      await _api.taoLop(ten);
      _tai();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return KhungLopHoc(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: const Text('LỚP CỦA TÔI'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _taoLop,
        backgroundColor: AppColors.decorativeOrange,
        foregroundColor: AppColors.ink,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Tạo lớp'),
      ),
      body: RefreshIndicator(
        onRefresh: _tai,
        color: AppColors.red,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const LoiChaoSanChoi(
                tieuDe: 'Theo lớp qua từng buổi',
                moTa:
                    'Tạo lớp một lần, chọn lớp khi mở phòng để theo dõi tiến bộ của các em.'),
            const SizedBox(height: 16),
            const Text(
              'Mở phòng cho một lớp thì các em vào phòng được ghi vào lớp, và thầy cô xem được '
              'kết quả của lớp qua nhiều buổi.',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.inkSoft,
                  fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_dangTai)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.red)),
              )
            else if (_loi != null)
              Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_loi!, textAlign: TextAlign.center))
            else if (_lop.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Chưa có lớp nào. Bấm "Tạo lớp".',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        color: AppColors.inkSoft)),
              )
            else
              for (final l in _lop)
                Card(
                  color: AppColors.card,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border)),
                  child: ListTile(
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => LopChiTietScreen(
                              api: _api, lopId: l['id'] as int)));
                      _tai();
                    },
                    title: Text('${l['ten']}',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                        )),
                    subtitle: Text(
                        'Sĩ số ${l['si_so']} · ${l['so_buoi']} buổi kiểm tra'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Một lớp: danh sách học sinh (thêm tay / bỏ), lối vào thống kê, đổi tên, xoá lớp.
class LopChiTietScreen extends StatefulWidget {
  const LopChiTietScreen({super.key, required this.api, required this.lopId});

  final LopHocApi api;
  final int lopId;

  @override
  State<LopChiTietScreen> createState() => _LopChiTietScreenState();
}

class _LopChiTietScreenState extends State<LopChiTietScreen> {
  Map<String, dynamic>? _lop;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    try {
      final l = await widget.api.chiTietLop(widget.lopId);
      if (mounted) {
        setState(() {
          _lop = l;
          _loi = null;
        });
      }
    } catch (e) {
      if (mounted)
        setState(
            () => _loi = e is ApiException ? e.message : 'Không kết nối được.');
    }
  }

  Future<void> _lam(Future<void> Function() viec) async {
    try {
      await viec();
      await _tai();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _themEm() async {
    final ten = await _hoiTen(context,
        tieuDe: 'Thêm học sinh',
        nhan: 'Họ tên (đúng như em sẽ gõ khi vào phòng)');
    if (ten != null) _lam(() => widget.api.themThanhVien(widget.lopId, ten));
  }

  Future<void> _doiTen() async {
    final ten = await _hoiTen(context,
        tieuDe: 'Đổi tên lớp', nhan: 'Tên lớp', cu: _lop?['ten'] as String?);
    if (ten != null) _lam(() => widget.api.doiTenLop(widget.lopId, ten));
  }

  Future<void> _xoaLop() async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Xoá lớp ${_lop?['ten'] ?? ''}?'),
        content: const Text(
            'Danh sách lớp bị xoá. Các phòng đã mở và bài làm của học sinh vẫn giữ nguyên '
            '(thành phòng không gắn lớp).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xoá lớp')),
        ],
      ),
    );
    if (dongY != true) return;
    try {
      await widget.api.xoaLop(widget.lopId);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _lop;
    final tv =
        ((l?['thanh_vien'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return KhungLopHoc(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: Text(l == null ? 'LỚP' : 'LỚP ${l['ten']}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'ten' ? _doiTen() : _xoaLop(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'ten', child: Text('Đổi tên lớp')),
              PopupMenuItem(value: 'xoa', child: Text('Xoá lớp')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _themEm,
        backgroundColor: AppColors.decorativeOrange,
        foregroundColor: AppColors.ink,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Thêm em'),
      ),
      body: _loi != null
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24), child: Text(_loi!)))
          : l == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.red))
              : RefreshIndicator(
                  onRefresh: _tai,
                  color: AppColors.red,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      LoiChaoSanChoi(
                          tieuDe: 'Lớp ${l['ten']}',
                          moTa:
                              '${l['si_so']} em · ${l['so_buoi']} buổi kiểm tra'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ThongKeLopScreen(
                                    api: widget.api, lopId: widget.lopId))),
                        icon: const Icon(Icons.insights_rounded),
                        label: Text('Thống kê ${l['so_buoi']} buổi kiểm tra'),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46)),
                      ),
                      const SizedBox(height: 18),
                      Text('HỌC SINH · SĨ SỐ ${l['si_so']}',
                          style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkSoft,
                              fontSize: 12,
                              letterSpacing: .7)),
                      const SizedBox(height: 8),
                      if (tv.isEmpty)
                        const Text(
                            'Chưa có em nào. Mở một phòng cho lớp này — các em vào phòng sẽ tự có tên ở đây.',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                color: AppColors.inkSoft)),
                      for (final t in tv)
                        Card(
                          color: AppColors.card,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppColors.border)),
                          child: ListTile(
                            dense: true,
                            title: Text('${t['ten']}'),
                            subtitle: Text(t['da_vao_phong'] == true
                                ? 'Đã làm ${t['so_buoi_lam']} buổi'
                                : 'Thêm tay · chưa vào phòng nào'),
                            trailing: IconButton(
                              tooltip: 'Bỏ khỏi lớp',
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: () => _lam(() => widget.api
                                  .boThanhVien(widget.lopId, t['id'] as int)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
