import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hoạt ảnh ngọn lửa bốc cháy chuyển động cho chỉ số Chuỗi ngày (Streak).
/// Sử dụng bảng màu vàng cam rực rỡ đặc trưng của streak lửa (Fire Orange -> Amber Gold),
/// kết hợp 2 tầng lửa lượn sóng (Outer Flame + Inner Core) và các tia lửa li ti bốc lên.
class AnimatedStreakFire extends StatefulWidget {
  const AnimatedStreakFire({
    super.key,
    this.size = 20.0,
    this.showSparks = true,
  });

  final double size;
  final bool showSparks;

  @override
  State<AnimatedStreakFire> createState() => _AnimatedStreakFireState();
}

class _AnimatedStreakFireState extends State<AnimatedStreakFire>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return _buildStaticFire(widget.size);
    }

    final size = widget.size;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value * 2 * math.pi;

        // Nhịp thở & co giãn ngọn lửa
        final scaleY = 1.0 + 0.08 * math.sin(t * 2);
        final scaleX = 1.0 - 0.04 * math.sin(t * 2);
        final sway = 0.045 * math.sin(t);

        // Lớp lửa lõi bên trong lệch pha
        final innerScaleY = 1.0 + 0.12 * math.sin(t * 2.5 + 0.8);
        final innerSway = -0.05 * math.sin(t * 1.8 + 0.5);

        // Hào quang bập bùng
        final glowPulse = (math.sin(t * 2) + 1.0) / 2.0;

        return SizedBox(
          width: size + 6,
          height: size + 6,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Hào quang lửa vàng cam tỏa sáng phía sau
              Container(
                width: size * 0.9,
                height: size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6D00)
                          .withValues(alpha: 0.28 + 0.22 * glowPulse),
                      blurRadius: 8 + 4 * glowPulse,
                      spreadRadius: 1 + 2 * glowPulse,
                    ),
                  ],
                ),
              ),

              // Tia lửa li ti bốc lên
              if (widget.showSparks)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FireSparksPainter(
                      progress: _ctrl.value,
                      flameSize: size,
                    ),
                  ),
                ),

              // Lớp ngọn lửa chính (Vàng cam rực rỡ)
              Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0)
                  ..rotateZ(sway),
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFFFF3D00), // Đỏ cam đậm đáy lửa
                      Color(0xFFFF8F00), // Cam rực rỡ
                      Color(0xFFFFD54F), // Vàng hoàng kim đỉnh ngọn
                    ],
                    stops: [0.0, 0.52, 1.0],
                  ).createShader(bounds),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: size,
                    color: Colors.white,
                  ),
                ),
              ),

              // Lõi lửa trong rực sáng (Tâm vàng sáng - trắng)
              Positioned(
                bottom: 3,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(1.0, innerScaleY, 1.0)
                    ..rotateZ(innerSway),
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xFFFFA000), // Vàng cam ấm
                        Color(0xFFFFF59D), // Vàng chanh sáng
                        Color(0xFFFFFFFF), // Trắng tâm lửa
                      ],
                      stops: [0.0, 0.65, 1.0],
                    ).createShader(bounds),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      size: size * 0.60,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaticFire(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xFFFF3D00),
            Color(0xFFFF8F00),
            Color(0xFFFFD54F),
          ],
        ).createShader(bounds),
        child: Icon(
          Icons.local_fire_department_rounded,
          size: size,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Vẽ 3 tia lửa nhỏ li ti bay bốc lên từ ngọn lửa
class _FireSparksPainter extends CustomPainter {
  _FireSparksPainter({
    required this.progress,
    required this.flameSize,
  });

  final double progress;
  final double flameSize;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final baseY = size.height * 0.45;

    // Hạt 1
    _drawSpark(
      canvas: canvas,
      phase: (progress + 0.0) % 1.0,
      centerX: centerX - 2.5,
      baseY: baseY,
      horizontalDrift: 3.5,
      color: const Color(0xFFFFE082),
      radius: 1.1,
    );

    // Hạt 2
    _drawSpark(
      canvas: canvas,
      phase: (progress + 0.38) % 1.0,
      centerX: centerX + 3.0,
      baseY: baseY,
      horizontalDrift: -3.0,
      color: const Color(0xFFFFB300),
      radius: 1.3,
    );

    // Hạt 3
    _drawSpark(
      canvas: canvas,
      phase: (progress + 0.72) % 1.0,
      centerX: centerX,
      baseY: baseY,
      horizontalDrift: 2.0,
      color: const Color(0xFFFF8F00),
      radius: 0.9,
    );
  }

  void _drawSpark({
    required Canvas canvas,
    required double phase,
    required double centerX,
    required double baseY,
    required double horizontalDrift,
    required Color color,
    required double radius,
  }) {
    // phase: 0.0 -> 1.0
    final y = baseY - phase * (flameSize * 0.65);
    final x = centerX + math.sin(phase * math.pi * 2) * horizontalDrift;
    final opacity = math.sin(phase * math.pi).clamp(0.0, 1.0);
    final currentRadius = radius * (1.0 - phase * 0.4);

    final paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.85)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), currentRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _FireSparksPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
