import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Khung điện thoại cho web/desktop, tích hợp Chế độ Trình chiếu (Presentation Mode)
/// theo Mục 6 của SPEC_UI_UX.md phục vụ buổi demo máy chiếu tuần 10.
class MobileFrame extends StatefulWidget {
  const MobileFrame({super.key, required this.child});

  final Widget child;

  @override
  State<MobileFrame> createState() => _MobileFrameState();
}

class _MobileFrameState extends State<MobileFrame> {
  static const double _baseWidth = 430;
  static const double _baseHeight = 890;

  bool _isPresenting = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // Bật tự động nếu có query param ?present=1 trên web
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.queryParameters['present'] == '1') {
        _isPresenting = true;
      }
    }
    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _togglePresenting() {
    setState(() {
      _isPresenting = !_isPresenting;
    });
    _resetHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = screenSize.width;
    final height = screenSize.height;

    // Trên thiết bị màn hẹp (điện thoại thật): chạy full view nguyên bản
    if (width <= _baseWidth + 24) {
      return widget.child;
    }

    // Tính toán kích thước khung
    double frameWidth = _baseWidth;
    double frameHeight = _baseHeight;

    if (_isPresenting) {
      // Phóng theo chiều cao cửa sổ (tối đa 2.0x), giữ đúng tỷ lệ 430:890
      final availableHeight = height * 0.94;
      final scale = (availableHeight / _baseHeight).clamp(1.0, 2.0);
      frameWidth = math.min(_baseWidth * scale, width * 0.94);
      frameHeight = (frameWidth / _baseWidth) * _baseHeight;
    }

    final backdropColor = _isPresenting
        ? AppColors.redDeepest
        : const Color(0xFFEDE3D3);

    return MouseRegion(
      onHover: (_) => _resetHideTimer(),
      child: GestureDetector(
        onTap: _resetHideTimer,
        child: ColoredBox(
          color: backdropColor,
          child: Stack(
            children: [
              // Khung điện thoại căn giữa
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_isPresenting ? 32 : 28),
                  child: Container(
                    width: frameWidth,
                    height: _isPresenting ? frameHeight : null,
                    constraints: _isPresenting
                        ? null
                        : BoxConstraints(maxHeight: height),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: _isPresenting ? 0.45 : 0.18,
                          ),
                          blurRadius: _isPresenting ? 50 : 40,
                          spreadRadius: _isPresenting ? 8 : 4,
                        ),
                      ],
                    ),
                    child: widget.child,
                  ),
                ),
              ),

              // Nút bật/tắt chế độ trình chiếu ở góc dưới bên phải
              Positioned(
                bottom: 20,
                right: 20,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.15,
                  duration: const Duration(milliseconds: 300),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      canRequestFocus: false,
                      onTap: _togglePresenting,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _isPresenting
                              ? AppColors.goldBright
                              : AppColors.redDeepest.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: appSoftShadow,
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isPresenting
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.present_to_all_rounded,
                              color: _isPresenting
                                  ? AppColors.ink
                                  : AppColors.goldBright,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isPresenting ? 'Thu nhỏ' : 'Trình chiếu',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isPresenting
                                    ? AppColors.ink
                                    : AppColors.goldBright,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
