import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/motion_preferences.dart';
export 'animated_streak_fire.dart';

/// Hoạ tiết mặt Trống Đồng Ngọc Lũ làm nền, dựng từ
/// `assets/brand/dong_son_drum.png` — ảnh chỉ có kênh alpha, màu do
/// [DongSonBackground.color] quyết định nên luôn khớp bộ nhận diện.
///
/// Nguồn ảnh và giấy phép CC BY-SA 3.0: xem `assets/brand/CREDITS.md`.
/// Để độ mờ 3–4% cho nền trang nhã mà không cản đọc chữ.
class DongSonBackground extends StatelessWidget {
  const DongSonBackground({
    super.key,
    this.child,
    this.opacity = 0.04,
    this.size = 360,
    this.color,
  });

  final Widget? child;
  final double opacity;
  final double size;

  /// Màu hoạ tiết. Bỏ trống thì lấy đỏ son của bộ nhận diện.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final drum = _PulsingDongSonDrum(
      opacity: opacity,
      size: size,
      color: color ?? AppColors.red,
    );

    if (child == null) {
      return SizedBox(
        width: size,
        height: size,
        child: drum,
      );
    }

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          top: -size * 0.2,
          right: -size * 0.2,
          width: size,
          height: size,
          child: IgnorePointer(child: drum),
        ),
        // KHÔNG đặt lớp hạt lửa (EmberLayer) ở đây nữa (21/10): hoạ tiết này bọc ~15
        // màn, mỗi màn một iframe hạt lửa → đo trên bản dựng, CPU chậm 4×: trang chủ
        // sau khi lướt các tab có 6 iframe, mỗi khung 33–36 ms (≈28 hình/giây) so với
        // ~21 ms khi tắt. Góp ý 04/10: "điều hướng giật lag lắm, không có mượt".
        // Hạt lửa giờ chỉ còn ở trang chủ (dashboard_screen.dart).
        child!,
      ],
    );
  }
}

class _PulsingDongSonDrum extends StatefulWidget {
  const _PulsingDongSonDrum({
    required this.opacity,
    required this.size,
    required this.color,
  });

  final double opacity;
  final double size;
  final Color color;

  @override
  State<_PulsingDongSonDrum> createState() => _PulsingDongSonDrumState();
}

class _PulsingDongSonDrumState extends State<_PulsingDongSonDrum>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;
  bool _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MotionPreferences.reduce(context);
    // `TickerMode.of` is the public API for checking whether animations are
    // enabled for this subtree.  It also registers this state as a dependent,
    // so didChangeDependencies runs when the mode changes.
    final tickerEnabled = TickerMode.of(context);
    if (_reduceMotion == reduceMotion &&
        _tickerEnabled == tickerEnabled &&
        (_controller.isAnimating || reduceMotion || !tickerEnabled)) {
      return;
    }
    _reduceMotion = reduceMotion;
    _tickerEnabled = tickerEnabled;
    if (reduceMotion || !tickerEnabled) {
      _controller.stop();
      if (reduceMotion) _controller.value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paintedDrum = RepaintBoundary(
      child: Opacity(
        opacity: widget.opacity,
        child: Image.asset(
          'assets/brand/dong_son_drum.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          // Ảnh chỉ mang kênh alpha; srcIn phủ màu thương hiệu lên phần
          // hoạ tiết và giữ nguyên nền trong suốt.
          color: widget.color,
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );

    return ExcludeSemantics(
      child: _reduceMotion
          ? paintedDrum
          : AnimatedBuilder(
              animation: _controller,
              child: paintedDrum,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _controller.value * math.pi * 2,
                  child: child,
                );
              },
            ),
    );
  }
}

/// Con dấu Triện Hoàng Gia (Royal Seal) - Dập xuống khi trả lời đúng Quiz.
/// Đem lại cảm giác công nhận trang trọng đậm chất sử Việt.
class RoyalSealStamp extends StatefulWidget {
  const RoyalSealStamp({
    super.key,
    this.text = 'CHUẨN',
    this.subtext = 'ĐẠI VIỆT',
    this.size = 80,
    this.width,
    this.height,
    this.onCompleted,
  });

