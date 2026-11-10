import 'package:flutter/material.dart';
import '../theme.dart';

/// Header Sa Bàn Chỉ Huy Chiến Thuật & Sĩ Khí Đại Việt
class BattlefieldTacticsHeader extends StatelessWidget {
  final String campaignName;
  final int currentQuestion;
  final int totalQuestions;
  final int correctCount;
  final int streakCount;
  final int timeRemaining;
  final bool isDrumBeating;
  final EdgeInsetsGeometry? margin;

  const BattlefieldTacticsHeader({
    super.key,
    required this.campaignName,
    required this.currentQuestion,
    required this.totalQuestions,
    required this.correctCount,
    required this.streakCount,
    required this.timeRemaining,
    required this.isDrumBeating,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    // Phong độ tăng khi trả lời đúng (từ 50% đến 100%). Chữ trên thanh này đổi
    // sang lời thường 21/10 — góp ý: dùng từ "sử hoá" quá, học sinh thấy xa lạ.
    final double morale =
        (0.5 + (correctCount / (totalQuestions > 0 ? totalQuestions : 1)) * 0.5)
            .clamp(0.2, 1.0);
    final String moraleStatus = morale >= 0.85
        ? 'Đang cực kỳ xuất sắc!'
        : morale >= 0.65
            ? 'Đang làm tốt lắm'
            : 'Bình tĩnh, chắc từng câu';

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.redDeepest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.goldImperial.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dòng 1: Tên chiến địa & Thời gian đếm ngược
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.goldImperial.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.goldImperial, width: 1.2),
                    ),
                    child: const Icon(
                      Icons.fort_rounded,
                      color: AppColors.goldLight,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ĐẤU TRƯỜNG',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.goldLight.withValues(alpha: 0.7),
                          letterSpacing: 1.5,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        campaignName,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.textPrimaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Trống trận đếm ngược
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDrumBeating
                      ? AppColors.redPrimary
                      : AppColors.goldImperial.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isDrumBeating ? Colors.white : AppColors.goldImperial,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDrumBeating
                          ? Icons.warning_amber_rounded
                          : Icons.timer_rounded,
                      size: 16,
                      color: isDrumBeating ? Colors.white : AppColors.goldLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${timeRemaining}s',
                      style: AppTypography.labelMedium.copyWith(
                        color:
                            isDrumBeating ? Colors.white : AppColors.goldLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Dòng 2: Lộ trình tiến quân (Quân kỳ dịch chuyển theo câu hỏi)
          Row(
            children: [
              Text(
                'Câu $currentQuestion/$totalQuestions',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (streakCount > 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.goldImperial,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Đúng liền $streakCount',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.redDeepest,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Thanh sa bàn lộ trình với cờ lệnh
          LayoutBuilder(
            builder: (context, constraints) {
              final double progress = totalQuestions > 0
                  ? (currentQuestion / totalQuestions).clamp(0.0, 1.0)
                  : 0.0;
              final double flagPosition =
                  (constraints.maxWidth - 24) * progress;

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // Đường hành quân ngầm
                  Container(
                    height: 8,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.goldImperial.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.goldDark, AppColors.goldLight],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Cờ lệnh di chuyển
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    left: flagPosition,
                    top: -10,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.redPrimary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.goldImperial,
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        color: AppColors.goldLight,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // Dòng 3: Sĩ Khí Đại Việt — animated bar + text
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.goldLight,
                size: 16,
              ),
              const SizedBox(width: 4),
              // Animated morale percentage text
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: morale),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, animValue, _) {
                  return Text(
                    'Phong độ: ${(animValue * 100).toInt()}%',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  moraleStatus,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryDark,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Sĩ khí progress bar — animated width
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: 6,
                width: constraints.maxWidth,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * morale,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.goldDark,
                          morale >= 0.75
                              ? AppColors.goldBright
                              : AppColors.gold,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
