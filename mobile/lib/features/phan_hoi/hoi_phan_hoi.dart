import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analytics.dart';
import '../../core/api_client.dart';
import '../../core/nguon_truy_cap.dart';
import '../../core/theme.dart';

/// Khi nào được TỰ hỏi phản hồi.
///
/// Hỏi dồn là cách nhanh nhất để người dùng ghét app và bấm bừa cho xong —
/// số liệu thu về vô nghĩa. Nên:
///   • mỗi máy tự hỏi tối đa 3 ngày một lần (sau quiz: 1 ngày), và mỗi phiên một lần;
///   • bấm "Để sau" 3 lần thì thôi hẳn — người đó đã nói rõ là không muốn;
///   • câu "có giới thiệu cho bạn bè không" (NPS) chỉ hỏi 30 ngày một lần.
/// Ai muốn góp ý lúc nào cũng được, qua mục trong Hồ sơ.
class LichHoiPhanHoi {
  static const cachNgay = Duration(days: 3);
  /// Sau quiz hỏi dày hơn (21/10): bảng mới hiện 51 lần, 24 lần gửi, 10 người chấm NPS
  /// — quá ít để đọc ra điều gì. Vừa làm xong một lượt quiz là lúc người dùng có ý kiến
  /// rõ nhất về nội dung. Luật "mỗi phiên một lần" và "Để sau 3 lần là thôi" vẫn giữ,
  /// nên ai không thích bị hỏi thì vẫn tự tắt được.
  static const cachNgaySauQuiz = Duration(days: 1);
  static const npsCachNgay = Duration(days: 30);
  static const boQuaToiDa = 3;

  static Duration khoangCachCho(String nguCanh) =>
      nguCanh == 'quiz' ? cachNgaySauQuiz : cachNgay;

  static const _kLanCuoi = 'phan_hoi_lan_cuoi';
  static const _kBoQua = 'phan_hoi_so_lan_bo_qua';
  static const _kNps = 'phan_hoi_nps_lan_cuoi';

  static bool _daHoiPhienNay = false;

  /// Hàm thuần để test: có nên tự hỏi không. [khoangCach] lấy từ [khoangCachCho].
  static bool nenHoi({required DateTime bayGio, DateTime? lanCuoi, int boQua = 0,
      bool daHoiPhienNay = false, Duration khoangCach = cachNgay}) {
    if (daHoiPhienNay || boQua >= boQuaToiDa) return false;
    return lanCuoi == null || bayGio.difference(lanCuoi) >= khoangCach;
  }

  static bool nenHoiNps({required DateTime bayGio, DateTime? lanCuoi}) =>
      lanCuoi == null || bayGio.difference(lanCuoi) >= npsCachNgay;

  static Future<bool> coTheTuHoi({String nguCanh = 'khac'}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final ms = p.getInt(_kLanCuoi);
      return nenHoi(
        bayGio: DateTime.now(),
        lanCuoi: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
        boQua: p.getInt(_kBoQua) ?? 0,
        daHoiPhienNay: _daHoiPhienNay,
        khoangCach: khoangCachCho(nguCanh),
      );
    } catch (_) {
      return !_daHoiPhienNay;
    }
  }

  static Future<bool> coHoiNps() async {
    try {
      final ms = (await SharedPreferences.getInstance()).getInt(_kNps);
      return nenHoiNps(bayGio: DateTime.now(),
          lanCuoi: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms));
    } catch (_) {
      return true;
    }
  }

  static Future<void> ghiDaHoi({required bool boQua, required bool daChamNps}) async {
    _daHoiPhienNay = true;
    try {
      final p = await SharedPreferences.getInstance();
      final bayGio = DateTime.now().millisecondsSinceEpoch;
      await p.setInt(_kLanCuoi, bayGio);
      if (daChamNps) await p.setInt(_kNps, bayGio);
      await p.setInt(_kBoQua, boQua ? (p.getInt(_kBoQua) ?? 0) + 1 : 0);
    } catch (_) {}
  }
}

