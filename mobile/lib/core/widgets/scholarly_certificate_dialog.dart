import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'app_widgets.dart';
import 'vietnamese_decorations.dart';

/// Hộp thoại Bằng Sắc Phong Vinh Quy tỉ lệ chuẩn 9:16 (Story format)
class ScholarlyCertificateDialog extends StatelessWidget {
  final String studentName;
  final String rankTitle;
  final String rankStage;
  final int xp;
  final String motto;

  const ScholarlyCertificateDialog({
    super.key,
    required this.studentName,
    required this.rankTitle,
    required this.rankStage,
    required this.xp,
    this.motto = 'Hiền tài là nguyên khí của quốc gia',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 660),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Khung Bằng Sắc Phong tỉ lệ chuẩn 9:16
              Expanded(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.paperCream,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.goldImperial, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.goldImperial.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Nền trống đồng mờ
                        const Positioned.fill(
                          child: Opacity(
                            opacity: 0.06,
                            child: DongSonBackground(),
                          ),
                        ),

                        // Viền trang trí 4 góc hoàng gia
                        const Positioned.fill(
                          child: ImperialBorderDecoration(
                            fillColor: Colors.transparent,
                            child: SizedBox.shrink(),
                          ),
                        ),

                        // Nội dung bằng sắc phong
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Đầu sắc phong
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.redDeepest,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.goldImperial, width: 1.2),
                                    ),
                                    child: Text(
                                      'QUỐC TỬ GIÁM BẢNG VÀNG',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.goldLight,
                                        letterSpacing: 2.0,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'SẮC BAN KHẮC TÊN',
                                    style: AppTypography.headingMedium.copyWith(
                                      color: AppColors.redPrimary,
                                      letterSpacing: 3.0,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ĐẠI TRIỆU KHOA THI SỬ VIỆT 2026',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.goldDark,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),

                              // Thân sắc phong: Tên người học & Phẩm hàm
                              Column(
                                children: [
                                  Text(
                                    'Khâm ban Sĩ tử',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondaryLight,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    studentName.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.headingLarge.copyWith(
                                      color: AppColors.textPrimaryLight,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.goldImperial.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.goldImperial, width: 1.2),
                                    ),
                                    child: Text(
                                      rankTitle.toUpperCase(),
                                      style: AppTypography.labelLarge.copyWith(
                                        color: AppColors.goldDark,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    rankStage,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.redPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tích luỹ $xp Điểm Công Đức Sử Học',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondaryLight,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),

                              // Châm ngôn & Dấu triện đỏ
                              Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgAlt,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.goldImperial.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      '“$motto”',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.redPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'HISTORIAI APP',
                                            style: AppTypography.caption.copyWith(
                                              color: AppColors.goldDark,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.0,
                                              fontSize: 9.5,
                                            ),
                                          ),
                                          Text(
                                            'Di sản sử học tương tác',
                                            style: AppTypography.caption.copyWith(
                                              color: AppColors.textSecondaryLight,
                                              fontSize: 8.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const RoyalSealStamp(
                                        text: 'CHUẨN',
                                        subtext: 'ĐẠI VIỆT',
                                        size: 58,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Các nút hành động bên dưới
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Sao Chép Vinh Quy',
                      icon: Icons.share_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                          text: 'Ta là $studentName, đã đỗ đạt danh hiệu $rankTitle ($rankStage) trên nền tảng Sử học HistoriAI! Cùng vào đàm đạo sử Việt nhé!',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép lời tuyên sắc! Hãy dán để chia sẻ Story nhé!'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white24,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper mở Bằng Sắc Phong Story 9:16
void showScholarlyCertificateDialog(
  BuildContext context, {
  required String studentName,
  required String rankTitle,
  required String rankStage,
  required int xp,
  String motto = 'Hiền tài là nguyên khí của quốc gia',
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (_) => ScholarlyCertificateDialog(
      studentName: studentName,
      rankTitle: rankTitle,
      rankStage: rankStage,
      xp: xp,
      motto: motto,
    ),
  );
}