  final String text;
  final String subtext;
  final double size;
  final double? width;
  final double? height;
  final VoidCallback? onCompleted;

  @override
  State<RoyalSealStamp> createState() => _RoyalSealStampState();
}

class _RoyalSealStampState extends State<RoyalSealStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;
  late final Animation<double> _impact;
  late final Animation<double> _opacity;
  bool _started = false;
  bool _completed = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.98), weight: 72),
      TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.0), weight: 28),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _rotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.8), weight: 72),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 28),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _impact = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -2.0, end: 1.5), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: -0.5), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.5, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, 0.22, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MotionPreferences.reduce(context);
    if (_started && _reduceMotion == reduceMotion) return;
    _started = true;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _ctrl.value = 1;
      _notifyCompleted();
    } else {
      _ctrl.forward(from: 0).then((_) => _notifyCompleted());
    }
  }

  void _notifyCompleted() {
    if (_completed) return;
    _completed = true;
    widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = widget.width ?? widget.size;
    final effectiveHeight = widget.height ?? widget.size;

    return SizedBox(
      width: effectiveWidth * 1.12,
      height: effectiveHeight * 1.12,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final progress = _reduceMotion ? 1.0 : _ctrl.value;
          return Transform.translate(
            offset: Offset(_reduceMotion ? 0 : _impact.value, 0),
            child: Transform.rotate(
              angle: (_reduceMotion ? 0 : _rotation.value) * math.pi / 180,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (!_reduceMotion && progress > 0.18 && progress < 0.82)
                    ExcludeSemantics(
                      child: IgnorePointer(
                        child: CustomPaint(
                          size: Size(
                              effectiveWidth * 1.12, effectiveHeight * 1.12),
                          painter: _SealGoldDustPainter(progress: progress),
                        ),
                      ),
                    ),
                  Opacity(
                    opacity: _reduceMotion ? 1 : _opacity.value,
                    child: Transform.scale(
                      scale: _reduceMotion ? 1 : _scale.value,
                      child: Container(
                        width: effectiveWidth,
                        height: effectiveHeight,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.goldBright, width: 2.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.red.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.onRed.withValues(alpha: 0.75),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    widget.text,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'PlayfairDisplay',
                                      color: AppColors.onRed,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: effectiveWidth * 0.55,
                                height: 1,
                                color:
                                    AppColors.goldBright.withValues(alpha: 0.8),
                              ),
                              const SizedBox(height: 2),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    widget.subtext,
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      color: AppColors.goldBright,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SealGoldDustPainter extends CustomPainter {
  const _SealGoldDustPainter({required this.progress});

  final double progress;

  static const _particles = <Offset>[
    Offset(-0.42, -0.26),
    Offset(0.44, -0.18),
    Offset(-0.48, 0.22),
    Offset(0.40, 0.30),
    Offset(0.04, -0.48),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final local = ((progress - 0.18) / 0.64).clamp(0.0, 1.0);
    final opacity = math.sin(local * math.pi).clamp(0.0, 1.0) * 0.65;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = AppColors.goldBright.withValues(alpha: opacity);
    for (var i = 0; i < _particles.length; i++) {
      final seed = _particles[i];
      final travel = 0.72 + local * 0.28;
      final point = Offset(
        center.dx + seed.dx * size.width * travel,
        center.dy + seed.dy * size.height * travel,
      );
      canvas.drawCircle(point, i.isEven ? 1.5 : 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SealGoldDustPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Khung viền hoành phi / góc sắc phong cho thẻ danh nhân hoặc sự kiện tiêu biểu.
class ImperialBorderDecoration extends StatelessWidget {
  const ImperialBorderDecoration({
    super.key,
    required this.child,
    this.borderColor = AppColors.gold,
    this.fillColor = AppColors.card,
  });

  final Widget child;
  final Color borderColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: appSoftShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Góc trang trí hoành phi cổ
            Positioned(
              top: 4,
              left: 4,
              child: _CornerAccent(color: borderColor),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Transform.flip(
                flipX: true,
                child: _CornerAccent(color: borderColor),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Transform.flip(
                flipY: true,
                child: _CornerAccent(color: borderColor),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Transform.flip(
                flipX: true,
                flipY: true,
                child: _CornerAccent(color: borderColor),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _CornerAccent extends StatelessWidget {
  const _CornerAccent({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(14, 14),
      painter: _CornerPainter(color: color),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final p = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);

    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ============================================================================
/// HOẠ TIẾT VĂN HOÁ VIỆT NAM MỚI: CHIM LẠC ĐÔNG SƠN & CỜ NGŨ SẮC LỄ HỘI
/// ============================================================================

/// 1. Chim Lạc Đông Sơn — trích từ vành chim trên mặt trống Ngọc Lũ.
///
/// Dùng ảnh `assets/brand/chim_lac.png` thay vì vẽ tay: hoạ tiết Đông Sơn
/// thật là các dải song song có vạch kẻ, mỏ dài và mắt vòng tròn — vẽ lại
/// bằng path ở cỡ nhỏ chỉ ra một đốm đặc, không còn nhận ra con chim.
/// Ảnh chỉ mang kênh alpha nên [color] quyết định màu, luôn khớp bộ nhận diện.
///
/// Nguồn và giấy phép CC BY-SA 3.0: xem `assets/brand/CREDITS.md`.
///
/// **Cỡ tối thiểu nên dùng là 40** — hoạ tiết rất ngang (cao chỉ bằng 0,37
/// bề rộng), dưới mức đó các vạch kẻ trên cánh dính vào nhau.
class ChimLacMotif extends StatelessWidget {
  const ChimLacMotif({
    super.key,
    this.size = 56,
    this.color = AppColors.goldBright,
    this.flip = false,
    this.opacity = 1.0,
  });

  /// Bề rộng hoạ tiết. Chiều cao tự tính theo tỉ lệ gốc của hoạ tiết.
  final double size;
  final Color color;

  /// Lật ngang: mặc định chim bay sang phải.
  final bool flip;
  final double opacity;

  /// Tỉ lệ cao/rộng lấy đúng theo hoạ tiết gốc trên mặt trống.
  static const double _tiLe = 0.537;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.flip(
        flipX: flip,
        child: ExcludeSemantics(
          child: Image.asset(
            'assets/brand/chim_lac.png',
            width: size,
            height: size * _tiLe,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            color: color,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

/// 2. Đàn Chim Lạc bay lượn (Flock of Lac Birds) làm nền watermark trang nhã.
class ChimLacFlightFlock extends StatelessWidget {
  const ChimLacFlightFlock({
    super.key,
    this.width = 220,
    this.color = AppColors.goldBright,
    this.opacity = 0.18,
  });

  final double width;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.35,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 2,
            child: ChimLacMotif(
                size: width * 0.38, color: color, opacity: opacity),
          ),
          Positioned(
            right: width * 0.34,
            top: width * 0.08,
            child: ChimLacMotif(
                size: width * 0.26, color: color, opacity: opacity * 0.8),
          ),
          Positioned(
            right: width * 0.62,
            top: width * 0.02,
            child: ChimLacMotif(
                size: width * 0.20, color: color, opacity: opacity * 0.6),
          ),
        ],
      ),
    );
  }
}

/// 3. Cờ Ngũ Sắc Lễ Hội / Cờ Lệnh Đại Việt (Traditional Vietnamese Festival Flag).
/// Biểu tượng ngàn năm văn hoá hội làng, đền miếu, chiến trận khởi nghĩa:
/// 5 tầng màu ngũ hành (Vàng - Đỏ - Xanh lá - Trắng - Xanh lam) cùng diềm ngọn lửa phấp phới.
class VietnameseFestivalFlag extends StatelessWidget {
  const VietnameseFestivalFlag({
    super.key,
    this.size = 28,
    this.withStaff = true,
  });

  final double size;
  final bool withStaff;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * (withStaff ? 1.35 : 1.0),
      child: CustomPaint(
        size: Size(size, size * (withStaff ? 1.35 : 1.0)),
        painter: _FestivalFlagPainter(withStaff: withStaff),
      ),
    );
  }
}

class _FestivalFlagPainter extends CustomPainter {
  const _FestivalFlagPainter({required this.withStaff});
  final bool withStaff;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final flagHeight = withStaff ? size.height * 0.72 : size.height;
    final flagWidth = w * 0.82;
    final startX = withStaff ? w * 0.16 : 0.0;
    const startY = 4.0;

    // 1. Cán cờ tre / gỗ sơn son
    if (withStaff) {
      final staffPaint = Paint()
        ..color = const Color(0xFF8B4513) // Nâu gỗ mộc
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      // Cán cờ
      canvas.drawLine(
        Offset(startX, 1.0),
        Offset(startX, size.height - 1.0),
        staffPaint,
      );

      // Chóp ngọn giáo / búp sen vàng kim trên đỉnh cán
      final spear = Path()
        ..moveTo(startX, 0)
        ..lineTo(startX - 2.5, 4.5)
        ..lineTo(startX + 2.5, 4.5)
        ..close();
      canvas.drawPath(spear, Paint()..color = AppColors.goldBright);
    }

    // 2. Diềm cờ hình ngọn lửa (Flame fringes / Răng cưa ngọn lửa) ở 3 cạnh tự do
    final fringePaint = Paint()
      ..color = const Color(0xFFE67E22) // Cam đỏ viền lửa
      ..style = PaintingStyle.fill;

    final fringe = Path();
    final rightX = startX + flagWidth;
    final bottomY = startY + flagHeight;

    // Răng cưa cạnh trên
    const teethTop = 4;
    final stepTop = flagWidth / teethTop;
    for (int i = 0; i < teethTop; i++) {
      final x1 = startX + i * stepTop;
      fringe.moveTo(x1, startY);
      fringe.lineTo(x1 + stepTop * 0.5, startY - 3.5);
      fringe.lineTo(x1 + stepTop, startY);
    }

    // Răng cưa cạnh phải
    const teethRight = 5;
    final stepRight = flagHeight / teethRight;
    for (int i = 0; i < teethRight; i++) {
      final y1 = startY + i * stepRight;
      fringe.moveTo(rightX, y1);
      fringe.lineTo(rightX + 4.0, y1 + stepRight * 0.5);
      fringe.lineTo(rightX, y1 + stepRight);
    }

    // Răng cưa cạnh dưới
    for (int i = 0; i < teethTop; i++) {
      final x1 = startX + i * stepTop;
      fringe.moveTo(x1, bottomY);
      fringe.lineTo(x1 + stepTop * 0.5, bottomY + 3.5);
      fringe.lineTo(x1 + stepTop, bottomY);
    }
    canvas.drawPath(fringe, fringePaint);

    // 3. Năm tầng màu đồng tâm ngũ hành chuẩn di sản
    // Tầng 1: Đỏ son ngoài cùng (Hỏa)
    final r1 = Rect.fromLTWH(startX, startY, flagWidth, flagHeight);
    canvas.drawRect(r1, Paint()..color = AppColors.red);

    // Tầng 2: Xanh lục (Mộc)
    final pad2 = flagWidth * 0.12;
    final r2 = Rect.fromLTWH(startX + pad2, startY + pad2, flagWidth - pad2 * 2,
        flagHeight - pad2 * 2);
    canvas.drawRect(r2, Paint()..color = const Color(0xFF1E8449));

    // Tầng 3: Trắng tinh khiết (Kim)
    final pad3 = flagWidth * 0.22;
    final r3 = Rect.fromLTWH(startX + pad3, startY + pad3, flagWidth - pad3 * 2,
        flagHeight - pad3 * 2);
    canvas.drawRect(r3, Paint()..color = const Color(0xFFFDF9F4));

    // Tầng 4: Xanh lam thẫm (Thủy)
    final pad4 = flagWidth * 0.30;
    final r4 = Rect.fromLTWH(startX + pad4, startY + pad4, flagWidth - pad4 * 2,
        flagHeight - pad4 * 2);
    canvas.drawRect(r4, Paint()..color = const Color(0xFF1F4E79));

    // Tầng 5: Vàng hoàng thổ ở trung tâm (Thổ - Trung ương)
    final pad5 = flagWidth * 0.38;
    final r5 = Rect.fromLTWH(startX + pad5, startY + pad5, flagWidth - pad5 * 2,
        flagHeight - pad5 * 2);
    canvas.drawRect(r5, Paint()..color = AppColors.goldBright);

    // Viền chỉ vàng sang trọng quanh cờ
    canvas.drawRect(
      r1,
      Paint()
        ..color = AppColors.goldBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _FestivalFlagPainter oldDelegate) => false;
}

/// 4. Cặp Cờ Lệnh Hội Ngũ Sắc bắt chéo (Double Crossed Ceremonial Flags)
class DoubleFestivalFlags extends StatelessWidget {
  const DoubleFestivalFlags({
    super.key,
    this.size = 36,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.5,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cờ trái nghiêng
          Transform.rotate(
            angle: -0.22,
            child: VietnameseFestivalFlag(size: size * 0.72),
          ),
          // Cờ phải nghiêng đối xứng
          Transform.rotate(
            angle: 0.22,
            child: Transform.flip(
              flipX: true,
              child: VietnameseFestivalFlag(size: size * 0.72),
            ),
          ),
          // Hạt ngọc vàng kết liên chéo ở giữa
          Positioned(
            bottom: size * 0.18,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.goldBright,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x66000000), blurRadius: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cờ lệnh nền Đấu Trường — bản lớn, tĩnh, chỉ dùng như hoạ tiết nền.
/// Năm lớp màu lồng nhau theo cờ ngũ sắc; mép vải khuyết nhẹ tạo cảm giác phấp phới.
class CommandFlagBackgroundMotif extends StatelessWidget {
  const CommandFlagBackgroundMotif({
    super.key,
    this.width = 132,
    this.opacity = 0.09,
    this.flipX = false,
  });

  final double width;
  final double opacity;
  final bool flipX;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.flip(
            flipX: flipX,
            child: SizedBox(
              width: width,
              height: width * 1.34,
              child: CustomPaint(
                painter: const _CommandFlagBackgroundPainter(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandFlagBackgroundPainter extends CustomPainter {
  const _CommandFlagBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final staffX = w * 0.17;
    final clothLeft = staffX + w * 0.025;
    final clothTop = h * 0.11;
    final clothBottom = h * 0.68;
    final clothWidth = w * 0.70;

    // Cán tre/gỗ sẫm, có bóng chỉ để tạo chiều sâu rất nhẹ.
    final staffShadow = Paint()
      ..color = const Color(0xFF3A140E).withValues(alpha: 0.35)
      ..strokeWidth = w * 0.050
      ..strokeCap = StrokeCap.round;
    final staffPaint = Paint()
      ..color = const Color(0xFF6B351D)
      ..strokeWidth = w * 0.032
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(staffX + w * 0.012, h * 0.045),
        Offset(staffX + w * 0.012, h * 0.95), staffShadow);
    canvas.drawLine(
        Offset(staffX, h * 0.04), Offset(staffX, h * 0.94), staffPaint);

    // Chóp giáo/búp sen vàng của cờ lệnh.
    final finial = Path()
      ..moveTo(staffX, h * 0.018)
      ..quadraticBezierTo(staffX - w * 0.045, h * 0.075, staffX, h * 0.105)
      ..quadraticBezierTo(staffX + w * 0.045, h * 0.075, staffX, h * 0.018)
      ..close();
    canvas.drawPath(finial, Paint()..color = AppColors.goldDark);
    canvas.drawCircle(Offset(staffX, h * 0.098), w * 0.025,
        Paint()..color = AppColors.goldBright);

    // Mép vải bay nhẹ; năm dải đồng tâm theo cấu trúc cờ ngũ sắc.
    Path clothPath(double inset) {
      final left = clothLeft + inset;
      final top = clothTop + inset;
      final right = clothLeft + clothWidth - inset;
      final bottom = clothBottom - inset;
      return Path()
        ..moveTo(left, top)
        ..lineTo(right - w * 0.025, top + h * 0.018)
        ..quadraticBezierTo(right + w * 0.038, (top + bottom) * 0.42,
            right - w * 0.015, (top + bottom) * 0.64)
        ..quadraticBezierTo(
            right - w * 0.055, bottom - h * 0.015, right - w * 0.020, bottom)
        ..lineTo(left, bottom - h * 0.018)
        ..close();
    }

    final outer = clothPath(0);
    canvas.drawPath(outer, Paint()..color = AppColors.red);
    canvas.drawPath(
        clothPath(w * 0.055), Paint()..color = const Color(0xFF1E8449));
    canvas.drawPath(
        clothPath(w * 0.112), Paint()..color = AppColors.paperCream);
    canvas.drawPath(
        clothPath(w * 0.168), Paint()..color = const Color(0xFF1F4E79));
    canvas.drawPath(
        clothPath(w * 0.224), Paint()..color = AppColors.goldBright);

    // Chỉ thêu viền và một trục dọc gợi đường nếp vải, không thêm text/biểu tượng giả sử liệu.
    final seam = Paint()
      ..color = AppColors.goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.009
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(outer, seam);
    canvas.drawLine(
      Offset(clothLeft + clothWidth * 0.48, clothTop + h * 0.018),
      Offset(clothLeft + clothWidth * 0.46, clothBottom - h * 0.025),
      seam..color = AppColors.goldBright.withValues(alpha: 0.65),
    );

    // Hai tua lụa nhỏ gợi cờ lệnh, dừng trước phần cán để nền vẫn tối giản.
    final tassel = Paint()
      ..color = AppColors.redDark
      ..strokeWidth = w * 0.020
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(staffX - w * 0.012, h * 0.91),
        Offset(staffX - w * 0.065, h * 0.98), tassel);
    canvas.drawLine(Offset(staffX + w * 0.012, h * 0.91),
        Offset(staffX + w * 0.080, h * 0.97), tassel);
  }

  @override
  bool shouldRepaint(covariant _CommandFlagBackgroundPainter oldDelegate) =>
      false;
}

/// 5. Dải hoa văn diềm Đông Sơn sóng nước & Chim Lạc chạy ngang (Dong Son Wave Ribbon)
class DongSonWaveDivider extends StatelessWidget {
  const DongSonWaveDivider({
    super.key,
    this.color = AppColors.gold,
    this.height = 18,
    this.opacity = 0.55,
  });

  final Color color;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _DongSonWavePainter(color: color),
        ),
      ),
    );
  }
}

class _DongSonWavePainter extends CustomPainter {
  const _DongSonWavePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Đường kẻ trên và dưới
    canvas.drawLine(Offset(0, 1), Offset(w, 1), paint);
    canvas.drawLine(Offset(0, h - 1), Offset(w, h - 1), paint);

    // Chuỗi hình thoi mắt công và sóng nước Đại Việt
    const step = 20.0;
    final count = (w / step).ceil();
    for (int i = 0; i < count; i++) {
      final x = i * step;
      final diamond = Path()
        ..moveTo(x, midY)
        ..lineTo(x + step * 0.5, 3)
        ..lineTo(x + step, midY)
        ..lineTo(x + step * 0.5, h - 3)
        ..close();
      canvas.drawPath(diamond, paint);

      // Chấm tâm hình thoi
      canvas.drawCircle(
          Offset(x + step * 0.5, midY), 1.1, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _DongSonWavePainter oldDelegate) => false;
}
