import 'dart:math' as toan;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Pháo giấy mừng chiến thắng.
///
/// VÌ SAO TỰ VẼ THAY VÌ THÊM GÓI
///     Cần đúng một hiệu ứng, dùng đúng một chỗ. Kéo thêm một gói phụ thuộc
///     cho việc đó là đổi lấy rủi ro bảo trì mà chẳng được gì; vài chục hình
///     chữ nhật rơi xuống thì `CustomPainter` vẽ thừa sức.
///
///     Màu lấy từ bộ nhận diện Imperial Light chứ không phải bảy sắc cầu vồng
///     — pháo giấy xanh lá tím hồng giữa một sản phẩm sử Việt trông như dán
///     nhầm từ app khác.
///
/// CHẠY MỘT LẦN RỒI THÔI
///     Hết 2,6 giây là tự dừng bộ điều khiển. Hiệu ứng ăn mừng mà lặp mãi thì
///     tới giây thứ mười là phiền, và giữ khung hình chạy liên tục cũng tốn
///     pin vô ích.
class PhaoGiay extends StatefulWidget {
  const PhaoGiay({super.key, this.soManh = 46, this.chay = true});

  final int soManh;

  /// Đặt false để tắt hẳn — dùng khi người dùng thua, không có gì để mừng.
  final bool chay;

  @override
  State<PhaoGiay> createState() => _PhaoGiayState();
}

class _PhaoGiayState extends State<PhaoGiay>
    with SingleTickerProviderStateMixin {
  // KHÔNG dùng `late final` khởi tạo lười ở đây.
  //
  // Khi người dùng thua thì `chay` là false, build trả về SizedBox và biến này
  // không bao giờ bị chạm tới — cho tới lúc dispose() gọi _ctl.dispose(), và
  // chính lời gọi đó mới kích hoạt khởi tạo. Lúc ấy widget đã bị gỡ khỏi cây
  // nên `vsync: this` đi tra tổ tiên và ném lỗi. Test màn kết quả bắt được.
  late final AnimationController _ctl;

  late final List<_Manh> _manh;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    final r = toan.Random();
    _manh = List.generate(widget.soManh, (_) => _Manh.ngauNhien(r));
    if (widget.chay) _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.chay) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, __) => CustomPaint(
          painter: _VePhao(_manh, _ctl.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Manh {
  _Manh({
    required this.x,
    required this.treMs,
    required this.rong,
    required this.cao,
    required this.mau,
    required this.xoay,
    required this.tocDoXoay,
    required this.lech,
  });

  final double x;        // vị trí ngang lúc bắt đầu, 0..1
  final double treMs;    // rơi trễ một chút cho khỏi thành một hàng thẳng
  final double rong;
  final double cao;
  final Color mau;
  final double xoay;
  final double tocDoXoay;
  final double lech;     // độ dạt ngang khi rơi

  static const _mau = [
    AppColors.goldBright,
    AppColors.gold,
    AppColors.red,
    AppColors.cta,
    Color(0xFFFBF3E6),
  ];

  factory _Manh.ngauNhien(toan.Random r) => _Manh(
        x: r.nextDouble(),
        treMs: r.nextDouble() * 0.35,
        rong: 5 + r.nextDouble() * 6,
        cao: 9 + r.nextDouble() * 8,
        mau: _mau[r.nextInt(_mau.length)],
        xoay: r.nextDouble() * toan.pi,
        tocDoXoay: (r.nextDouble() - 0.5) * 9,
        lech: (r.nextDouble() - 0.5) * 0.30,
      );
}

class _VePhao extends CustomPainter {
  _VePhao(this.manh, this.t);

  final List<_Manh> manh;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final son = Paint();
    for (final m in manh) {
      // Mỗi mảnh có nhịp riêng, và mảnh nào trễ thì rơi ngắn hơn — nhờ vậy
      // trận pháo tan dần chứ không biến mất cùng một lúc.
      final tt = ((t - m.treMs) / (1 - m.treMs)).clamp(0.0, 1.0);
      if (tt <= 0) continue;

      // Rơi nhanh dần: quãng đường tỉ lệ bình phương thời gian, như trọng lực.
      final y = (tt * tt) * (size.height + 60) - 30;
      final x = (m.x + m.lech * tt) * size.width;

      // Mờ dần ở một phần tư cuối, để không biến mất đột ngột giữa màn hình.
      final mo = tt > 0.75 ? (1 - (tt - 0.75) / 0.25) : 1.0;
      son.color = m.mau.withValues(alpha: mo.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(m.xoay + m.tocDoXoay * tt);
      // Bẹt dần theo trục ngang để trông như mảnh giấy đang lật trong không khí.
      final beRong = m.rong * (0.35 + 0.65 * (toan.cos(tt * 9 + m.xoay)).abs());
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: beRong, height: m.cao),
          const Radius.circular(1.5),
        ),
        son,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_VePhao cu) => cu.t != t;
}
