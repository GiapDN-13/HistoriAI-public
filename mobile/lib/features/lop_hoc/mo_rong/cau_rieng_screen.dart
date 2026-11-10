import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../lop_hoc_api.dart';
import '../giao_dien/san_choi.dart';
import 'nhap_nhieu_cau_screen.dart';

/// Câu hỏi giáo viên tự soạn. Chỉ thầy cô đó thấy; dùng được khi soạn đề (nhóm "Câu tôi
/// tự soạn" ở đầu kho). Không vào kho quiz chung của app — kho chung đã qua kiểm duyệt.
class CauRiengScreen extends StatefulWidget {
  const CauRiengScreen({super.key, this.api});

  final LopHocApi? api;

  @override
  State<CauRiengScreen> createState() => _CauRiengScreenState();
}

class _CauRiengScreenState extends State<CauRiengScreen> {
  late final LopHocApi _api = widget.api ?? LopHocApi();
  List<Map<String, dynamic>> _cau = [];
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
      final c = await _api.dsCauRieng();
      if (mounted) {
        setState(() {
          _cau = c;
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

  Future<void> _soan([Map<String, dynamic>? cu]) async {
    final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => SoanCauScreen(api: _api, cu: cu)));
    if (ok == true) _tai();
  }

  Future<void> _xoa(Map<String, dynamic> c) async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Xoá câu này?'),
        content: Text(c['da_dung_trong_de'] == true
            ? 'Câu đang nằm trong đề đã soạn. Câu sẽ ẩn khỏi kho, không đưa vào đề mới được, '
                'nhưng bài học sinh đã làm vẫn xem lại được.'
            : 'Câu sẽ bị xoá hẳn.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xoá')),
        ],
      ),
    );
    if (dongY != true) return;
    try {
      await _api.xoaCauRieng(c['cau_rieng_id'] as int);
      _tai();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _danNhieu() async {
    final so = await Navigator.of(context).push<int>(
        MaterialPageRoute(builder: (_) => NhapNhieuCauScreen(api: _api)));
    if (so == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Đã lưu $so câu.')));
    _tai();
  }

  @override
  Widget build(BuildContext context) {
    return KhungLopHoc(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: const Text('CÂU TÔI TỰ SOẠN'),
        actions: [
          TextButton.icon(
            onPressed: _danNhieu,
            style: TextButton.styleFrom(foregroundColor: AppColors.goldBright),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Dán nhiều câu'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _soan(),
        backgroundColor: AppColors.decorativeOrange,
        foregroundColor: AppColors.ink,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Soạn câu'),
      ),
      body: RefreshIndicator(
        onRefresh: _tai,
        color: AppColors.red,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const LoiChaoSanChoi(
                tieuDe: 'Kho câu của thầy cô',
                moTa:
                    'Soạn một câu hoặc dán cả đề. Câu đã lưu dùng được ngay khi chọn đề.'),
            const SizedBox(height: 16),
            const Text(
              'Câu thầy cô tự soạn chỉ thầy cô thấy, dùng được khi soạn đề cùng câu trong kho. '
              'Câu không vào phần luyện quiz chung của app.',
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
            else if (_cau.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Chưa có câu nào. Bấm "Soạn câu" để bắt đầu.',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        color: AppColors.inkSoft)),
              )
            else
              for (final c in _cau)
                Card(
                  color: AppColors.card,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border)),
                  child: ListTile(
                    onTap: () => _soan(c),
                    title: Text('${c['question']}',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                        )),
                    subtitle: Text(
                      'Đáp án ${c['correct_option']}. ${(c['options'] as Map)[c['correct_option']]}'
                      '${c['event_title'] != null ? ' · ${c['event_title']}' : ''}',
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 12.5),
                    ),
                    trailing: IconButton(
                      tooltip: 'Xoá',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _xoa(c),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Soạn mới (cu == null) hoặc sửa một câu. Trả về true khi đã lưu.
class SoanCauScreen extends StatefulWidget {
  const SoanCauScreen({super.key, required this.api, this.cu});

  final LopHocApi api;
  final Map<String, dynamic>? cu;

  @override
  State<SoanCauScreen> createState() => _SoanCauScreenState();
}

class _SoanCauScreenState extends State<SoanCauScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _hoi =
      TextEditingController(text: widget.cu?['question'] as String?);
  late final _pa = {
    for (final k in const ['A', 'B', 'C', 'D'])
      k: TextEditingController(
          text: (widget.cu?['options'] as Map?)?[k] as String?),
  };
  late final _giaiThich =
      TextEditingController(text: widget.cu?['explanation'] as String?);
  late String _dung = (widget.cu?['correct_option'] as String?) ?? 'A';
  late String? _suKien = widget.cu?['event_slug'] as String?;
  List<(String, String)> _dsSuKien = [];
  bool _dangLuu = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    // Danh sách sự kiện lấy từ kho câu (đã có sẵn cho giáo viên) — không cần API riêng.
    widget.api.khoCau().then((kho) {
      if (!mounted) return;
      setState(() => _dsSuKien = [
            for (final sk in kho)
              if (sk['rieng'] != true)
                ('${sk['event_slug']}', '${sk['event_title']}'),
          ]);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _hoi.dispose();
    for (final c in _pa.values) {
      c.dispose();
    }
    _giaiThich.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    if (!_formKey.currentState!.validate()) return;
    final du = {
      'question': _hoi.text.trim(),
      for (final k in _pa.keys)
        'option_${k.toLowerCase()}': _pa[k]!.text.trim(),
      'correct_option': _dung,
      'explanation':
          _giaiThich.text.trim().isEmpty ? null : _giaiThich.text.trim(),
      'event_slug': _suKien,
    };
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      if (widget.cu == null) {
        await widget.api.taoCauRieng(du);
      } else {
        await widget.api.suaCauRieng(widget.cu!['cau_rieng_id'] as int, du);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Không kết nối được. Thử lại.');
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sự kiện đang gắn có thể không còn trong danh sách tải về → vẫn hiện để khỏi lỗi Dropdown.
    final dsSk = [
      ..._dsSuKien,
      if (_suKien != null && !_dsSuKien.any((s) => s.$1 == _suKien))
        (_suKien!, '${widget.cu?['event_title'] ?? _suKien}'),
    ];
    return KhungLopHoc(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: Text(widget.cu == null ? 'SOẠN CÂU' : 'SỬA CÂU'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _dangLuu ? null : _luu,
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(_dangLuu ? 'Đang lưu…' : 'Lưu câu'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            TextFormField(
              controller: _hoi,
              maxLines: 3,
              minLines: 1,
              maxLength: 1000,
              decoration:
                  const InputDecoration(labelText: 'Câu hỏi', counterText: ''),
              validator: (v) =>
                  (v ?? '').trim().length < 5 ? 'Câu hỏi quá ngắn' : null,
            ),
            const SizedBox(height: 8),
            const Text('Bấm chữ cái để chọn đáp án đúng',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    color: AppColors.inkSoft,
                    fontSize: 12.5)),
            for (final k in _pa.keys)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, right: 8),
                        child: ChoiceChip(
                          label: Text(k),
                          selected: _dung == k,
                          selectedColor:
                              AppColors.success.withValues(alpha: .18),
                          onSelected: (_) => setState(() => _dung = k),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _pa[k],
                          maxLength: 300,
                          decoration: InputDecoration(
                            labelText:
                                'Phương án $k${_dung == k ? ' (đúng)' : ''}',
                            counterText: '',
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Nhập phương án $k'
                              : null,
                        ),
                      ),
                    ]),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _giaiThich,
              maxLines: 3,
              minLines: 1,
              maxLength: 2000,
              decoration: const InputDecoration(
                  labelText: 'Giải thích (hiện cho học sinh sau khi nộp)',
                  counterText: ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _suKien,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Gắn với sự kiện (không bắt buộc)'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Không gắn')),
                for (final s in dsSk)
                  DropdownMenuItem<String?>(value: s.$1, child: Text(s.$2)),
              ],
              onChanged: (v) => setState(() => _suKien = v),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                  'Gắn sự kiện để thống kê lớp cho biết cả lớp yếu ở sự kiện nào.',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      color: AppColors.inkSoft,
                      fontSize: 12.5)),
            ),
            if (_loi != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_loi!,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        color: AppColors.danger)),
              ),
          ],
        ),
      ),
    );
  }
}
