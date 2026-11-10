import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'lop_hoc_api.dart';
import 'giao_dien/san_choi.dart';
import 'giao_dien/mo_phong.dart';
import 'mo_rong/nhap_nhieu_cau_screen.dart';
import 'mo_rong/cau_rieng_screen.dart';
import 'mo_rong/lop_co_dinh_screen.dart';
import 'phong_screen.dart';
import 'truc_tiep/dieu_khien_screen.dart';

/// Trang chính của giáo viên: các phòng đã mở + các đề đã soạn; soạn đề mới, mở phòng.
class GiaoVienScreen extends StatefulWidget {
  const GiaoVienScreen({super.key, this.api});
  final LopHocApi? api;

  @override
  State<GiaoVienScreen> createState() => _GiaoVienScreenState();
}

class _GiaoVienScreenState extends State<GiaoVienScreen> {
  late final _api = widget.api ?? LopHocApi();
  List<Map<String, dynamic>> _phong = [];
  List<Map<String, dynamic>> _de = [];
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
      final kq = await Future.wait([_api.dsPhong(), _api.dsDe()]);
      if (mounted)
        setState(() {
          _phong = kq[0];
          _de = kq[1];
          _dangTai = false;
        });
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          _loi = e.message;
          _dangTai = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loi = 'Không kết nối được. Kéo xuống để thử lại.';
          _dangTai = false;
        });
    }
  }

  Future<void> _soanDe() async {
    final ok = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => SoanDeScreen(api: _api)));
    if (ok == true) _tai();
  }

  Future<void> _danNhieu() async {
    final so = await Navigator.of(context).push<int>(
        MaterialPageRoute(builder: (_) => NhapNhieuCauScreen(api: _api)));
    if (so == null || !mounted) return;
    // Kho đã gồm câu tự soạn với id âm; đi thẳng tới chọn câu sau khi dán.
    await _soanDe();
    if (mounted) _tai();
  }

  Future<void> _moPhong(Map<String, dynamic> de) async {
    List<Map<String, dynamic>> lop = [];
    try {
      lop = await _api.dsLop();
    } catch (_) {/* Vẫn mở được phòng không gắn lớp. */}
    if (!mounted) return;
    final chon = await showDialog<(String, int?, int?)>(
        context: context,
        builder: (_) => MoPhong(tieuDe: '${de['tieu_de']}', lop: lop));
    if (chon == null || !mounted) return;
    try {
      final p = await _api.moPhong(de['id'] as int,
          hanPhut: chon.$2, cheDo: chon.$1, lopId: chon.$3);
      if (!mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => _manPhong(p)));
      _tai();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Phòng trực tiếp chưa xong trận → màn điều khiển; còn lại → bảng theo dõi giai đoạn 1.
  Widget _manPhong(Map<String, dynamic> p) =>
      p['che_do'] == 'truc_tiep' && p['dang_mo'] == true
          ? DieuKhienTrucTiepScreen(ma: '${p['ma']}')
          : PhongScreen(ma: '${p['ma']}');

  @override
  Widget build(BuildContext context) {
    return KhungLopHoc(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: const Text('LỚP HỌC'),
      ),
      body: RefreshIndicator(
        onRefresh: _tai,
        color: AppColors.red,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const LoiChaoSanChoi(
                tieuDe: 'Một tiết học, cả lớp cùng chơi',
                moTa: 'Chọn đề, mở phòng rồi mời các em thử tài lịch sử.'),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _danNhieu,
                icon: const Icon(Icons.content_paste_rounded),
                label: const Text('Dán nhiều câu từ AI')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: _soanDe,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Soạn đề mới')),
            const SizedBox(height: 24),
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
            else ...[
              // GĐ3: lớp cố định + thống kê nhiều buổi, câu tự soạn (features/lop_hoc/mo_rong/)
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DsLopScreen(api: _api)));
                      _tai();
                    },
                    icon: const Icon(Icons.groups_rounded),
                    label: const Text('Lớp của tôi'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => CauRiengScreen(api: _api))),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Câu tự soạn'),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              const _TieuDe('PHÒNG ĐÃ MỞ'),
              if (_phong.isEmpty)
                const _Trong(
                    'Chưa mở phòng nào. Soạn một đề rồi bấm "Mở phòng".'),
              for (final p in _phong)
                _The(
                  tieuDe: '${p['tieu_de']}',
                  phu:
                      'Mã ${p['ma']} · ${p['so_nop']}/${p['so_bai']} em đã nộp',
                  nhan: p['dang_mo'] == true
                      ? (p['che_do'] == 'truc_tiep' ? 'TRỰC TIẾP' : 'ĐANG MỞ')
                      : 'ĐÃ ĐÓNG',
                  mauNhan: p['dang_mo'] == true
                      ? AppColors.success
                      : AppColors.inkMuted,
                  onTap: () async {
                    await Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => _manPhong(p)));
                    _tai();
                  },
                ),
              const SizedBox(height: 22),
              const _TieuDe('ĐỀ ĐÃ SOẠN'),
              if (_de.isEmpty)
                const _Trong(
                    'Chưa có đề — dán đề AI soạn hoặc chọn câu từ kho.'),
              for (final d in _de)
                _The(
                  tieuDe: '${d['tieu_de']}',
                  phu: '${d['so_cau']} câu · ${d['giay_moi_cau']} giây/câu',
                  nhan: 'MỞ PHÒNG',
                  mauNhan: AppColors.red,
                  onTap: () => _moPhong(d),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TieuDe extends StatelessWidget {
  const _TieuDe(this.chu);
  final String chu;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(chu,
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
                fontSize: 12,
                letterSpacing: .7)),
      );
}

