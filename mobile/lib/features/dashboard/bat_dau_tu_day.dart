import 'package:flutter/material.dart';

import '../../core/lo_trinh_dau.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../chat/mo_chat.dart';
import '../quiz/quiz_play_screen.dart';
import '../timeline/event_detail_screen.dart';

/// Thẻ "Bắt đầu từ đây": ba bước cho người mới, cùng một trận Bạch Đằng 938.
/// Xem [LoTrinhDau] cho lý do (góp ý 17/10).
///
/// Bước 2, 3 dùng lại biểu tượng của lưới "Khám phá" (đã tải sẵn ở trang chủ).
/// Bước 1 chờ ảnh `assets/lo_trinh/buoc_1_xem_phim.png` (giao Codex — xem
/// `docs/PROMPT_CODEX_PHAN_HOI_21-10.md`); chưa có thì hiện biểu tượng.
class BatDauTuDay extends StatelessWidget {
  const BatDauTuDay({
    super.key,
    required this.suKien,
    this.suKienTiepTheo,
  });

  /// Toàn bộ sự kiện (đã tải). Thẻ cần Bạch Đằng 938 — không có thì ẩn.
  final List<HistoricalEvent> suKien;

  /// Gợi ý sau khi xong ba bước (theo lộ trình 938 → 981 → 1288 của nhóm).
  final HistoricalEvent? suKienTiepTheo;

  static const slugBatDau = 'bach-dang-938';

  @override
  Widget build(BuildContext context) {
    final e = suKien.where((x) => x.slug == slugBatDau).firstOrNull;
    if (e == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: LoTrinhDau.daAn,
      builder: (_, an, __) => an
          ? const SizedBox.shrink()
          : ValueListenableBuilder<Set<String>>(
              valueListenable: LoTrinhDau.daXong,
              builder: (context, xong, _) => _the(context, e, xong),
            ),
    );
  }

  Widget _the(BuildContext context, HistoricalEvent e, Set<String> xong) {
    final soXong = LoTrinhDau.cacBuoc.where(xong.contains).length;
    final buoc = [
      (
        LoTrinhDau.xemPhim,
        'Xem phim trận Bạch Đằng 938',
        'Thấy Ngô Quyền dùng cọc ngầm và thuỷ triều đánh thắng quân Nam Hán.',
        Icons.movie_outlined,
        'assets/lo_trinh/buoc_1_xem_phim.png',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => EventDetailScreen(event: e))),
      ),
      (
        LoTrinhDau.hoiViNhan,
        'Hỏi Trần Hưng Đạo một câu',
        '350 năm sau, ông dùng lại kế cọc ngầm trên chính dòng sông này.',
        Icons.forum_outlined,
        'assets/figures3d/item/isolate_the_warrior_helmet_and_speech_bubble_icon_on_a_completely_clean_solid.png',
        () => moChatVoiViNhan(context, 'tran-hung-dao',
            cauMoDau: 'Vì sao ngài dùng lại kế cọc ngầm của Ngô Quyền trên sông Bạch Đằng?'),
      ),
      (
        LoTrinhDau.lamQuiz,
        'Làm quiz Bạch Đằng 938',
        'Mỗi câu đúng +10 điểm. Sai thì có giải thích ngay.',
        Icons.emoji_events_outlined,
        'assets/figures3d/item/isolate_only_the_golden_arena_quiz_trophy_icon_from_bottom_right_golden.png',
        () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    QuizPlayScreen(eventSlug: e.slug, eventTitle: e.title))),
      ),
    ];
    final xongHet = soXong == buoc.length;

    return Container(
      key: const Key('bat-dau-tu-day'),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cta.withValues(alpha: .55), width: 1.4),
        boxShadow: appSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  xongHet ? 'Xong 3 bước đầu rồi!' : 'Bắt đầu từ đây',
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                '$soXong/${buoc.length}',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  color: AppColors.cta,
                ),
              ),
              IconButton(
                tooltip: 'Ẩn thẻ này',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkMuted),
                onPressed: LoTrinhDau.an,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              xongHet
                  ? (suKienTiepTheo == null
                      ? 'Bạn đã biết cách dùng cả ba tính năng chính.'
                      : 'Học tiếp theo lộ trình: ${suKienTiepTheo!.title}.')
                  : 'Chưa biết học gì trước? Đi lần lượt 3 bước này.',
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.4),
            ),
          ),
          const SizedBox(height: 10),
          if (!xongHet)
            for (var i = 0; i < buoc.length; i++)
              _DongBuoc(
                so: i + 1,
                tieuDe: buoc[i].$2,
                moTa: buoc[i].$3,
                icon: buoc[i].$4,
                anh: buoc[i].$5,
                daXong: xong.contains(buoc[i].$1),
                // Bước kế tiếp chưa xong được tô nổi để mắt biết bấm vào đâu.
                laBuocKe: !xong.contains(buoc[i].$1) &&
                    buoc.take(i).every((b) => xong.contains(b.$1)),
                onTap: buoc[i].$6,
              )
          else if (suKienTiepTheo != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.cta),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EventDetailScreen(event: suKienTiepTheo!))),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text('Học ${suKienTiepTheo!.title}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _DongBuoc extends StatelessWidget {
  const _DongBuoc({
    required this.so,
    required this.tieuDe,
    required this.moTa,
    required this.icon,
    required this.anh,
    required this.daXong,
    required this.laBuocKe,
    required this.onTap,
  });

  final int so;
  final String tieuDe;
  final String moTa;
  final IconData icon;
  final String anh;
  final bool daXong;
  final bool laBuocKe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mau = daXong ? AppColors.success : (laBuocKe ? AppColors.cta : AppColors.inkMuted);
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Material(
        color: laBuocKe ? AppColors.cta.withValues(alpha: .07) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Image.asset(
                    anh,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        color: mau.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: mau, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bước $so · $tieuDe',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.ink,
                          decoration: daXong ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(moTa,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.inkSoft, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  daXong ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                  color: mau,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
