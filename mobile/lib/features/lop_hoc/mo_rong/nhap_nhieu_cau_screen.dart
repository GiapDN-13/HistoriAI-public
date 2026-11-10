import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../lop_hoc_api.dart';
import '../giao_dien/san_choi.dart';
import 'prompt_soan_de.dart';

/// Dán nhiều câu một lúc — thường là kết quả AI trả về theo [promptSoanDe].
/// Hai bước: Xem trước (máy chủ đọc và chỉ ra câu lỗi) → Lưu các câu hợp lệ.
class NhapNhieuCauScreen extends StatefulWidget {
  const NhapNhieuCauScreen({super.key, this.api});

  final LopHocApi? api;

  @override
  State<NhapNhieuCauScreen> createState() => _NhapNhieuCauScreenState();
}

class _NhapNhieuCauScreenState extends State<NhapNhieuCauScreen> {
  late final LopHocApi _api = widget.api ?? LopHocApi();
  final _chu = TextEditingController();
  Map<String, dynamic>? _xem; // kết quả xem trước
  bool _dang = false;
  String? _loi;

  @override
  void dispose() {
    _chu.dispose();
    super.dispose();
  }

  Future<void> _chepPrompt() async {
    await Clipboard.setData(const ClipboardData(text: promptSoanDe));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Đã chép prompt. Dán vào ChatGPT / Gemini, sửa chủ đề trong [ ], '
            'rồi chép câu trả lời của AI về dán vào ô dưới.')));
  }

  Future<void> _dan() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text?.isNotEmpty ?? false)
      setState(() {
        _chu.text = d!.text!;
        _xem = null;
      });
  }

  Future<void> _goi({required bool luu}) async {
    if (_chu.text.trim().isEmpty) return;
    setState(() {
      _dang = true;
      _loi = null;
    });
    try {
      final kq = await _api.nhapNhieuCau(_chu.text, luu: luu);
      if (!mounted) return;
      if (luu) {
        Navigator.pop(context, kq['da_luu'] as int? ?? 0);
        return;
      }
      setState(() => _xem = kq);
    } on ApiException catch (e) {
      setState(() => _loi = e.message);
    } catch (_) {
      setState(() => _loi = 'Không kết nối được. Kiểm tra mạng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _dang = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final xem = _xem;
    final hopLe = xem?['hop_le'] as int? ?? 0;
    return KhungLopHoc(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: const Text('DÁN NHIỀU CÂU'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const Text('Từ đề AI đến trận mới', style: AppTypography.headingMedium),
          const SizedBox(height: 6),
          const Text('Chép mẫu, dán câu hỏi rồi kiểm tra đáp án trước khi lưu.', style: AppTypography.bodyMedium),
          const SizedBox(height: 16),
          _Buoc(
            so: 1,
            tieuDe: 'Nhờ AI soạn đề',
            chu:
                'Chép prompt, dán vào ChatGPT / Gemini (bản miễn phí là đủ), sửa chủ đề, số câu, '
                'lớp trong dấu [ ].',
            nut: OutlinedButton.icon(
              onPressed: _chepPrompt,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Chép prompt cho AI'),
            ),
          ),
          ExpansionTile(title: const Text('Xem mẫu yêu cầu cho AI'), children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(promptSoanDe,
                    style: AppTypography.bodyMedium))
          ]),
          const SizedBox(height: 12),
          _Buoc(
            so: 2,
            tieuDe: 'Dán câu trả lời của AI vào đây',
            chu:
                'Tự soạn tay cũng được, miễn đúng mẫu: "Câu 1: …", bốn dòng A. B. C. D., '
                '"Đáp án: B", "Giải thích: …".',
            nut: TextButton.icon(
              onPressed: _dan,
              icon: const Icon(Icons.content_paste_rounded),
              label: const Text('Dán từ bộ nhớ tạm'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _chu,
            minLines: 8,
            maxLines: 16,
            onChanged: (_) {
              if (_xem != null) setState(() => _xem = null);
            },
            decoration: const InputDecoration(
              hintText:
                  'Câu 1: Trận Bạch Đằng năm 938 do ai chỉ huy?\nA. Ngô Quyền\nB. Lê Hoàn\n'
                  'C. Trần Hưng Đạo\nD. Lý Thường Kiệt\nĐáp án: A\nGiải thích: …',
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_loi != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_loi!,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      color: AppColors.danger)),
            ),
          if (xem != null) ...[
            Text(
                'Đọc được ${(xem['cau'] as List).length} câu: $hopLe câu dùng được'
                '${xem['loi'] != 0 ? ', ${xem['loi']} câu lỗi (sẽ bỏ qua)' : ''}.',
                style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text('Đọc lại đáp án trước khi lưu — AI cũng có lúc sai.',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    color: AppColors.inkSoft,
                    fontSize: 13)),
            const SizedBox(height: 8),
            for (final c in (xem['cau'] as List).cast<Map<String, dynamic>>())
              _CauXem(c: c),
          ],
        ],
      ),
      bottomNavigationBar: xem == null
          ? SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                      onPressed: _dang ? null : () => _goi(luu: false),
                      icon: const Icon(Icons.visibility_rounded),
                      label: Text(_dang ? 'Đang đọc…' : 'Bước 3: Xem trước'))))
          : hopLe == 0
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50)),
                      onPressed: _dang ? null : () => _goi(luu: true),
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_dang
                          ? 'Đang lưu…'
                          : 'Lưu $hopLe câu vào "Câu tôi tự soạn"'),
                    ),
                  ),
                ),
    );
  }
}

class _Buoc extends StatelessWidget {
  const _Buoc(
      {required this.so,
      required this.tieuDe,
      required this.chu,
      required this.nut});

  final int so;
  final String tieuDe;
  final String chu;
  final Widget nut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: .5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.red,
            child: Text('$so',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 13,
                )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(tieuDe,
                style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(chu,
            style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                color: AppColors.inkSoft,
                fontSize: 13,
                height: 1.4)),
        const SizedBox(height: 6),
        nut,
      ]),
    );
  }
}

class _CauXem extends StatelessWidget {
  const _CauXem({required this.c});

  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    final loi = c['loi'] as String?;
    final mau = loi == null ? AppColors.success : AppColors.danger;
    final dung = '${c['correct_option']}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mau.withValues(alpha: .35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Câu ${c['so']}: ${c['question']}',
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: AppColors.ink)),
        const SizedBox(height: 4),
        for (final k in ['a', 'b', 'c', 'd'])
          if ('${c['option_$k'] ?? ''}'.isNotEmpty)
            Text(
                '${k.toUpperCase()}. ${c['option_$k']}${dung == k.toUpperCase() ? '   ✓' : ''}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: dung == k.toUpperCase()
                      ? AppColors.success
                      : AppColors.ink,
                )),
        if (loi != null) ...[
          const SizedBox(height: 4),
          Text('✗ $loi',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              )),
        ] else if ('${c['explanation'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${c['explanation']}',
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.inkSoft,
                  fontSize: 12.5)),
        ],
      ]),
    );
  }
}
