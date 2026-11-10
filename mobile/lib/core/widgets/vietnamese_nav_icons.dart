import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// Bộ Icon Văn Hoá Sử Việt thuần Vector tinh xảo dành riêng cho Thanh Điều Hướng (Bottom Navigation).
/// Thiết kế chuẩn mực mang đậm dấu ấn di sản Đại Việt:
/// 0: Khuê Văn Các & Cửa Sổ Sao Khuê (Trang chủ)
/// 1: Chiếu Thư Triện Đỏ & Dòng Lịch Sử (Dòng thời gian)
/// 2: Trống Đồng Đông Sơn & Song Kiếm Lệnh (Đấu trường)
/// 3: Mũ Cánh Chuồn Trạng Nguyên Hiền Tài (Vĩ nhân)
/// 4: Vạc Đồng Cửu Đỉnh & Lư Hương Hoàng Triều (Bảo tàng)
class VietnameseNavIcon extends StatelessWidget {
  const VietnameseNavIcon({
    super.key,
    required this.index,
    required this.active,
    required this.color,
    this.size = 25,
  });

  final int index;
  final bool active;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _getPainter(index, active, color),
      ),
    );
  }

  CustomPainter _getPainter(int idx, bool active, Color color) {
    switch (idx) {
      case 0:
        return _KhueVanCacPainter(active: active, color: color);
      case 1:
        return _RoyalScrollPainter(active: active, color: color);
      case 2:
        return _DongSonDrumPainter(active: active, color: color);
      case 3:
        return _ScholarHatPainter(active: active, color: color);
      case 4:
      default:
        return _ImperialUrnPainter(active: active, color: color);
    }
  }
}

/// 0. Khuê Văn Các — Biểu tượng đỉnh cao trí tuệ và văn hiến ngàn năm Thăng Long
class _KhueVanCacPainter extends CustomPainter {
  const _KhueVanCacPainter({required this.active, required this.color});
  final bool active;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 1.6 : 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = active ? color.withValues(alpha: 0.25) : Colors.transparent
      ..style = PaintingStyle.fill;

    // 1. Tầng mái trên — Mái đao cong vút Đại Việt
    final topRoof = Path()
      ..moveTo(w * 0.08, h * 0.28)
      ..cubicTo(w * 0.25, h * 0.28, w * 0.38, h * 0.12, w * 0.50, h * 0.08)
      ..cubicTo(w * 0.62, h * 0.12, w * 0.75, h * 0.28, w * 0.92, h * 0.28)
      ..lineTo(w * 0.80, h * 0.33)
      ..lineTo(w * 0.20, h * 0.33)
      ..close();
    canvas.drawPath(topRoof, fill);
    canvas.drawPath(topRoof, stroke);

    // Chỏm đỉnh hồ lô / kìm nóc
    canvas.drawCircle(Offset(w * 0.50, h * 0.05), 1.6, Paint()..color = color);

    // 2. Gác Khuê Văn Các với Cửa Sổ Tròn Sao Khuê (Đặc trưng độc nhất vô nhị)
    final pavilion = Rect.fromLTRB(w * 0.24, h * 0.33, w * 0.76, h * 0.64);
    canvas.drawRect(pavilion, fill);
    canvas.drawRect(pavilion, stroke);

    // Cửa sổ tròn sao Khuê ở tâm
    final sunWindowCenter = Offset(w * 0.50, h * 0.485);
    final sunWindowRadius = w * 0.13;
    canvas.drawCircle(sunWindowCenter, sunWindowRadius, stroke..strokeWidth = 1.2);
    if (active) {
      canvas.drawCircle(
        sunWindowCenter,
        sunWindowRadius * 0.6,
        Paint()..color = color,
      );
    } else {
      // Nan cửa sổ chữ thập toả tia
      canvas.drawLine(
        Offset(sunWindowCenter.dx - sunWindowRadius, sunWindowCenter.dy),
        Offset(sunWindowCenter.dx + sunWindowRadius, sunWindowCenter.dy),
        stroke..strokeWidth = 1.0,
      );
      canvas.drawLine(
        Offset(sunWindowCenter.dx, sunWindowCenter.dy - sunWindowRadius),
        Offset(sunWindowCenter.dx, sunWindowCenter.dy + sunWindowRadius),
        stroke..strokeWidth = 1.0,
      );
    }

    // 3. Tầng mái dưới chìa ra
    final lowerRoof = Path()
      ..moveTo(w * 0.12, h * 0.64)
      ..lineTo(w * 0.88, h * 0.64)
      ..lineTo(w * 0.84, h * 0.69)
      ..lineTo(w * 0.16, h * 0.69)
      ..close();
    canvas.drawPath(lowerRoof, stroke..strokeWidth = 1.2);

