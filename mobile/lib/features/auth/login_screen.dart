import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../shell/main_navigation_shell.dart';
import 'auth_service.dart';
import 'dang_nhap_google.dart';
import 'quen_mat_khau.dart';
import 'register_screen.dart';

/// Màn hình Đăng nhập của HistoriAI.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    this.quayLaiKhiXong = false,
  });
  final AuthService authService;

  /// Đăng nhập xong thì đóng màn này (trả `true`) thay vì vào thẳng app.
  /// Dùng khi người dùng bị mời đăng nhập giữa chừng một việc khác (vd thanh
  /// toán Premium) — vào app là bỏ họ giữa đường, mất chỗ đang làm dở.
  final bool quayLaiKhiXong;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.authService.login(
        _emailCtl.text.trim(),
        _passCtl.text,
      );
      if (!mounted) return;
      _vaoApp();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Đã có lỗi xảy ra. Vui lòng kiểm tra kết nối.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _vaoApp() {
    if (widget.quayLaiKhiXong) {
      Navigator.pop(context, true);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigationShell(authService: widget.authService),
      ),
    );
  }

  void _continueAsGuest() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            MainNavigationShell(authService: widget.authService),
        transitionDuration: Duration.zero,
      ),
    );
  }

  void _showPasswordResetHelp() {
    FocusManager.instance.primaryFocus?.unfocus();
    hoiQuenMatKhau(context, widget.authService, email: _emailCtl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DongSonBackground(
        size: 340,
        opacity: 0.04,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewportConstraints) {
              const viewportPadding = EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                // Đệm đáy lớn hơn để cân bằng trọng lượng các CTA dưới ô
                // mật khẩu; mốc nhập vẫn nằm giữa theo cảm nhận thị giác.
                AppSpacing.lg + AppSpacing.sm,
              );
              final minContentHeight =
                  (viewportConstraints.maxHeight - viewportPadding.vertical)
                      .clamp(0.0, double.infinity)
                      .toDouble();

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: viewportPadding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minContentHeight),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Các phần trên kết thúc ngay trước mốc ô mật khẩu.
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/brand/logo.png',
                                    height: 84,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 12),
                                  // Bọc FittedBox để hàng logo tự thu trên máy
                                  // hẹp (360 px) thay vì tràn — chim Lạc giữ
                                  // được cỡ lớn trên màn thường.
                                  const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ChimLacMotif(
                                            size: 64, color: AppColors.red),
                                        SizedBox(width: 10),
                                        Text(
                                          'HISTORIAI',
                                          style: TextStyle(
                                            fontFamily: 'PlayfairDisplay',
                                            color: AppColors.red,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        ChimLacMotif(
                                          size: 64,
                                          color: AppColors.red,
                                          flip: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Cùng AI sống lại trang sử hào hùng Đại Việt',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: AppColors.inkSoft,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const DongSonWaveDivider(
                                    color: AppColors.gold,
                                    height: 16,
                                    opacity: 0.50,
                                  ),
                                  const SizedBox(height: 16),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Đăng nhập tài khoản',
                                      style: TextStyle(
                                        fontFamily: 'PlayfairDisplay',
                                        color: AppColors.ink,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  TextFormField(
                                    controller: _emailCtl,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: AppColors.ink,
                                      fontSize: 14,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(
                                        Icons.email_outlined,
                                        color: AppColors.inkSoft,
                                        size: 20,
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Vui lòng nhập email của bạn'
                                            : null,
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              ),
                            ),
                          ),

                          // Mốc quang học: giữ tâm ô mật khẩu ở giữa viewport.
                          // Khoảng đệm theo token bên dưới tạo nhịp tự nhiên tới
                          // hành động "Quên mật khẩu?" và không dùng offset tuyệt đối.
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: TextFormField(
                              key: const Key('login-password-field'),
                              controller: _passCtl,
                              obscureText: _obscurePass,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.ink,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu',
                                prefixIcon: const Icon(
                                  Icons.lock_outlined,
                                  color: AppColors.inkSoft,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePass
                                      ? 'Hiện mật khẩu'
                                      : 'Ẩn mật khẩu',
                                  constraints: const BoxConstraints(
                                    minWidth: AppDimensions.minIconInteractive,
                                    minHeight: AppDimensions.minIconInteractive,
                                  ),
                                  icon: Icon(
                                    _obscurePass
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.inkSoft,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePass = !_obscurePass,
                                  ),
                                ),
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Mật khẩu phải từ 6 ký tự trở lên'
                                  : null,
                            ),
                          ),

                          // Các hành động còn lại chảy xuống dưới mốc giữa.
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Column(
                                children: [
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _loading
                                          ? null
                                          : _showPasswordResetHelp,
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(
                                          44,
                                          AppDimensions.minIconInteractive,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.xs,
                                        ),
                                        foregroundColor: AppColors.primary,
                                      ),
                                      child: const Text(
                                        'Quên mật khẩu?',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: AppColors.danger,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                color: AppColors.danger,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  AppButton(
                                    label: 'Đăng nhập',
                                    fullWidth: true,
                                    loading: _loading,
                                    onPressed: _submit,
                                  ),
                                  if (googleDangBat) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    NutGoogle(
                                      authService: widget.authService,
                                      disabled: _loading,
                                      khiXong: (_) => _vaoApp(),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.sm),
                                  AppButton(
                                    label: 'Dùng thử không cần tài khoản',
                                    fullWidth: true,
                                    variant: AppButtonVariant.secondary,
                                    icon: Icons.visibility_outlined,
                                    disabled: _loading,
                                    onPressed: _continueAsGuest,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      const Text(
                                        'Chưa có tài khoản? ',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          color: AppColors.inkSoft,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _loading
                                            ? null
                                            : () => Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        RegisterScreen(
                                                      authService:
                                                          widget.authService,
                                                    ),
                                                  ),
                                                ),
                                        style: TextButton.styleFrom(
                                          minimumSize: const Size(
                                            44,
                                            AppDimensions.minIconInteractive,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xs,
                                          ),
                                          foregroundColor: AppColors.primary,
                                        ),
                                        child: const Text(
                                          'Đăng ký ngay',
                                          style: TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
