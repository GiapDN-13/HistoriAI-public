import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../app_preferences.dart';
import '../theme.dart';
import 'vietnamese_decorations.dart';

/// Thẻ "Mốc sử hôm nay" — mỗi ngày gợi ý một sự kiện THẬT trong kho, xoay vòng.
///
/// Trước 27/09 thẻ này tên "Ngày này năm xưa" nhưng nội dung viết cứng một bài về
/// Bình Ngô Đại Cáo, không đổi theo ngày, kèm con số không có nguồn. Giờ lấy từ
/// /events (cùng tóm tắt đã duyệt trên dòng thời gian) và không tự nhận là "ngày
/// này năm xưa" — kho chưa có ngày tháng của từng sự kiện để khớp ngày.
class DailyHistoryCard extends StatefulWidget {
  final List<HistoricalEvent> suKien;
  final ValueChanged<HistoricalEvent>? onOpen;

  /// Hỏi vĩ nhân về mốc này. [tenViNhan] trả tên vị trả lời được (null = mốc chưa
  /// có vĩ nhân) — góp ý 04/10: "đọc xong mình lại muốn hỏi thêm mà chưa có chỗ để
  /// bấm vào tìm hiểu sâu hơn". Trước đây nút "Học mốc này" nằm ẩn sau mũi tên mở rộng.
  final ValueChanged<HistoricalEvent>? onHoi;
  final String? Function(HistoricalEvent)? tenViNhan;

  const DailyHistoryCard({
    super.key,
    required this.suKien,
    this.onOpen,
    this.onHoi,
    this.tenViNhan,
  });

  /// Sự kiện của ngày [ngay] — cùng một ngày thì mọi lần mở đều ra cùng sự kiện.
  static HistoricalEvent? cuaNgay(List<HistoricalEvent> ds, DateTime ngay) {
    if (ds.isEmpty) return null;
    final soNgay = DateTime.utc(ngay.year, ngay.month, ngay.day)
        .difference(DateTime.utc(2026))
        .inDays;
    return ds[soNgay % ds.length];
  }

  @override
  State<DailyHistoryCard> createState() => _DailyHistoryCardState();
}

class _DailyHistoryCardState extends State<DailyHistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = now.day;
    final month = now.month;
    final e = DailyHistoryCard.cuaNgay(widget.suKien, now);
    if (e == null) return const SizedBox.shrink();
    final tomTat = e.tomTatCho(AppPreferences.lopHoc.value) ?? e.summary ?? '';
    final viNhan = widget.tenViNhan?.call(e);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onOpen == null ? null : () => widget.onOpen!(e),
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.paperCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.goldImperial,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldImperial.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Nền trống đồng mờ
          const Positioned(
            right: -20,
            bottom: -20,
            width: 180,
            height: 180,
            child: Opacity(
              opacity: 0.06,
              child: DongSonBackground(size: 180),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dòng 1: Huy hiệu ngày & Tiêu đề
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.redDeepest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.goldImperial, width: 1.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  color: AppColors.goldLight,
                                  size: 12,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$day Tháng $month',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.goldLight,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'MỐC SỬ HÔM NAY',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.redPrimary,
                                letterSpacing: 1.5,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: AppColors.redPrimary,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Tiêu đề sự kiện
                Text(
                  e.title,
                  style: AppTypography.headingSmall.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    'Năm ${e.year}',
                    if ((e.period ?? '').isNotEmpty) e.period!,
                  ].join(' • '),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.goldDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                if (tomTat.isNotEmpty)
                  Text(
                    tomTat,
                    maxLines: _isExpanded ? null : 2,
                    overflow: _isExpanded ? null : TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryLight,
                      height: 1.5,
                    ),
                  ),

                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    if (viNhan != null && widget.onHoi != null)
                      OutlinedButton.icon(
                        key: const Key('moc-su-hoi'),
                        onPressed: () => widget.onHoi!(e),
                        icon: const Icon(Icons.forum_outlined, size: 15),
                        label: Text('Hỏi $viNhan'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.redPrimary,
                          side: const BorderSide(color: AppColors.goldImperial),
                          textStyle: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    FilledButton.icon(
                      key: const Key('moc-su-hoc'),
                      onPressed: widget.onOpen == null ? null : () => widget.onOpen!(e),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                      label: const Text('Học mốc này'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.redPrimary,
                        textStyle: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