    // 4. Bốn cột trụ gạch đá tầng dưới đứng vững chãi
    stroke.strokeWidth = active ? 1.5 : 1.2;
    canvas.drawLine(Offset(w * 0.25, h * 0.69), Offset(w * 0.25, h * 0.94), stroke);
    canvas.drawLine(Offset(w * 0.42, h * 0.69), Offset(w * 0.42, h * 0.94), stroke);
    canvas.drawLine(Offset(w * 0.58, h * 0.69), Offset(w * 0.58, h * 0.94), stroke);
    canvas.drawLine(Offset(w * 0.75, h * 0.69), Offset(w * 0.75, h * 0.94), stroke);

    // Bậc thềm đá
    canvas.drawLine(Offset(w * 0.08, h * 0.94), Offset(w * 0.92, h * 0.94), stroke);
  }

  @override
  bool shouldRepaint(covariant _KhueVanCacPainter old) =>
      old.active != active || old.color != color;
}

/// 1. Chiếu Thư & Cuộn Thẻ Tre — Chiếu Dời Đô, Hịch Tướng Sĩ ngàn năm lưu sử
class _RoyalScrollPainter extends CustomPainter {
  const _RoyalScrollPainter({required this.active, required this.color});
  final bool active;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 1.6 : 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = active ? color.withValues(alpha: 0.22) : Colors.transparent
      ..style = PaintingStyle.fill;

    // 1. Thân chiếu thư mở rộng uốn lượn như lụa gấm
    final scrollBody = Path()
      ..moveTo(w * 0.18, h * 0.22)
      ..cubicTo(w * 0.35, h * 0.26, w * 0.65, h * 0.18, w * 0.82, h * 0.22)
      ..lineTo(w * 0.82, h * 0.78)
      ..cubicTo(w * 0.65, h * 0.74, w * 0.35, h * 0.82, w * 0.18, h * 0.78)
      ..close();
    canvas.drawPath(scrollBody, fill);
    canvas.drawPath(scrollBody, stroke);

    // 2. Hai trục cuốn gỗ sơn son thếp vàng hai bên
    // Trục trái
    final leftSpindle = RRect.fromLTRBR(
      w * 0.08,
      h * 0.14,
      w * 0.18,
      h * 0.86,
      const Radius.circular(2.5),
    );
    canvas.drawRRect(leftSpindle, fill);
    canvas.drawRRect(leftSpindle, stroke);
    // Đầu bịt đồng trục trái
    canvas.drawCircle(Offset(w * 0.13, h * 0.11), 1.8, Paint()..color = color);
    canvas.drawCircle(Offset(w * 0.13, h * 0.89), 1.8, Paint()..color = color);

    // Trục phải
    final rightSpindle = RRect.fromLTRBR(
      w * 0.82,
      h * 0.14,
      w * 0.92,
      h * 0.86,
      const Radius.circular(2.5),
    );
    canvas.drawRRect(rightSpindle, fill);
    canvas.drawRRect(rightSpindle, stroke);
    // Đầu bịt đồng trục phải
    canvas.drawCircle(Offset(w * 0.87, h * 0.11), 1.8, Paint()..color = color);
    canvas.drawCircle(Offset(w * 0.87, h * 0.89), 1.8, Paint()..color = color);

    // 3. Dòng chữ sử thi khắc bên trong
    final textPaint = Paint()
      ..color = color.withValues(alpha: active ? 0.9 : 0.6)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(w * 0.27, h * 0.36), Offset(w * 0.73, h * 0.36), textPaint);
    canvas.drawLine(Offset(w * 0.27, h * 0.48), Offset(w * 0.64, h * 0.48), textPaint);
    canvas.drawLine(Offset(w * 0.27, h * 0.60), Offset(w * 0.52, h * 0.60), textPaint);

    // 4. Dấu Triện Son / Ngọc Tỷ Chu Sa đỏ thắm Đại Việt ở góc phải
    final sealPaint = Paint()
      ..color = const Color(0xFFBA2323) // Đỏ son triện ngọc
      ..style = PaintingStyle.fill;
    final sealBorder = Paint()
      ..color = AppColors.goldBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final sealRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.68, h * 0.60), width: 7.0, height: 7.0),
      const Radius.circular(1.2),
    );
    canvas.drawRRect(sealRect, sealPaint);
    canvas.drawRRect(sealRect, sealBorder);
  }

  @override
  bool shouldRepaint(covariant _RoyalScrollPainter old) =>
      old.active != active || old.color != color;
}

