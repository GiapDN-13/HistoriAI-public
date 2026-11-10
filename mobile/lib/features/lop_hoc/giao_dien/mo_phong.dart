import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Các lựa chọn phụ ở cùng chỗ để thầy cô không phải đi qua nhiều hộp thoại.
class MoPhong extends StatefulWidget {
  const MoPhong({super.key, required this.tieuDe, required this.lop});
  final String tieuDe;
  final List<Map<String, dynamic>> lop;
  @override
  State<MoPhong> createState() => _MoPhongState();
}

class _MoPhongState extends State<MoPhong> {
  String _cheDo = 'truc_tiep';
  int _han = 0;
  int? _lopId;
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Mở phòng'),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(widget.tieuDe, style: AppTypography.headingSmall),
                  const SizedBox(height: 16),
                  for (final (ma, ten, phu, hinh) in const [
                    (
                      'truc_tiep',
                      'Thi trực tiếp',
                      'Cả lớp cùng chơi, thầy cô chuyển câu',
                      Icons.cast_rounded
                    ),
                    (
                      'bai_tap',
                      'Bài tập',
                      'Các em tự làm theo nhịp của mình',
                      Icons.menu_book_rounded
                    ),
                  ])
                    Card(
                        elevation: 0,
                        color: _cheDo == ma ? AppColors.bgAlt : AppColors.card,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: _cheDo == ma
                                    ? AppColors.gold
                                    : AppColors.border)),
                        child: ListTile(
                            onTap: () => setState(() => _cheDo = ma),
                            leading: Icon(hinh, color: AppColors.red),
                      title: Text(ten, style: AppTypography.labelMedium),
                      subtitle: Text(phu, style: AppTypography.bodyMedium),
                            trailing: Icon(_cheDo == ma
                                ? Icons.check_circle
                                : Icons.circle_outlined))),
                  if (_cheDo == 'bai_tap') ...[
                    const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                  style: AppTypography.bodyMedium,
                        initialValue: _han,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Hạn làm bài'),
                        items: [
                          for (final (phut, nhan) in const [
                            (0, 'Tới khi thầy cô đóng'),
                            (15, '15 phút'),
                            (45, 'Một tiết · 45 phút'),
                            (1440, '1 ngày'),
                            (10080, '7 ngày'),
                          ])
                            DropdownMenuItem(value: phut, child: Text(nhan))
                        ],
                        onChanged: (v) => setState(() => _han = v ?? 0)),
                  ],
                  if (widget.lop.isNotEmpty) ...[
                    const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                  style: AppTypography.bodyMedium,
                        initialValue: _lopId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Lớp'),
                        items: [
                          const DropdownMenuItem<int>(
                              value: null, child: Text('Không gắn lớp')),
                          for (final l in widget.lop)
                            DropdownMenuItem(
                                value: l['id'] as int,
                                child: Text('${l['ten']} · ${l['si_so']} em',
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: (v) => setState(() => _lopId = v)),
                  ],
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(context, (
                    _cheDo,
                    _cheDo == 'truc_tiep' || _han == 0 ? null : _han,
                    _lopId
                  )),
              child: const Text('Mở phòng')),
        ],
      );
}
