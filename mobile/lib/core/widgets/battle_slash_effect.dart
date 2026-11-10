import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/motion_preferences.dart';

class BattleSlashEffect extends StatelessWidget {
  const BattleSlashEffect({
    super.key,
    required this.animation,
    required this.isCorrect,
  });

  final Animation<double> animation;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    if (MotionPreferences.reduce(context)) return const SizedBox.shrink();

    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) => CustomPaint(
              painter: _BattleSlashPainter(
                progress: animation.value,
                isCorrect: isCorrect,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _BattleSlashPainter extends CustomPainter {
  const _BattleSlashPainter({
    required this.progress,
    required this.isCorrect,
  });

  final double progress;
  final bool isCorrect;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final travel = Curves.easeOutCubic.transform((progress / 0.72).clamp(0, 1));
    final fade = progress < 0.58 ? 1.0 : (1 - progress) / 0.42;
    final alpha = (fade * (isCorrect ? 0.82 : 0.44)).clamp(0.0, 1.0);
    final start = Offset(size.width * 0.12, size.height * 0.78);
    final target = Offset(size.width * 0.88, size.height * 0.22);
    final end = Offset.lerp(start, target, travel)!;

    final halo = Paint()
      ..color = AppColors.goldBright.withValues(alpha: alpha * 0.42)
      ..strokeWidth = isCorrect ? 8 : 5
      ..strokeCap = StrokeCap.round;
    final core = Paint()
      ..color = AppColors.goldBright.withValues(alpha: alpha)
      ..strokeWidth = isCorrect ? 2.2 : 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, halo);
    canvas.drawLine(start, end, core);

    if (isCorrect && progress > 0.42 && progress < 0.8) {
      final flash = mathPulse((progress - 0.42) / 0.38);
      canvas.drawCircle(
        target,
        8 + 6 * flash,
        Paint()..color = AppColors.goldBright.withValues(alpha: 0.2 * flash),
      );
    }
  }

  double mathPulse(double value) {
    final t = value.clamp(0.0, 1.0);
    return t < 0.5 ? t * 2 : (1 - t) * 2;
  }

  @override
  bool shouldRepaint(covariant _BattleSlashPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isCorrect != isCorrect;
}
