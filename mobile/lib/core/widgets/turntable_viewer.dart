import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Xem nhân vật "xoay 360" bằng bộ ảnh nhiều góc (turntable).
///
/// Vì sao không dùng model 3D .glb: `model_viewer_plus` render qua WebGL trong
/// một web-component nhúng — trên Flutter Web nó rất hay hiện ô trống (đặc biệt
/// trong khung nhỏ). Ghép ảnh nhiều góc cho trải nghiệm "xoay" mượt, chạy 100%
/// trên web/mobile, và tận dụng đúng ảnh hi-res của nhân vật.
///
/// Kéo ngang để xoay; có thể bật [autoRotate] để tự quay.
class TurntableViewer extends StatefulWidget {
  const TurntableViewer({
    super.key,
    required this.frames,
    this.autoRotate = true,
    this.fit = BoxFit.cover,
    this.showHint = true,
  });

  /// Danh sách asset path theo thứ tự quay (vd 6 góc).
  final List<String> frames;
  final bool autoRotate;
  final BoxFit fit;
  final bool showHint;

  @override
  State<TurntableViewer> createState() => _TurntableViewerState();
}

class _TurntableViewerState extends State<TurntableViewer> {
  int _index = 0;
  double _dragAccum = 0;
  bool _interacted = false;
  Timer? _autoTimer;
  bool _precached = false;

  // Số pixel kéo ngang để sang 1 frame.
  static const double _pxPerFrame = 26;

  @override
  void initState() {
    super.initState();
    if (widget.autoRotate) {
      _autoTimer = Timer.periodic(const Duration(milliseconds: 140), (_) {
        if (!mounted || _interacted) return;
        setState(() => _index = (_index + 1) % widget.frames.length);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final f in widget.frames) {
        precacheImage(AssetImage(f), context);
      }
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  void _onDrag(double dx) {
    _interacted = true;
    _dragAccum += dx;
    final n = widget.frames.length;
    while (_dragAccum.abs() >= _pxPerFrame) {
      if (_dragAccum > 0) {
        _index = (_index - 1 + n) % n;
        _dragAccum -= _pxPerFrame;
      } else {
        _index = (_index + 1) % n;
        _dragAccum += _pxPerFrame;
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.frames.isEmpty) {
      return const Center(
        child: Icon(Icons.person, color: AppColors.goldBright, size: 64),
      );
    }
    return GestureDetector(
      onHorizontalDragUpdate: (d) => _onDrag(d.delta.dx),
      onHorizontalDragEnd: (_) => _dragAccum = 0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Giữ tất cả frame trong cây để chuyển tức thì (đã precache).
          for (int i = 0; i < widget.frames.length; i++)
            Opacity(
              opacity: i == _index ? 1 : 0,
              child: Image.asset(widget.frames[i],
                  fit: widget.fit, gaplessPlayback: true),
            ),
          if (widget.showHint && !_interacted)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swipe, color: AppColors.goldBright, size: 16),
                      SizedBox(width: 6),
                      Text('Kéo để xoay 360°',
                          style: TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