/// 2. Trống Đồng Đông Sơn & Song Kiếm Lệnh — Hào khí Thăng Long & Chiến trận
class _DongSonDrumPainter extends CustomPainter {
  const _DongSonDrumPainter({required this.active, required this.color});
  final bool active;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 1.6 : 1.3
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = active ? color.withValues(alpha: 0.22) : Colors.transparent
      ..style = PaintingStyle.fill;

    // 1. Song Kiếm Lệnh cắm chéo phía sau (Crossed broadswords)
    final swordPaint = Paint()
      ..color = color.withValues(alpha: active ? 0.75 : 0.5)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // Lưỡi kiếm
    canvas.drawLine(Offset(w * 0.12, h * 0.12), Offset(w * 0.88, h * 0.88), swordPaint);
    canvas.drawLine(Offset(w * 0.88, h * 0.12), Offset(w * 0.12, h * 0.88), swordPaint);

    // Chắn kiếm & chuôi kiếm
    canvas.drawLine(Offset(w * 0.07, h * 0.17), Offset(w * 0.17, h * 0.07), swordPaint);
    canvas.drawLine(Offset(w * 0.83, h * 0.07), Offset(w * 0.93, h * 0.17), swordPaint);
    // Chuôi núm kiếm tròn
    canvas.drawCircle(Offset(w * 0.09, h * 0.09), 1.4, Paint()..color = color);
    canvas.drawCircle(Offset(w * 0.91, h * 0.09), 1.4, Paint()..color = color);

    // 2. Vành Trống Đồng tròn uy nghiêm
    final drumR = w * 0.35;
    canvas.drawCircle(center, drumR, fill);
    canvas.drawCircle(center, drumR, stroke);

    // Vành đồng tâm thứ 2
    canvas.drawCircle(center, drumR * 0.70, stroke..strokeWidth = 1.0);

    // 3. Mặt trời Đông Sơn 12 tia ở tâm
    final sunR = drumR * 0.38;
    const rays = 8;
    for (int i = 0; i < rays; i++) {
      final angle = (i * 2 * math.pi) / rays;
      final p = Offset(center.dx + sunR * math.cos(angle), center.dy + sunR * math.sin(angle));
      canvas.drawLine(center, p, stroke..strokeWidth = 1.2);
    }
    canvas.drawCircle(center, 2.2, Paint()..color = color);

    // 4. Bốn cánh chim Lạc bay quanh vành trống
    final birdR = drumR * 0.85;
    final dotPaint = Paint()..color = color;
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) + math.pi / 4;
      canvas.drawCircle(
        Offset(center.dx + birdR * math.cos(angle), center.dy + birdR * math.sin(angle)),
        1.1,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DongSonDrumPainter old) =>
      old.active != active || old.color != color;
}

/// 3. Mũ Cánh Chuồn Trạng Nguyên — Biểu tượng hiền tài là nguyên khí quốc gia
class _ScholarHatPainter extends CustomPainter {
  const _ScholarHatPainter({required this.active, required this.color});
  final bool active;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 1.6 : 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = active ? color.withValues(alpha: 0.25) : Colors.transparent
      ..style = PaintingStyle.fill;

    // 1. Thân mũ Ô Sa (Mũ cánh chuồn Trạng Nguyên)
    final hatDome = Path()
      ..moveTo(w * 0.31, h * 0.70)
      ..lineTo(w * 0.33, h * 0.38)
      ..cubicTo(w * 0.36, h * 0.16, w * 0.64, h * 0.16, w * 0.67, h * 0.38)
      ..lineTo(w * 0.69, h * 0.70)
      ..close();
    canvas.drawPath(hatDome, fill);
    canvas.drawPath(hatDome, stroke);

    // Vành đai mũ sơn son
    final band = RRect.fromLTRBR(
      w * 0.27,
      h * 0.68,
      w * 0.73,
      h * 0.77,
      const Radius.circular(2.5),
    );
    canvas.drawRRect(band, fill);
    canvas.drawRRect(band, stroke);

    // Viên Ngọc Như Ý / Bác Sơn ở chính diện mũ
    canvas.drawCircle(Offset(w * 0.50, h * 0.42), 2.2, Paint()..color = color);
    if (active) {
      canvas.drawCircle(
        Offset(w * 0.50, h * 0.42),
        1.0,
        Paint()..color = const Color(0xFFBA2323),
      );
    }

