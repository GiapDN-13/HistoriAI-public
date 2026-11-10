import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils/motion_preferences.dart';

class AnimatedTimelineNode extends StatefulWidget {
  const AnimatedTimelineNode({
    super.key,
    required this.revealed,
    required this.lineProgress,
    required this.isLast,
    required this.child,
  });

  final bool revealed;
  final double lineProgress;
  final bool isLast;
  final Widget child;

  @override
  State<AnimatedTimelineNode> createState() => _AnimatedTimelineNodeState();
}

class _AnimatedTimelineNodeState extends State<AnimatedTimelineNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MotionPreferences.reduce(context);
    if (_reduceMotion) {
      _controller.value = 1;
    } else if (widget.revealed && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedTimelineNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.revealed && widget.revealed) {
      if (_reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lineProgress =
        _reduceMotion ? 1.0 : widget.lineProgress.clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned(
          left: 14.75,
          top: 38,
          bottom: widget.isLast ? 20 : 0,
          width: 2.5,
          child: widget.isLast
              ? const SizedBox.shrink()
              : CustomPaint(
                  painter: _TimelineLinePainter(progress: lineProgress),
                ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final t = _controller.value.clamp(0.0, 1.0);
                    final pulse = t < 0.7
                        ? 1 +
                            0.08 *
                                Curves.easeOut
                                    .transform((t / 0.7).clamp(0.0, 1.0))
                        : 1.08 -
                            0.08 *
                                Curves.easeIn.transform(
                                    ((t - 0.7) / 0.3).clamp(0.0, 1.0));
                    return Transform.scale(
                      scale: _reduceMotion ? 1 : pulse,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.goldBright,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.red, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: AnimatedBuilder(
                  animation: _controller,
                  child: widget.child,
                  builder: (context, child) {
                    final t =
                        _reduceMotion ? 1.0 : _controller.value.clamp(0.0, 1.0);
                    return Opacity(
                      opacity: 0.72 + 0.28 * t,
                      child: Transform.translate(
                        offset: Offset(0, 6 * (1 - t)),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimelineLinePainter extends CustomPainter {
  const _TimelineLinePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.12)
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      track,
    );

    final paintedHeight = size.height * progress.clamp(0.0, 1.0);
    if (paintedHeight <= 0) return;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.gold,
          AppColors.gold.withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, paintedHeight),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelineLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
