import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/motion_preferences.dart';
import 'scholarly_certificate_dialog.dart';
import 'vietnamese_decorations.dart';

/// Hạt bụi vàng lấp lánh (Golden Sparkles)
class GoldParticle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;

  GoldParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class GoldParticlePainter extends CustomPainter {
  final List<GoldParticle> particles;
  final double animationValue;

  GoldParticlePainter({required this.particles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final currentY = (p.y - animationValue * p.speed * 80) % size.height;
      final currentX = p.x + math.sin(animationValue * 2 * math.pi + p.y) * 12;
      paint.color = AppColors.goldImperial.withValues(
          alpha: (p.opacity * (0.4 + 0.6 * math.sin(animationValue * math.pi)))
              .clamp(0.0, 1.0));
      canvas.drawCircle(Offset(currentX % size.width, currentY), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GoldParticlePainter oldDelegate) => true;
}

/// Trục cuốn sớ bằng gỗ mun khảm vàng
class ScrollRollerPainter extends CustomPainter {
  final bool isLeft;

  ScrollRollerPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    // Trục gỗ chính
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final woodGradient = LinearGradient(
      begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
      end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      colors: const [
        Color(0xFF5D4037),
        Color(0xFF271510),
        Color(0xFF8D6E63),
        Color(0xFF1E100C),
      ],
      stops: const [0.0, 0.4, 0.7, 1.0],
    );
    final woodPaint = Paint()..shader = woodGradient.createShader(rect);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)), woodPaint);

    // Núm vàng trang trí ở hai đầu trên và dưới
    final goldPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          AppColors.goldLight,
          AppColors.goldImperial,
          AppColors.goldDark
        ],
      ).createShader(rect);

    // Núm trên
    canvas.drawOval(Rect.fromLTWH(-2, -8, size.width + 4, 16), goldPaint);
    // Núm dưới
    canvas.drawOval(
        Rect.fromLTWH(-2, size.height - 8, size.width + 4, 16), goldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Viền cuộn giấy cổ truyền với hoa cúc dây mạ vàng
class ScrollBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = AppColors.goldImperial.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Đường viền kép trên và dưới
    canvas.drawLine(const Offset(8, 6), Offset(size.width - 8, 6), goldPaint);
    canvas.drawLine(const Offset(8, 10), Offset(size.width - 8, 10), goldPaint);
    canvas.drawLine(Offset(8, size.height - 6),
        Offset(size.width - 8, size.height - 6), goldPaint);
    canvas.drawLine(Offset(8, size.height - 10),
        Offset(size.width - 8, size.height - 10), goldPaint);

    // Họa tiết hoa văn góc
    const cornerSize = 14.0;
    // Góc trên trái
    canvas.drawLine(const Offset(8, 10),
        const Offset(8 + cornerSize, 10 + cornerSize), goldPaint);
    // Góc trên phải
    canvas.drawLine(Offset(size.width - 8, 10),
        Offset(size.width - 8 - cornerSize, 10 + cornerSize), goldPaint);
    // Góc dưới trái
    canvas.drawLine(Offset(8, size.height - 10),
        Offset(8 + cornerSize, size.height - 10 - cornerSize), goldPaint);
    // Góc dưới phải
    canvas.drawLine(
        Offset(size.width - 8, size.height - 10),
        Offset(size.width - 8 - cornerSize, size.height - 10 - cornerSize),
        goldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cuộn Sớ Chiếu Thư / Sắc Phong Hoàng Gia
class RoyalEdictScrollDialog extends StatefulWidget {
  final String title;
  final String recipient;
  final String rankTitle;
  final String body;
  final String motto;
  final String sealText;

  const RoyalEdictScrollDialog({
    super.key,
    required this.title,
    required this.recipient,
    required this.rankTitle,
    required this.body,
    this.motto = 'Hiền tài là nguyên khí của quốc gia',
    this.sealText = 'SẮC MỆNH CHI BẢO',
  });

  @override
  State<RoyalEdictScrollDialog> createState() => _RoyalEdictScrollDialogState();
}

class _RoyalEdictScrollDialogState extends State<RoyalEdictScrollDialog>
    with TickerProviderStateMixin {
  late final AnimationController _openController;
  late final Animation<double> _paperAnimation;
  late final Animation<double> _contentAnimation;

  late final AnimationController _sparkleController;
  late final List<GoldParticle> _particles;

  bool _showSeal = false;
  bool _motionStarted = false;
  bool _reduceMotion = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _paperAnimation = CurvedAnimation(
      parent: _openController,
      curve: const Interval(0, 0.78, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    _contentAnimation = CurvedAnimation(
      parent: _openController,
      curve: const Interval(0.25, 1, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Sinh hạt bụi vàng ngẫu nhiên
    final random = math.Random();
    _particles = List.generate(24, (index) {
      return GoldParticle(
        x: random.nextDouble() * 360,
        y: random.nextDouble() * 600,
        size: 1.5 + random.nextDouble() * 2.5,
        speed: 0.5 + random.nextDouble() * 0.8,
        opacity: 0.3 + random.nextDouble() * 0.6,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionStarted) return;
    _motionStarted = true;
    _reduceMotion = MotionPreferences.reduce(context);
    if (_reduceMotion) {
      _openController.value = 1;
      _sparkleController.value = 0;
      _showSeal = true;
      return;
    }
    _sparkleController.repeat();
    _openController.forward().then((_) {
      if (!mounted) return;
      setState(() => _showSeal = true);
    });
  }

  @override
  void dispose() {
    _openController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  Future<void> _close([VoidCallback? afterClose]) async {
    if (_closing) return;
    setState(() => _closing = true);
    _sparkleController.stop();
    final navigator = Navigator.of(context);
    if (!_reduceMotion && _openController.value > 0) {
      setState(() => _showSeal = false);
      await _openController.reverse();
    }
    if (!navigator.mounted) return;
    navigator.pop();
    if (afterClose != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => afterClose());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: IgnorePointer(
        ignoring: _closing,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 680),
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _paperAnimation,
                  _contentAnimation,
                  _sparkleController,
                ]),
                builder: (context, child) {
                  final paperProgress = _paperAnimation.value;
                  final contentProgress = _contentAnimation.value;
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Hạt bụi vàng lơ lửng xung quanh
                      Positioned.fill(
                        child: CustomPaint(
                          painter: GoldParticlePainter(
                            particles: _particles,
                            animationValue: _sparkleController.value,
                          ),
                        ),
                      ),

                      // Toàn bộ thân sớ mở dọc như một cuộn chiếu cổ.
                      Opacity(
                        opacity: paperProgress,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: paperProgress,
                            child: Container(
                              width: 380,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: AppColors.paperCream,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.goldImperial
                                        .withValues(alpha: 0.35),
                                    blurRadius: 28,
                                    spreadRadius: 4,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Nền trống đồng mờ bên trong giấy dó
                                  const Positioned.fill(
                                    child: Opacity(
                                      opacity: 0.05,
                                      child: DongSonBackground(),
                                    ),
                                  ),

                                  // Viền hoa văn cung đình
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: ScrollBorderPainter(),
                                    ),
                                  ),

                                  // Nội dung văn tự hiện sau lớp giấy.
                                  Opacity(
                                    opacity: contentProgress,
                                    child: Transform.translate(
                                      offset:
                                          Offset(0, 5 * (1 - contentProgress)),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            26, 32, 26, 24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Tiêu đề đầu sớ
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.redDeepest,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                    color:
                                                        AppColors.goldImperial,
                                                    width: 1.2),
                                              ),
                                              child: Text(
                                                widget.title,
                                                style: AppTypography
                                                    .headingSmall
                                                    .copyWith(
                                                  color: AppColors.goldLight,
                                                  letterSpacing: 2.0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 16),

                                            // Phụng mệnh tuyên sắc
                                            Text(
                                              'SẮC BAN ĐẠI PHONG',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                color: AppColors.redPrimary,
                                                letterSpacing: 3.0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),

                                            // Tên người nhận & Danh vị
                                            Text(
                                              widget.recipient,
                                              style: AppTypography.headingMedium
                                                  .copyWith(
                                                color:
                                                    AppColors.textPrimaryLight,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.goldImperial
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                    color: AppColors
                                                        .goldImperial
                                                        .withValues(
                                                            alpha: 0.5)),
                                              ),
                                              child: Text(
                                                widget.rankTitle,
                                                style: AppTypography.bodySmall
                                                    .copyWith(
                                                  color: AppColors.goldDark,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 18),

                                            // Nội dung chiếu thư
                                            Flexible(
                                              child: SingleChildScrollView(
                                                child: Text(
                                                  widget.body,
                                                  textAlign: TextAlign.center,
                                                  style: AppTypography
                                                      .bodyMedium
                                                      .copyWith(
                                                    color: AppColors
                                                        .textPrimaryLight
                                                        .withValues(alpha: 0.9),
                                                    height: 1.65,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 16),

                                            // Lời răn dạy của cổ nhân
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppColors.redDeepest
                                                    .withValues(alpha: 0.05),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: AppColors
                                                        .goldImperial
                                                        .withValues(
                                                            alpha: 0.3)),
                                              ),
                                              child: Text(
                                                '“${widget.motto}”',
                                                textAlign: TextAlign.center,
                                                style: AppTypography.caption
                                                    .copyWith(
                                                  color: AppColors.redPrimary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 20),

                                            // Khu vực ấn triện và nút đóng
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                // Dấu triện hoàng gia
                                                Flexible(
                                                  child: Align(
                                                    alignment:
                                                        Alignment.bottomLeft,
                                                    child: AnimatedScale(
                                                      scale:
                                                          _showSeal ? 1.0 : 0.2,
                                                      duration: const Duration(
                                                          milliseconds: 400),
                                                      curve: Curves.elasticOut,
                                                      child: AnimatedOpacity(
                                                        opacity: _showSeal
                                                            ? 1.0
                                                            : 0.0,
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    300),
                                                        child: RoyalSealStamp(
                                                          text: widget.sealText,
                                                          size: 64,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),

                                                // Nút hành động gọn để không lấn ấn triện.
                                                IconButton(
                                                  tooltip:
                                                      'Xuất Bằng 9:16 Story',
                                                  icon: const Icon(
                                                      Icons.share_rounded,
                                                      color: AppColors.goldDark,
                                                      size: 20),
                                                  onPressed: () {
                                                    final navigatorContext =
                                                        Navigator.of(context)
                                                            .context;
                                                    _close(() {
                                                      showScholarlyCertificateDialog(
                                                        navigatorContext,
                                                        studentName:
                                                            widget.recipient,
                                                        rankTitle:
                                                            widget.rankTitle,
                                                        rankStage:
                                                            'Đại Triệu Khoa Bảng',
                                                        xp: 350,
                                                        motto: widget.motto,
                                                      );
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 2),
                                                IconButton.filled(
                                                  tooltip: 'Kính Tuân Chỉ',
                                                  style: IconButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.redPrimary,
                                                    foregroundColor:
                                                        AppColors.onRed,
                                                  ),
                                                  icon: const Icon(
                                                    Icons
                                                        .check_circle_outline_rounded,
                                                    size: 20,
                                                  ),
                                                  onPressed: _close,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Trục cuốn giữ nguyên bề ngang, chỉ theo lớp giấy mở dọc.
                      Positioned(
                        left: -4,
                        top: 12,
                        bottom: 12,
                        width: 20,
                        child: CustomPaint(
                          painter: ScrollRollerPainter(isLeft: true),
                        ),
                      ),

                      // Trục cuốn phải
                      Positioned(
                        right: -4,
                        top: 12,
                        bottom: 12,
                        width: 20,
                        child: CustomPaint(
                          painter: ScrollRollerPainter(isLeft: false),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper hiển thị Chiếu Thư Hoàng Gia
Future<void> showRoyalEdictDialog(
  BuildContext context, {
  required String title,
  required String recipient,
  required String rankTitle,
  required String body,
  String motto = 'Hiền tài là nguyên khí của quốc gia',
  String sealText = 'SẮC MỆNH CHI BẢO',
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (context) => RoyalEdictScrollDialog(
      title: title,
      recipient: recipient,
      rankTitle: rankTitle,
      body: body,
      motto: motto,
      sealText: sealText,
    ),
  );
}
