import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../premium/premium_screen.dart';
import '../quiz/quiz_play_screen.dart';

/// Lịch sử học: thống kê, các lượt làm quiz (xem lại từng câu), và "Ôn câu sai".
///
/// Trước 27/09 máy chủ lưu từng câu trả lời nhưng app không có chỗ nào cho xem
/// lại — làm sai là quên luôn, không có đường ôn.
class LichSuHocScreen extends StatefulWidget {
  const LichSuHocScreen({super.key});

  @override
  State<LichSuHocScreen> createState() => _LichSuHocScreenState();
}

class _LichSuHocScreenState extends State<LichSuHocScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _thongKe;
  List<Map<String, dynamic>> _luot = [];
  List<QuizQuestion> _cauSai = [];

  /// Số câu sai máy chủ đã giấu vì bản thường chỉ ôn 5 câu gần nhất (0 với Premium).
  int _cauSaiBiKhoa = 0;
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
      final kq = await Future.wait([
        _api.get('/me/thong-ke'),
        _api.get('/me/lich-su-quiz?limit=30'),
        // limit lớn: bản thường tự bị máy chủ cắt còn 5, Premium nhận hết. `kem_tong`
        // để biết còn bao nhiêu câu bị giấu (không gửi thì máy chủ trả mảng trơn).
        _api.get('/me/cau-sai?limit=100&kem_tong=1'),
      ]);
      if (!mounted) return;
      setState(() {
        _thongKe = (kq[0] as Map).cast<String, dynamic>();
        _luot = (kq[1] as List).cast<Map<String, dynamic>>();
        // Máy chủ cũ (chưa có kem_tong) trả mảng trơn → không có câu nào bị giấu.
        final tho = kq[2];
        final ds = tho is Map ? (tho['cau_hoi'] as List? ?? const []) : tho as List;
        _cauSai = ds
            .map((e) => QuizQuestion.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        _cauSaiBiKhoa = tho is Map ? ((tho['da_cat'] as num?)?.toInt() ?? 0) : 0;
        _dangTai = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _loi = e.message;
        _dangTai = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _loi = 'Không kết nối được. Kéo xuống để thử lại.';
        _dangTai = false;
      });
    }
  }

  Future<void> _onCauSai() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPlayScreen(
          eventSlug: 'on-cau-sai',
          eventTitle: 'Ôn câu sai',
          cauHoiSan: _cauSai,
        ),
      ),
    );
    if (mounted) _tai();
  }

  /// Quay lại từ màn Premium là nạp lại: người học có thể vừa mua, khi đó các câu bị
  /// giấu phải hiện ra ngay.
  Future<void> _xemPremium() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
    );
    if (mounted) _tai();
  }

  Future<void> _xemLuot(Map<String, dynamic> l) async {
    List<Map<String, dynamic>>? cau;
    String? loi;
    try {
      cau = (await _api.get('/me/lich-su-quiz/${l['ma']}') as List)
          .cast<Map<String, dynamic>>();
    } on ApiException catch (e) {
      loi = e.message;
    } catch (_) {
      loi = 'Không kết nối được.';
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, cuon) => ListView(
          controller: cuon,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            Text('${l['event_title'] ?? 'Lượt làm bài'}',
                style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('${_ngay(l['luc'])} · đúng ${l['dung']}/${l['tong']} câu',
                style: const TextStyle(color: AppColors.inkSoft)),
            const SizedBox(height: 14),
            if (loi != null) Text(loi, style: const TextStyle(color: AppColors.danger)),
            for (final c in cau ?? const <Map<String, dynamic>>[]) _CauDaLam(c: c),
          ],
        ),
      ),
    );
  }

  static String _ngay(Object? iso) {
    final t = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (t == null) return '';
    String h(int n) => n.toString().padLeft(2, '0');
    return '${h(t.day)}/${h(t.month)}/${t.year} ${h(t.hour)}:${h(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final tk = _thongKe;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: const Text('LỊCH SỬ HỌC'),
      ),
      body: RefreshIndicator(
        onRefresh: _tai,
        color: AppColors.red,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            if (_dangTai)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator(color: AppColors.red)),
              )
            else if (_loi != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(_loi!, textAlign: TextAlign.center),
              )
            else ...[
              if (tk != null) ...[
                Row(children: [
                  Expanded(child: _O(nhan: 'Câu đã làm', giaTri: '${tk['tong_cau']}')),
                  const SizedBox(width: 10),
                  Expanded(child: _O(nhan: 'Tỉ lệ đúng', giaTri: '${tk['ti_le_dung']}%')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _O(nhan: 'Trận đã học', giaTri: '${tk['so_su_kien_da_hoc']}')),
                  const SizedBox(width: 10),
                  Expanded(child: _O(nhan: 'Hạng', giaTri: '${tk['hang']}/${tk['tong_nguoi']}')),
                ]),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withValues(alpha: .6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ôn câu sai',
                        style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    const SizedBox(height: 4),
                    Text(
                      _cauSai.isEmpty
                          ? 'Không còn câu nào đang sai. Làm thêm quiz để có câu ôn.'
                          : '${_cauSai.length} câu lần gần nhất bạn trả lời chưa đúng. '
                              'Ôn đúng câu nào, câu đó rời khỏi danh sách.',
                      style: const TextStyle(color: AppColors.inkSoft, height: 1.4),
                    ),
                    if (_cauSai.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _onCauSai,
                        icon: const Icon(Icons.replay_rounded),
                        label: Text('Ôn ${_cauSai.length} câu'),
                      ),
                    ],
                    if (_cauSaiBiKhoa > 0) ...[
                      const SizedBox(height: 12),
                      DongConCauSai(soCon: _cauSaiBiKhoa, onXemPremium: _xemPremium),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('CÁC LƯỢT LÀM BÀI',
                  style: TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .7)),
              const SizedBox(height: 8),
              if (_luot.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Chưa có lượt nào. Vào Đấu trường để làm quiz đầu tiên.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.inkSoft)),
                ),
              for (final l in _luot)
                Card(
                  color: AppColors.card,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border)),
                  child: ListTile(
                    title: Text('${l['event_title'] ?? 'Quiz'}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_ngay(l['luc'])),
                    trailing: Text('${l['dung']}/${l['tong']}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: l['dung'] == l['tong']
                                ? AppColors.success
                                : AppColors.cta)),
                    onTap: () => _xemLuot(l),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dòng "Còn N câu nữa — mở bằng Premium" dưới nút Ôn câu sai của bản thường. Chỉ nói
/// SỐ câu còn lại (máy chủ không gửi nội dung các câu đó), và có lối đi tới Premium.
class DongConCauSai extends StatelessWidget {
  const DongConCauSai({super.key, required this.soCon, required this.onXemPremium});

  final int soCon;
  final VoidCallback onXemPremium;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('con-cau-sai'),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.bgAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withValues(alpha: .5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.goldDark),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Còn $soCon câu nữa — mở bằng Premium',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      height: 1.35,
                      color: AppColors.ink)),
            ),
            TextButton(
              onPressed: onXemPremium,
              child: const Text('Xem Premium',
                  style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      color: AppColors.red)),
            ),
          ],
        ),
      );
}

class _O extends StatelessWidget {
  const _O({required this.nhan, required this.giaTri});

  final String nhan;
  final String giaTri;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(giaTri,
                style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red)),
            Text(nhan, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
          ],
        ),
      );
}

class _CauDaLam extends StatelessWidget {
  const _CauDaLam({required this.c});

  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    final dung = c['correct'] == true;
    final chon = '${c['selected_option'] ?? ''}';
    final dapAn = '${c['correct_option'] ?? ''}'.toUpperCase();
    final phuongAn = (c['options'] as Map?)?.cast<String, dynamic>() ?? const {};
    String noi(String k) => k.isEmpty ? '(hết giờ)' : '$k. ${phuongAn[k] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (dung ? AppColors.success : AppColors.danger).withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (dung ? AppColors.success : AppColors.danger).withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${c['question']}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text('Bạn chọn: ${noi(chon)}',
              style: TextStyle(color: dung ? AppColors.success : AppColors.danger)),
          if (!dung) Text('Đáp án đúng: ${noi(dapAn)}',
              style: const TextStyle(color: AppColors.success)),
          if ((c['explanation'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${c['explanation']}',
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
