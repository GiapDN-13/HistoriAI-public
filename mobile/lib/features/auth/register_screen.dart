import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/analytics.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/chon_lop.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../shell/main_navigation_shell.dart';
import 'auth_service.dart';
import 'dang_nhap_google.dart';
import 'login_screen.dart';

/// Màn hình Đăng ký tài khoản (khắc phục Mục 11.1 SPEC_UI_UX.md).
/// Giữ nguyên lời gọi đo lường signupStart theo R3, Việt hoá 100%, bỏ italic.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  int? _lop;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Bắt buộc ghi nhận event đo lường signupStart theo R3
    Analytics.instance.log(Ev.signupStart);

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.authService.register(
        _nameCtl.text.trim(),
        _emailCtl.text.trim(),
        _passCtl.text,
        lop: _lop,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(authService: widget.authService),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Đã có lỗi xảy ra trong quá trình đăng ký.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DongSonBackground(
        size: 340,
        opacity: 0.04,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/brand/logo.png',
                      height: 72,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tạo Tài Khoản HistoriAI',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        color: AppColors.red,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Lưu lại hành trình và điểm số đấu trường lịch sử của bạn',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.inkSoft,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Họ và tên
                    TextFormField(
                      controller: _nameCtl,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.ink,
                          fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Họ và tên',
                        labelStyle: const TextStyle(
                            fontFamily: 'Inter', color: AppColors.inkSoft),
                        prefixIcon: const Icon(Icons.person_outline,
                            color: AppColors.inkSoft, size: 20),
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.red, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập tên của bạn'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Email
                    TextFormField(
                      controller: _emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.ink,
                          fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(
                            fontFamily: 'Inter', color: AppColors.inkSoft),
                        prefixIcon: const Icon(Icons.email_outlined,
                            color: AppColors.inkSoft, size: 20),
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.red, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập email hợp lệ'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Mật khẩu
                    TextFormField(
                      controller: _passCtl,
                      obscureText: _obscurePass,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.ink,
                          fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        labelStyle: const TextStyle(
                            fontFamily: 'Inter', color: AppColors.inkSoft),
                        prefixIcon: const Icon(Icons.lock_outlined,
                            color: AppColors.inkSoft, size: 20),
                        suffixIcon: IconButton(
                          tooltip:
                              _obscurePass ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.inkSoft,
                            size: 19,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.red, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      validator: (v) => (v == null || v.length < 8)
                          ? 'Mật khẩu cần ít nhất 8 ký tự'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Xác nhận mật khẩu
                    TextFormField(
                      controller: _confirmCtl,
                      obscureText: _obscureConfirm,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.ink,
                          fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Xác nhận mật khẩu',
                        labelStyle: const TextStyle(
                            fontFamily: 'Inter', color: AppColors.inkSoft),
                        prefixIcon: const Icon(Icons.lock_clock_outlined,
                            color: AppColors.inkSoft, size: 20),
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirm
                              ? 'Hiện mật khẩu xác nhận'
                              : 'Ẩn mật khẩu xác nhận',
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.inkSoft,
                            size: 19,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.red, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      validator: (v) => (v != _passCtl.text)
                          ? 'Mật khẩu xác nhận không khớp'
                          : null,
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Em đang học lớp mấy? (không bắt buộc)',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Để phần tóm tắt dễ hay khó vừa sức em.',
                      style: TextStyle(
                          fontFamily: 'Inter', fontSize: 12.5, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    ChonLop(lop: _lop, onChanged: (l) => setState(() => _lop = l)),

                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.danger, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                    fontFamily: 'Inter',
                                    color: AppColors.danger,
                                    fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Nút Đăng ký
                    AppButton(
                      label: 'Tạo tài khoản',
                      fullWidth: true,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    if (googleDangBat) ...[
                      const SizedBox(height: 14),
                      // Không cần gõ họ tên, mật khẩu: lấy từ Google. Lớp đã chọn ở
                      // trên vẫn được gửi kèm.
                      NutGoogle(
                        authService: widget.authService,
                        lop: _lop,
                        disabled: _loading,
                        khiXong: (_) => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MainNavigationShell(
                                authService: widget.authService),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Nói trước khi thu, không phải sau. Đặt ngay tại chỗ tạo
                    // tài khoản vì đó mới là lúc người dùng quyết định giao dữ
                    // liệu của mình.
                    Center(
                      child: TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse('https://historiai.org/rieng-tu/'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text(
                          'Tạo tài khoản tức là bạn đồng ý với Chính sách quyền riêng tư',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.inkSoft,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),

                    // Chuyển sang Đăng nhập
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Đã có tài khoản? ',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.inkSoft,
                              fontSize: 13.5),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoginScreen(
                                    authService: widget.authService),
                              )),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Đăng nhập ngay',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: AppColors.red,
                              fontSize: 13.5,
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
          ),
        ),
      ),
    );
  }
}