/// Mở bảng hỏi phản hồi. [tuDong] = app tự hỏi (tôn trọng lịch hỏi);
/// false = người dùng tự bấm "Góp ý" (luôn mở).
Future<void> hoiPhanHoi(BuildContext context,
    {required String nguCanh, String? target, bool tuDong = true}) async {
  if (tuDong && !await LichHoiPhanHoi.coTheTuHoi(nguCanh: nguCanh)) return;
  final coNps = await LichHoiPhanHoi.coHoiNps();
  if (!context.mounted) return;
  Analytics.instance.log('phan_hoi_hien', target: target, them: {'ngu_canh': nguCanh});
  final daGui = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => BangPhanHoi(nguCanh: nguCanh, target: target, hoiNps: coNps),
  );
  if (daGui != true) {
    Analytics.instance.log('phan_hoi_bo_qua', target: target, them: {'ngu_canh': nguCanh});
  }
  await LichHoiPhanHoi.ghiDaHoi(boQua: daGui != true, daChamNps: daGui == true && coNps);
}

/// Chip cho câu "Bạn muốn app có thêm trận/chủ đề nào?" (slug → nhãn).
///
/// Góp ý lặp nhiều nhất là "nội dung còn ít, muốn thêm sự kiện", nhưng chữ tự gõ
/// không cho biết người dùng muốn trận NÀO — chip thì đếm thẳng được. Danh sách chỉ
/// nằm ở đây: máy chủ nhận mọi slug đã làm sạch, thêm/bớt chip không phải sửa máy
/// chủ. Toàn là trận app chưa có; làm xong trận nào thì gỡ khỏi đây.
const tranMuonThem = <String, String>{
  'hai-ba-trung-40': 'Khởi nghĩa Hai Bà Trưng (40)',
  'nhu-nguyet-1077': 'Lý Thường Kiệt – sông Như Nguyệt (1077)',
  'chong-mong-co-1258': 'Chống quân Mông Cổ lần 1 (1258)',
  'rach-gam-xoai-mut-1785': 'Rạch Gầm – Xoài Mút (1785)',
  'dien-bien-phu-1954': 'Điện Biên Phủ (1954)',
  'chien-dich-ho-chi-minh-1975': 'Chiến dịch Hồ Chí Minh (1975)',
  'van-lang-au-lac': 'Văn Lang – Âu Lạc',
};

/// Chọn tối đa 3: buộc người dùng chọn cái họ muốn NHẤT, không tích hết cho xong.
const muonThemToiDa = 3;

class BangPhanHoi extends StatefulWidget {
  const BangPhanHoi({super.key, required this.nguCanh, this.target, this.hoiNps = true,
      this.gui});

  final String nguCanh;
  final String? target;
  final bool hoiNps;

  /// Tiêm để test; mặc định gửi lên /phan-hoi.
  final Future<void> Function(Map<String, dynamic> body)? gui;

  @override
  State<BangPhanHoi> createState() => _BangPhanHoiState();
}

class _BangPhanHoiState extends State<BangPhanHoi> {
  int? _sao;
  int? _nps;
  final _gopY = TextEditingController();
  final _muonThem = <String>{};   // giữ thứ tự bấm
  bool _dangGui = false;
  String? _loi;

  /// Chỉ hỏi sau quiz (vừa hết một trận, dễ nghĩ tới "còn trận nào nữa") và ở Hồ sơ
  /// (người tự bấm góp ý, có thời gian). Đang chat dở thì bảng cần ngắn.
  bool get _hoiMuonThem => widget.nguCanh == 'quiz' || widget.nguCanh == 'ho-so';

  bool get _coGiDeGui => _sao != null || _nps != null || _gopY.text.trim().isNotEmpty ||
      _muonThem.isNotEmpty;

  @override
  void dispose() {
    _gopY.dispose();
    super.dispose();
  }

