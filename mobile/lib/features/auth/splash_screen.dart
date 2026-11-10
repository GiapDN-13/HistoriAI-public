import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils/motion_preferences.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../shell/main_navigation_shell.dart';
import 'auth_service.dart';
import '../onboarding/huong_dan_screen.dart';
import 'login_screen.dart';

/// Màn mở đầu có hiệu ứng: logo thương hiệu hiện dần + phóng to + hào quang
/// vàng quay, sau ~2.4s tự chuyển thẳng vào màn chính (preview mode).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro; // fade + scale logo
  late final AnimationController _spin; // hào quang vàng quay
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _fade = CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
    _scale = Tween(begin: 0.82, end: 1.0).animate(CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack)));
    _glow = CurvedAnimation(
        parent: _intro, curve: const Interval(0.4, 1.0, curve: Curves.easeIn));

    _intro.forward();
    _goNext();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPreferences.reduce(context)) {
      _spin.stop();
      _spin.value = 0;
      _intro.value = 1;
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  Future<void> _goNext() async {
    // Còn token cũ thì vào thẳng; chưa đăng nhập thì qua màn Sign In —
    // có đăng nhập mới lưu được điểm quiz và tiến độ học.
    var signedIn = false;
    try {
      signedIn = await widget.authService.tryAutoLogin();
    } catch (_) {}

    // Người mở app lần đầu xem phần giới thiệu TRƯỚC màn đăng nhập. Đặt sau
    // màn đăng nhập thì mất tác dụng: quyết định ở lại hay bỏ đi xảy ra ngay
    // lúc nhìn thấy màn hình đầu tiên, chứ không phải sau khi đã tạo tài khoản.
    //
    // Người đã đăng nhập sẵn thì bỏ qua — họ biết app này rồi.
    final canHuongDan = !signedIn && !await HuongDanScreen.daXem();

    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    // Giữ lấy Navigator TRƯỚC khi màn này bị thay thế.
    //
    // Màn hướng dẫn gọi ngược lại đây khi người dùng bấm xong. Nhưng lúc đó
    // SplashScreen đã tự thay chính nó bằng màn hướng dẫn, nên State này đã
    // bị huỷ: mọi lời gọi qua `context` của nó đều rơi vào hư không, KHÔNG
    // ném lỗi và KHÔNG ghi log gì.
    //
    // Hậu quả trước khi sửa: người mở app lần đầu bấm "Bắt đầu" hay "Bỏ qua"
    // đều đứng yên, phải tải lại trang mới thoát ra được. NavigatorState thì
    // sống lâu hơn từng màn, nên cầm nó là gọi được từ bất cứ đâu.
    final dieuHuong = Navigator.of(context);

    _sangMan(
        dieuHuong,
        canHuongDan
            ? HuongDanScreen(
                khiXong: () => _sangMan(
                    dieuHuong, LoginScreen(authService: widget.authService)))
            : signedIn
                ? MainNavigationShell(authService: widget.authService)
                : LoginScreen(authService: widget.authService));
  }

  void _sangMan(NavigatorState dieuHuong, Widget man) {
    dieuHuong.pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, __, ___) => man,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.redDeep, AppColors.redDark, Color(0xFF4A150D)],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _spin]),
            builder: (_, __) {
              return SizedBox(
                width: 280,
                height: 320,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Hào quang vàng quay phía sau logo
                    Opacity(
                      opacity: _glow.value * 0.9,
                      child: Transform.rotate(
                        angle: _spin.value * 6.28319,
                        child: CustomPaint(
                          size: const Size(300, 300),
                          painter: _HaloPainter(),
                        ),
                      ),
                    ),
                    // Glow tròn mềm
                    Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.gold
                                  .withValues(alpha: 0.30 * _glow.value),
                              blurRadius: 60,
                              spreadRadius: 10),
                        ],
                      ),
                    ),
                    // Logo thương hiệu (nền trong suốt)
                    FadeTransition(
                      opacity: _fade,
                      child: Transform.scale(
                        scale: _scale.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Đôi Chim Lạc bay chầu đối xứng
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                ChimLacMotif(
                                    size: 64, color: AppColors.goldBright),
                                SizedBox(width: 14),
                                DoubleFestivalFlags(size: 26),
                                SizedBox(width: 14),
                                ChimLacMotif(
                                    size: 64,
                                    color: AppColors.goldBright,
                                    flip: true),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Image.asset(
                              'assets/brand/logo.png',
                              width: 240,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Hai cung vàng đối xứng (gradient) tạo hào quang quay quanh logo.
class _HaloPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.gold,
          AppColors.goldBright,
          Colors.transparent,
          Colors.transparent,
          AppColors.gold,
          AppColors.goldBright,
          Colors.transparent,
        ],
        stops: [0.0, 0.12, 0.22, 0.34, 0.5, 0.62, 0.72, 0.84],
      ).createShader(rect);
    final r = rect.deflate(6);
    canvas.drawArc(r, 0, 2.0, false, paint);
    canvas.drawArc(r, 3.14159, 2.0, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
