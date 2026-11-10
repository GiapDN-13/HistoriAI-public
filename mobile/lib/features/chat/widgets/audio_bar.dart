import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Thanh phát âm thanh trong bong bóng bot — khớp mockup:
/// [▶/⏸] + dải sóng âm + thời lượng. Tự animate sóng khi đang phát.
class AudioBar extends StatefulWidget {
  const AudioBar({
    super.key,
    required this.isPlaying,
    required this.onToggle,
    this.duration,
    this.loading = false,
  });

  /// Đang phát hay không (do màn chat quản lý qua AudioPlayer).
  final bool isPlaying;

  /// Bấm nút play/pause.
  final VoidCallback onToggle;

  /// Thời lượng audio (hiển thị mm:ss). Null -> hiện "--:--".
  final Duration? duration;

  /// Đang tải/sinh audio (TTS) -> hiện spinner thay nút play.
  final bool loading;

  @override
  State<AudioBar> createState() => _AudioBarState();
}

class _AudioBarState extends State<AudioBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  bool _reduceMotion = false;

  // 24 cột sóng tĩnh (cao thấp khác nhau) -> nhân lên khi phát.
  static const _bars = 24;
  late final List<double> _heights;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // chiều cao cơ sở cố định (đẹp, không random mỗi frame)
    _heights = List.generate(_bars, (i) {
      final v = 0.35 + (sin(i * 0.9) + 1) / 2 * 0.65;
      return v.clamp(0.2, 1.0);
    });
    if (widget.isPlaying) _ctl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AudioBar old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_reduceMotion && !_ctl.isAnimating) {
      _ctl.repeat(reverse: true);
    } else if (!widget.isPlaying && _ctl.isAnimating) {
      _ctl.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _ctl.stop();
      _ctl.value = 0;
    } else if (widget.isPlaying && !_ctl.isAnimating) {
      _ctl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String get _durText {
    final d = widget.duration;
    if (d == null) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.redDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Nút play/pause tròn vàng
          IconButton(
            tooltip: widget.loading
                ? 'Đang tải âm thanh'
                : widget.isPlaying
                    ? 'Tạm dừng lời kể'
                    : 'Phát lời kể',
            onPressed: widget.loading ? null : widget.onToggle,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.goldBright,
                shape: BoxShape.circle,
              ),
              child: widget.loading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.redDark),
                    )
                  : Icon(
                      widget.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppColors.redDark,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // Dải sóng âm
          Expanded(
            child: SizedBox(
              height: 26,
              child: AnimatedBuilder(
                animation: _ctl,
                builder: (_, __) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(_bars, (i) {
                    final base = _heights[i];
                    // khi phát: nhấp nhô theo controller; khi dừng: tĩnh
                    final factor = widget.isPlaying
                        ? (0.6 + 0.4 * sin((_ctl.value * 2 * pi) + i))
                        : 1.0;
                    final h = (26 * base * factor).clamp(3.0, 26.0);
                    return Container(
                      width: 3,
                      height: h,
                      decoration: BoxDecoration(
                        color: AppColors.goldBright
                            .withValues(alpha: widget.isPlaying ? 0.95 : 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(_durText,
              style: const TextStyle(
                  color: AppColors.onRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