    // 2. Hai cánh chuồn (Chuồn chuồn vút ngang bay xa)
    // Cánh trái vươn rộng và lượn sóng mềm mại
    final leftWing = Path()
      ..moveTo(w * 0.29, h * 0.50)
      ..cubicTo(w * 0.14, h * 0.53, w * 0.05, h * 0.38, w * 0.02, h * 0.43)
      ..cubicTo(w * 0.03, h * 0.58, w * 0.13, h * 0.64, w * 0.28, h * 0.57)
      ..close();
    canvas.drawPath(leftWing, fill);
    canvas.drawPath(leftWing, stroke);

    // Cánh phải vươn rộng đối xứng
    final rightWing = Path()
      ..moveTo(w * 0.71, h * 0.50)
      ..cubicTo(w * 0.86, h * 0.53, w * 0.95, h * 0.38, w * 0.98, h * 0.43)
      ..cubicTo(w * 0.97, h * 0.58, w * 0.87, h * 0.64, w * 0.72, h * 0.57)
      ..close();
    canvas.drawPath(rightWing, fill);
    canvas.drawPath(rightWing, stroke);

    // Đỉnh chóp nón đính hạt ngọc vàng
    canvas.drawCircle(Offset(w * 0.50, h * 0.16), 1.8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ScholarHatPainter old) =>
      old.active != active || old.color != color;
}

/// 4. Vạc Đồng Cửu Đỉnh & Lư Hương Hoàng Triều — Cổ vật bảo tàng ngàn năm
class _ImperialUrnPainter extends CustomPainter {
  const _ImperialUrnPainter({required this.active, required this.color});
  final bool active;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 1.6 : 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = active ? color.withValues(alpha: 0.25) : Colors.transparent
      ..style = PaintingStyle.fill;

    // 1. Thân Đỉnh Đồng Cổ hình bầu dục bề thế
    final urnBody = Path()
      ..moveTo(w * 0.22, h * 0.26)
      ..lineTo(w * 0.78, h * 0.26)
      ..cubicTo(w * 0.86, h * 0.46, w * 0.84, h * 0.68, w * 0.68, h * 0.74)
      ..lineTo(w * 0.32, h * 0.74)
      ..cubicTo(w * 0.16, h * 0.68, w * 0.14, h * 0.46, w * 0.22, h * 0.26)
      ..close();
    canvas.drawPath(urnBody, fill);
    canvas.drawPath(urnBody, stroke);

    // Gờ miệng đỉnh đồng
    canvas.drawLine(Offset(w * 0.16, h * 0.26), Offset(w * 0.84, h * 0.26), stroke);

    // 2. Hai quai rồng / quai mây cách điệu hai bên
    final leftHandle = Path()
      ..moveTo(w * 0.18, h * 0.32)
      ..cubicTo(w * 0.04, h * 0.30, w * 0.04, h * 0.54, w * 0.18, h * 0.56);
    canvas.drawPath(leftHandle, stroke);

    final rightHandle = Path()
      ..moveTo(w * 0.82, h * 0.32)
      ..cubicTo(w * 0.96, h * 0.30, w * 0.96, h * 0.54, w * 0.82, h * 0.56);
    canvas.drawPath(rightHandle, stroke);

    // 3. Thế Chân Vạc vững vàng (3 chân đỉnh đồng)
    final legPaint = stroke..strokeWidth = active ? 1.6 : 1.3;
    // Chân trái choãi
    canvas.drawLine(Offset(w * 0.30, h * 0.74), Offset(w * 0.23, h * 0.93), legPaint);
    // Chân giữa thẳng
    canvas.drawLine(Offset(w * 0.50, h * 0.74), Offset(w * 0.50, h * 0.93), legPaint);
    // Chân phải choãi
    canvas.drawLine(Offset(w * 0.70, h * 0.74), Offset(w * 0.77, h * 0.93), legPaint);

    // 4. Hoa văn cổ trên thân đỉnh
    canvas.drawLine(
      Offset(w * 0.28, h * 0.50),
      Offset(w * 0.72, h * 0.50),
      stroke..strokeWidth = 1.1,
    );

    // Chồi lửa hoặc tia sáng báu vật phát quang trên đỉnh
    if (active) {
      canvas.drawCircle(Offset(w * 0.50, h * 0.14), 1.8, Paint()..color = color);
      canvas.drawLine(Offset(w * 0.40, h * 0.16), Offset(w * 0.36, h * 0.10), stroke..strokeWidth = 1.0);
      canvas.drawLine(Offset(w * 0.60, h * 0.16), Offset(w * 0.64, h * 0.10), stroke..strokeWidth = 1.0);
    }
  }

  @override
  bool shouldRepaint(covariant _ImperialUrnPainter old) =>
      old.active != active || old.color != color;
}
