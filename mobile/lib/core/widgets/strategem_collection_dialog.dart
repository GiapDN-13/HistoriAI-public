import 'package:flutter/material.dart';
import '../models/strategem.dart';
import '../theme.dart';
import 'app_widgets.dart';
import 'vietnamese_decorations.dart';

/// Hộp thoại Túi Cẩm Nang Kế Sách Sử Việt
class StrategemCollectionDialog extends StatefulWidget {
  const StrategemCollectionDialog({super.key});

  @override
  State<StrategemCollectionDialog> createState() =>
      _StrategemCollectionDialogState();
}

class _StrategemCollectionDialogState extends State<StrategemCollectionDialog> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final list = HistoricalStrategem.allStrategems;
    final current = list[_selectedIndex];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.paperCream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.goldImperial,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldImperial.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Nền trống đồng Đông Sơn
                const Positioned.fill(
                  child: Opacity(
                    opacity: 0.05,
                    child: DongSonBackground(),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.redDeepest,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.goldImperial,
                                      width: 1.2),
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: AppColors.goldLight,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CẨM NANG KẾ SÁCH',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.redPrimary,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                  Text(
                                    'Binh Pháp Đại Việt',
                                    style: AppTypography.headingSmall.copyWith(
                                      color: AppColors.textPrimaryLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: 'Đóng bộ sưu tập',
                            icon: const Icon(Icons.close_rounded,
                                color: AppColors.textSecondaryLight),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Danh sách chọn nhanh các thẻ kế sách (ngang)
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final isSelected = _selectedIndex == i;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedIndex = i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.redDeepest
                                      : AppColors.bgAlt,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.goldImperial
                                        : AppColors.border,
                                    width: isSelected ? 1.4 : 1.0,
                                  ),
                                ),
                                child: Text(
                                  list[i].title,
                                  style: AppTypography.caption.copyWith(
                                    color: isSelected
                                        ? AppColors.goldLight
                                        : AppColors.textPrimaryLight,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Chi tiết kế sách đang chọn
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Tên kế sách & Tác giả
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.redDeepest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.goldImperial,
                                      width: 1.2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(current.icon,
                                            color: AppColors.goldLight,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            current.title.toUpperCase(),
                                            style: AppTypography.headingSmall
                                                .copyWith(
                                              color: AppColors.goldLight,
                                              letterSpacing: 1.2,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${current.author} • ${current.period}',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Cốt lõi: ${current.corePrinciple}',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Bối cảnh lịch sử
                              Text(
                                'BỐI CẢNH LỊCH SỬ',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.redPrimary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                current.historyStory,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textPrimaryLight,
                                  height: 1.5,
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Ứng dụng trong đời sống hiện đại (EdTech lesson)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9F5EA),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.goldImperial
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.lightbulb_rounded,
                                          color: AppColors.cta,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'BÀI HỌC THỜI NAY CHO HỌC SINH',
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.goldDark,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      current.modernLesson,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textPrimaryLight,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Lời trích dẫn bất hủ
                              Center(
                                child: Text(
                                  '“${current.famousQuote}”',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.redPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Nút đóng
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: 'Khép Lại Cẩm Nang',
                          icon: Icons.check_circle_outline_rounded,
                          variant: AppButtonVariant.primary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper hiển thị Túi Cẩm Nang Kế Sách
void showStrategemCollectionDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (_) => const StrategemCollectionDialog(),
  );
}