class _Trong extends StatelessWidget {
  const _Trong(this.chu);
  final String chu;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(chu,
            style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                color: AppColors.inkSoft)),
      );
}

class _The extends StatelessWidget {
  const _The(
      {required this.tieuDe,
      required this.phu,
      required this.nhan,
      required this.mauNhan,
      required this.onTap});
  final String tieuDe, phu, nhan;
  final Color mauNhan;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.card,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border)),
        child: ListTile(
          onTap: onTap,
          title: Text(tieuDe,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              )),
          subtitle: Text(phu),
          trailing: Text(nhan,
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  color: mauNhan,
                  fontSize: 12)),
        ),
      );
}

/// Soạn đề: đặt tên, chọn câu theo từng sự kiện trong kho, đặt giây mỗi câu.
class SoanDeScreen extends StatefulWidget {
  const SoanDeScreen({super.key, this.api});
  final LopHocApi? api;

  @override
  State<SoanDeScreen> createState() => _SoanDeScreenState();
}

class _SoanDeScreenState extends State<SoanDeScreen> {
  late final _api = widget.api ?? LopHocApi();
  final _tenCtl = TextEditingController();
  List<Map<String, dynamic>> _kho = [];
  final _chon = <int>{};
  final _moRong = <String>{};
  int _giay = 30;
  bool _dangTai = true;
  bool _dangLuu = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _api.khoCau().then((k) {
      if (mounted)
        setState(() {
          _kho = k;
          _dangTai = false;
        });
    }).catchError((Object e) {
      if (mounted)
        setState(() {
          _loi = e is ApiException ? e.message : 'Không tải được kho câu hỏi.';
          _dangTai = false;
        });
    });
  }

  @override
  void dispose() {
    _tenCtl.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    final ten = _tenCtl.text.trim();
    if (ten.length < 2 || _chon.isEmpty || _chon.length > 60) {
      setState(() => _loi = 'Đặt tên đề và chọn từ 1 đến 60 câu.');
      return;
    }
    // Giữ thứ tự câu như trong kho (theo năm sự kiện) — dễ đoán hơn thứ tự bấm.
    final ids = [
      for (final sk in _kho)
        for (final c in (sk['cau'] as List))
          if (_chon.contains(c['id'])) c['id'] as int
    ];
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      await _api.taoDe(ten, ids, _giay);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KhungLopHoc(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: const Text('SOẠN ĐỀ'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _dangLuu ? null : _luu,
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child:
                Text(_dangLuu ? 'Đang lưu…' : 'Lưu đề (${_chon.length} câu)'),
          ),
        ),
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: AppColors.red))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const Text('Chọn câu cho trận mới', style: AppTypography.headingMedium),
                const SizedBox(height: 6),
                const Text('Chọn từ 1 đến 60 câu. Câu tự soạn nằm trong kho bên dưới.', style: AppTypography.bodyMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: _tenCtl,
                  maxLength: 120,
                  decoration: const InputDecoration(
                      labelText: 'Tên đề (vd "Ôn tập Bạch Đằng — 8A2")',
                      counterText: ''),
                ),
                const SizedBox(height: 12),
                Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      const Text('Thời gian mỗi câu:'),
                      DropdownButton<int>(
                        value: _giay,
                        items: [
                          for (final g in const [15, 20, 30, 45, 60, 90])
                            DropdownMenuItem(value: g, child: Text('$g giây'))
                        ],
                        onChanged: (g) => setState(() => _giay = g ?? 30),
                      ),
                    ]),
                if (_loi != null)
                  Text(_loi!,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          color: AppColors.danger)),
                const SizedBox(height: 8),
                for (final sk in _kho) _nhomSuKien(sk),
              ],
            ),
    );
  }

  Widget _nhomSuKien(Map<String, dynamic> sk) {
    final cau = (sk['cau'] as List).cast<Map<String, dynamic>>();
    final slug = '${sk['event_slug']}';
    final daChon = cau.where((c) => _chon.contains(c['id'])).length;
    final mo = _moRong.contains(slug);
    return Card(
      color: AppColors.card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border)),
      child: Column(children: [
        ListTile(
          title: Text('${sk['event_title']}',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              )),
          subtitle: Text('Đã chọn $daChon/${cau.length} câu'),
          trailing: Icon(mo ? Icons.expand_less : Icons.expand_more),
          onTap: () =>
              setState(() => mo ? _moRong.remove(slug) : _moRong.add(slug)),
        ),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                if (daChon == cau.length) {
                  _chon.removeAll(cau.map((c) => c['id'] as int));
                } else {
                  final them = cau
                      .map((c) => c['id'] as int)
                      .where((id) => !_chon.contains(id));
                  _chon.addAll(them.take(60 - _chon.length));
                }
              }),
              child: Text(daChon == cau.length ? 'Bỏ hết' : 'Chọn hết'),
            )),
        if (mo)
          for (final c in cau)
            CheckboxListTile(
              value: _chon.contains(c['id']),
              onChanged: (v) => setState(() {
                if (v == true && _chon.length < 60) _chon.add(c['id'] as int);
                if (v != true) _chon.remove(c['id']);
              }),
              title: Text('${c['question']}',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 14)),
              subtitle: Text(
                  'Đáp án ${c['correct_option']}. ${(c['options'] as Map)[c['correct_option']]}',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 12.5,
                      color: AppColors.success)),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
      ]),
    );
  }
}
