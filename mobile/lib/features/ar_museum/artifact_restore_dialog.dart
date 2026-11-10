import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_widgets.dart';

/// Lớp sơn phủ bụi thời gian và cọ quét phục chế
class DustScrubPainter extends CustomPainter {
  final List<Offset> points;
  final double brushRadius;
  final bool isRestored;

  DustScrubPainter({
    required this.points,
    this.brushRadius = 28.0,
    required this.isRestored,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isRestored) return; // Nếu đã phục chế xong thì xóa sạch lớp bụi

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.saveLayer(rect, Paint());

    // 1. Vẽ lớp bụi đất ngàn năm
    final dustPaint = Paint()
      ..color = const Color(0xFF6D543C).withValues(alpha: 0.94)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, dustPaint);

    // Vẽ thêm vết rạn nứt rêu phong cổ kính
    final crackPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width * 0.2, 0), Offset(size.width * 0.4, size.height * 0.5), crackPaint);
    canvas.drawLine(Offset(size.width * 0.4, size.height * 0.5), Offset(size.width * 0.35, size.height), crackPaint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.6, size.height * 0.6), crackPaint);

    // 2. Dùng BlendMode.clear để xóa lớp bụi tại các điểm đã chạm vuốt
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, brushRadius, clearPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DustScrubPainter oldDelegate) {
    return oldDelegate.points.length != points.length || oldDelegate.isRestored != isRestored;
  }
}

/// Dialog mini-game: Phục Dựng Cổ Vật - Quét Bụi Thời Gian
class ArtifactRestoreDialog extends StatefulWidget {
  final String artifactTitle;
  final String artifactPeriod;
  final String? imageUrl;
  final String description;

  const ArtifactRestoreDialog({
    super.key,
    required this.artifactTitle,
    required this.artifactPeriod,
    this.imageUrl,
    required this.description,
  });

  @override
  State<ArtifactRestoreDialog> createState() => _ArtifactRestoreDialogState();
}

class _ArtifactRestoreDialogState extends State<ArtifactRestoreDialog>
    with SingleTickerProviderStateMixin {
  final List<Offset> _scrubPoints = [];
  double _restoredPercentage = 0.0;
  bool _isComplete = false;

  late final AnimationController _celebrationController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glowAnimation = CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  void _addPoint(Offset localPosition, Size canvasSize) {
    if (_isComplete) return;

    setState(() {
      _scrubPoints.add(localPosition);
      // Ước tính phần trăm đã quét dựa trên số điểm vuốt phân tán
      _restoredPercentage = math.min(1.0, _scrubPoints.length / 55.0);

      if (_restoredPercentage >= 0.75 && !_isComplete) {
        _isComplete = true;
        _celebrationController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
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
                  color: AppColors.goldImperial.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tiêu đề
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_fix_high_rounded,
                            color: AppColors.goldDark,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PHỤC DỰNG BẢO VẬT',
                            style: AppTypography.headingSmall.copyWith(
                              color: AppColors.redPrimary,
                              letterSpacing: 1.5,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondaryLight),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  Text(
                    'Dùng ngón tay quét lớp bụi phong rêu nghìn năm để phục chế',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Khung tương tác quét bụi
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.redDeepest,
                        border: Border.all(
                          color: AppColors.goldImperial.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                          return GestureDetector(
                            onPanDown: (details) => _addPoint(details.localPosition, canvasSize),
                            onPanUpdate: (details) => _addPoint(details.localPosition, canvasSize),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // 1. Cổ vật nguyên bản bên dưới
                                CoverImage(
                                  url: widget.imageUrl,
                                  height: 220,
                                ),

                                // 2. Lớp bụi đất CustomPainter
                                CustomPaint(
                                  size: canvasSize,
                                  painter: DustScrubPainter(
                                    points: _scrubPoints,
                                    isRestored: _isComplete,
                                  ),
                                ),

                                // 3. Hiệu ứng bừng sáng khi hoàn thành
                                if (_isComplete)
                                  AnimatedBuilder(
                                    animation: _glowAnimation,
                                    builder: (context, child) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: RadialGradient(
                                            colors: [
                                              AppColors.goldLight.withValues(alpha: 0.5 * (1 - _glowAnimation.value)),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Transform.scale(
                                          scale: _glowAnimation.value,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: AppColors.redDeepest,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: AppColors.goldLight, width: 2),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: AppColors.goldImperial,
                                                  blurRadius: 16,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              '✨ PHỤC DỰNG THÀNH CÔNG! ✨',
                                              style: AppTypography.labelLarge.copyWith(
                                                color: AppColors.goldLight,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Thanh đo tiến độ phục chế
                  Row(
                    children: [
                      Text(
                        'Độ sáng tỏ:',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _isComplete ? 1.0 : _restoredPercentage,
                            backgroundColor: AppColors.paperCreamDark,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _isComplete ? AppColors.goldDark : AppColors.redPrimary,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(_isComplete ? 100 : _restoredPercentage * 100).toInt()}%',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.redPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Tên bảo vật & thời kỳ
                  Text(
                    widget.artifactTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.headingSmall.copyWith(
                      color: AppColors.textPrimaryLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.artifactPeriod,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.goldDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Nút đóng / nhận thưởng
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: _isComplete ? 'Hoàn tất phục chế' : 'Tiếp tục phục chế',
                      icon: _isComplete ? Icons.verified_rounded : Icons.gesture_rounded,
                      variant: _isComplete ? AppButtonVariant.primary : AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
