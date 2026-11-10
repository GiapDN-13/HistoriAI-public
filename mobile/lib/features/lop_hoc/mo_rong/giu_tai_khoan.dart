import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../auth/auth_service.dart';
import '../lop_hoc_api.dart';

/// Tài khoản nhanh = tài khoản tạo lúc vào phòng kiểm tra bằng tên + PIN. Máy chủ gán
/// email tổng hợp ở miền này (backend/app/api/routes/lop_hoc.py, MIEN_EMAIL_NHANH).
const mienEmailNhanh = 'nhanh.historiai.org';

bool laTaiKhoanNhanh(String? email) =>
    (email ?? '').toLowerCase().endsWith('@$mienEmailNhanh');

/// Thẻ mời trên màn Hồ sơ: tài khoản nhanh chỉ vào lại được đúng phòng bằng tên + PIN —
/// mất máy/xoá trình duyệt là mất XP, lịch sử. Thêm email thì giữ được mãi.
class LoiMoiGiuTaiKhoan extends StatelessWidget {
  const LoiMoiGiuTaiKhoan({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.goldBright.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold),
            ),
            child: const Row(children: [
              Icon(Icons.shield_moon_outlined, color: AppColors.goldDark),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Giữ tài khoản: thêm email',
                          style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                      SizedBox(height: 2),
                      Text(
                          'Tài khoản tạo nhanh trong phòng kiểm tra. Thêm email để giữ điểm, XP và '
                          'lịch sử học, đăng nhập được trên máy khác.',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              color: AppColors.inkSoft,
                              fontSize: 12.5)),
                    ]),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.goldDark),
            ]),
          ),
        ),
      );
}

/// Hộp nhập email + mật khẩu. Trả về true khi đã giữ tài khoản (mã đăng nhập mới đã lưu).
Future<bool?> hoiGiuTaiKhoan(BuildContext context, AuthService authService,
        {LopHocApi? api}) =>
    showDialog<bool>(
      context: context,
      builder: (_) =>
          _HopGiuTaiKhoan(authService: authService, api: api ?? LopHocApi()),
    );

class _HopGiuTaiKhoan extends StatefulWidget {
  const _HopGiuTaiKhoan({required this.authService, required this.api});

  final AuthService authService;
  final LopHocApi api;

  @override
  State<_HopGiuTaiKhoan> createState() => _HopGiuTaiKhoanState();
}

class _HopGiuTaiKhoanState extends State<_HopGiuTaiKhoan> {
  final _email = TextEditingController();
  final _mk = TextEditingController();
  final _lai = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _an = true;
  bool _dangGui = false;
  String? _loi;

  @override
  void dispose() {
    _email.dispose();
    _mk.dispose();
    _lai.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      final ma = await widget.api.giuTaiKhoan(_email.text.trim(), _mk.text);
      // Máy chủ đã thu hồi mã cũ (cấp lúc vào phòng) — phải lưu mã mới ngay.
      await widget.authService.luuPhien(ma);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _loi = 'Không kết nối được. Kiểm tra mạng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Giữ tài khoản'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Bài kiểm tra, XP và lịch sử học giữ nguyên. Từ giờ em đăng nhập bằng email và mật '
              'khẩu này (có thể dùng email của bố mẹ).',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.inkSoft,
                  fontSize: 13),
            ),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) {
                final e = (v ?? '').trim();
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e))
                  return 'Email chưa đúng';
                if (laTaiKhoanNhanh(e)) return 'Hãy dùng email thật';
                return null;
              },
            ),
            TextFormField(
              controller: _mk,
              obscureText: _an,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Mật khẩu (ít nhất 8 ký tự)',
                suffixIcon: IconButton(
                  tooltip: _an ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  icon: Icon(_an
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _an = !_an),
                ),
              ),
              validator: (v) =>
                  (v ?? '').length < 8 ? 'Cần ít nhất 8 ký tự' : null,
            ),
            TextFormField(
              controller: _lai,
              obscureText: _an,
              decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu'),
              validator: (v) => v != _mk.text ? 'Hai lần nhập chưa khớp' : null,
            ),
            const SizedBox(height: 10),
            const Text(
              'Sau khi giữ tài khoản, tên + mã PIN trong phòng không còn dùng để vào tài khoản này nữa.',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.inkMuted,
                  fontSize: 12),
            ),
            if (_loi != null) ...[
              const SizedBox(height: 10),
              Text(_loi!,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      color: AppColors.danger)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _dangGui ? null : () => Navigator.pop(context, false),
            child: const Text('Để sau')),
        FilledButton(
            onPressed: _dangGui ? null : _gui,
            child: Text(_dangGui ? 'Đang lưu…' : 'Giữ tài khoản')),
      ],
    );
  }
}