  Future<void> _guiDi() async {
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    final nguon = await NguonTruyCap.dauTienDaNho();
    final body = <String, dynamic>{
      if (_sao != null) 'diem': _sao,
      if (_nps != null) 'nps': _nps,
      if (_gopY.text.trim().isNotEmpty) 'gop_y': _gopY.text.trim(),
      if (_muonThem.isNotEmpty) 'muon_them': _muonThem.toList(),
      'ngu_canh': widget.nguCanh,
      if (widget.target != null) 'target': widget.target,
      if (nguon != null) ...nguon.thanhParams(),
      'nen_tang': Theme.of(context).platform == TargetPlatform.android ? 'android' : 'web',
    };
    try {
      await (widget.gui ?? (b) => ApiClient().post('/phan-hoi', b))(body);
      Analytics.instance.log('phan_hoi_gui', target: widget.target, value: _sao,
          them: {'ngu_canh': widget.nguCanh, if (_nps != null) 'nps': _nps});
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Chưa gửi được, bạn thử lại nhé.');
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chu = TextStyle(fontFamily: 'Inter', color: AppColors.ink, fontSize: 14);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            const Text('Bạn thấy phần này thế nào?',
                style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 19,
                    fontWeight: FontWeight.w700, color: AppColors.red)),
            const SizedBox(height: 4),
            Text('Góp ý của bạn giúp nhóm làm app tốt hơn. Mất chưa tới 10 giây.',
                style: chu.copyWith(color: AppColors.inkSoft, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    key: ValueKey('sao-$i'),
                    tooltip: '$i sao',
                    iconSize: 36,
                    onPressed: () => setState(() => _sao = i),
                    icon: Icon(
                      (_sao ?? 0) >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: AppColors.gold,
                    ),
                  ),
              ],
            ),
            if (widget.hoiNps) ...[
              const SizedBox(height: 8),
              Text('Bạn có muốn giới thiệu HistoriAI cho bạn bè không?', style: chu),
              const SizedBox(height: 2),
              Text('0 = chắc chắn không · 10 = chắc chắn có',
                  style: chu.copyWith(color: AppColors.inkSoft, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var d = 0; d <= 10; d++)
                    InkWell(
                      key: ValueKey('nps-$d'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _nps = d),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _nps == d ? AppColors.red : AppColors.bgAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _nps == d ? AppColors.red : AppColors.border),
                        ),
                        child: Text('$d',
                            style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700,
                                color: _nps == d ? AppColors.goldBright : AppColors.inkSoft)),
                      ),
                    ),
                ],
              ),
            ],
            if (_hoiMuonThem) ...[
              const SizedBox(height: 12),
              Text('Bạn muốn app có thêm trận/chủ đề nào?', style: chu),
              const SizedBox(height: 2),
              Text('Chọn tối đa $muonThemToiDa',
                  style: chu.copyWith(color: AppColors.inkSoft, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in tranMuonThem.entries)
                    FilterChip(
                      key: ValueKey('muon-them-${e.key}'),
                      label: Text(e.value),
                      selected: _muonThem.contains(e.key),
                      // Đủ 3 thì khoá các chip còn lại; bỏ bớt một chip mới chọn được chip khác.
                      onSelected: !_muonThem.contains(e.key) && _muonThem.length >= muonThemToiDa
                          ? null
                          : (chon) => setState(() {
                                if (chon) {
                                  _muonThem.add(e.key);
                                } else {
                                  _muonThem.remove(e.key);
                                }
                              }),
                      backgroundColor: AppColors.bgAlt,
                      selectedColor: AppColors.red,
                      checkmarkColor: AppColors.goldBright,
                      side: BorderSide(
                          color: _muonThem.contains(e.key) ? AppColors.red : AppColors.border),
                      labelStyle: TextStyle(fontFamily: 'Inter', fontSize: 13,
                          color: _muonThem.contains(e.key) ? AppColors.goldBright : AppColors.ink),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('gop-y'),
              controller: _gopY,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Góp ý thêm (không bắt buộc) — đừng ghi tên, số điện thoại',
                border: OutlineInputBorder(),
              ),
            ),
            if (_loi != null) ...[
              const SizedBox(height: 6),
              Text(_loi!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _dangGui ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Để sau'),
                ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('gui-phan-hoi'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                  onPressed: _coGiDeGui && !_dangGui ? _guiDi : null,
                  child: Text(_dangGui ? 'Đang gửi…' : 'Gửi góp ý'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
