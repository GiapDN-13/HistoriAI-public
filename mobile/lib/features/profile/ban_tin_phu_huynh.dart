import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

/// Bản tin tuần cho phụ huynh: học sinh tạo một link, gửi bố mẹ qua Zalo.
///
/// VÌ SAO (góp ý của một phụ huynh): "chưa biết rõ từng bài trong app liên quan đến
/// phần kiến thức nào con đang học trên lớp". Người dùng là học sinh, người trả tiền
/// là phụ huynh — bố mẹ phải thấy được con học gì mà không cần cài app hay có tài
/// khoản. Link mở một trang HTML nhẹ do máy chủ dựng (backend/app/api/routes/ban_tin.py):
/// tuần này con làm trận nào, đúng bao nhiêu câu, câu nào còn sai, bài đó học ở lớp mấy.
class TheBanTinPhuHuynh extends StatelessWidget {
  const TheBanTinPhuHuynh({super.key});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('the-ban-tin-phu-huynh'),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: .6)),
          boxShadow: appSoftShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => moBanTinPhuHuynh(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.family_restroom_rounded, color: AppColors.red, size: 23),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Gửi bản tin tuần cho phụ huynh',
                        style: TextStyle(
                            color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 14.5)),
                    SizedBox(height: 3),
                    Text(
                        'Một link để bố mẹ xem tuần này con học gì, đúng bao nhiêu câu '
                        'và bài đó ứng với lớp nào trên trường.',
                        style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5, height: 1.35)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
              ]),
            ),
          ),
        ),
      );
}

Future<void> moBanTinPhuHuynh(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => const BanTinPhuHuynhSheet(),
    );

/// Tạo link ngay khi mở. Link không lưu ở máy chủ (tự mang chữ ký + hạn 14 ngày),
/// nên mỗi lần mở là một link mới — link cũ vẫn dùng được tới hạn của nó.
class BanTinPhuHuynhSheet extends StatefulWidget {
  const BanTinPhuHuynhSheet({super.key});

  @override
  State<BanTinPhuHuynhSheet> createState() => _BanTinPhuHuynhSheetState();
}

class _BanTinPhuHuynhSheetState extends State<BanTinPhuHuynhSheet> {
  bool _dangTao = true;
  String? _url;
  DateTime? _hetHan;
  String? _loi;
  String? _loiMo;

  @override
  void initState() {
    super.initState();
    _taoLink();
  }

  Future<void> _taoLink() async {
    setState(() {
      _dangTao = true;
      _loi = null;
      _loiMo = null;
    });
    String? url;
    DateTime? hetHan;
    String? loi;
    try {
      final r = await ApiClient().post('/me/ban-tin/link', const <String, dynamic>{});
      url = r is Map ? r['url'] as String? : null;
      hetHan = r is Map ? DateTime.tryParse('${r['het_han']}')?.toLocal() : null;
      if (url == null || url.isEmpty) loi = 'Chưa tạo được link. Thử lại sau ít phút nhé.';
    } on ApiException catch (e) {
      loi = e.isConnectionError
          ? 'Chưa tạo được link: không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'
          : 'Chưa tạo được link: ${e.message}';
    } catch (_) {
      // Bản web: mất mạng ném ClientException của gói http, không qua ApiException.
      loi = 'Chưa tạo được link. Kiểm tra mạng rồi thử lại.';
    }
    if (!mounted) return;
    setState(() {
      _dangTao = false;
      _loi = loi;
      _url = loi == null ? url : null;
      _hetHan = loi == null ? hetHan : null;
    });
  }

  Future<void> _chep() async {
    final url = _url;
    if (url == null) return;
    final nhan = ScaffoldMessenger.of(context);
    final dieuHuong = Navigator.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: url));
    } catch (_) {
      if (mounted) setState(() => _loiMo = 'Chưa chép được. Giữ tay lên link để chọn rồi chép.');
      return;
    }
    if (!mounted) return;
    // Đóng bảng rồi mới báo: SnackBar nằm ở màn phía dưới, để bảng mở là bị che mất.
    // Chép xong thì việc tiếp theo là sang Zalo — không cần giữ bảng.
    await dieuHuong.maybePop();
    nhan.showSnackBar(const SnackBar(content: Text('Đã chép — dán vào Zalo gửi bố mẹ nhé')));
  }

  Future<void> _xemTruoc() async {
    final url = _url;
    if (url == null) return;
    var mo = false;
    try {
      mo = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!mo && mounted) {
      setState(() => _loiMo = 'Chưa mở được trình duyệt. Hãy chép link rồi mở thử.');
    }
  }

  static String _ngay(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bản tin tuần cho phụ huynh',
                  style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 4),
              const Text(
                  'Gửi link này cho bố mẹ qua Zalo. Bố mẹ mở ra là thấy 7 ngày qua con làm '
                  'trận nào, đúng bao nhiêu câu, câu nào cần ôn lại và bài đó học ở lớp mấy '
                  'trên trường.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.45)),
              const SizedBox(height: 16),
              if (_dangTao)
                const Row(children: [
                  SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.red)),
                  SizedBox(width: 12),
                  Text('Đang tạo link…', style: TextStyle(color: AppColors.inkSoft)),
                ])
              else if (_loi != null)
                _HopLoi(loi: _loi!, onThuLai: _taoLink)
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withValues(alpha: .6)),
                  ),
                  child: SelectableText(_url!,
                      key: const Key('ban-tin-link'),
                      style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4)),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  FilledButton.icon(
                    key: const Key('ban-tin-chep'),
                    onPressed: _chep,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Chép link'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('ban-tin-xem'),
                    onPressed: _xemTruoc,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Xem trước'),
                  ),
                ]),
                if (_loiMo != null) ...[
                  const SizedBox(height: 8),
                  Text(_loiMo!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, size: 17, color: AppColors.inkMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        'Link có hạn 14 ngày${_hetHan == null ? '' : ' (tới ${_ngay(_hetHan!)})'}. '
                        'Ai có link đều xem được — chỉ gửi cho bố mẹ nhé.',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.inkSoft, height: 1.4)),
                  ),
                ]),
              ],
            ],
          ),
        ),
      );
}

class _HopLoi extends StatelessWidget {
  const _HopLoi({required this.loi, required this.onThuLai});

  final String loi;
  final VoidCallback onThuLai;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('ban-tin-loi'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.inkMuted, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(loi,
                    style: const TextStyle(color: AppColors.ink, fontSize: 13.5, height: 1.4))),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onThuLai,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ),
        ]),
      );
}
