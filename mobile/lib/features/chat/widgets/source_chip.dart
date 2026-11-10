import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Chip hiển thị nguồn sử liệu chuẩn xác.
/// Thay thế hoàn toàn màu navy cũ bằng sắc đỏ thẫm hoàng cung redDeepest.
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.redDeepest,
        border: Border.all(
          color: AppColors.goldBright.withValues(alpha: 0.35),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: appSoftShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, color: AppColors.goldBright, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              color: AppColors.goldBright,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
