import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_service.dart';

/// Hộp đổi mật khẩu. [coMatKhau] false (tài khoản tạo bằng Google): "Đặt mật khẩu",
/// không hỏi mật khẩu cũ. Trả về true khi đã đổi.
Future<bool?> hoiDoiMatKhau(
  BuildContext context,
  AuthService authService, {
  required bool coMatKhau,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _HopDoiMatKhau(authService: authService, coMatKhau: coMatKhau),
  );
}

class _HopDoiMatKhau extends StatefulWidget {
  const _HopDoiMatKhau({required this.authService, required this.coMatKhau});

  final AuthService authService;
  final bool coMatKhau;

  @override
  State<_HopDoiMatKhau> createState() => _HopDoiMatKhauState();
}

class _HopDoiMatKhauState extends State<_HopDoiMatKhau> {
  final _cu = TextEditingController();
  final _moi = TextEditingController();
  final _lai = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _dangGui = false;
  bool _an = true;
  String? _loi;

  @override
  void dispose() {
    _cu.dispose();
    _moi.dispose();
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
      await widget.authService.doiMatKhau(
        cu: widget.coMatKhau ? _cu.text : null,
        moi: _moi.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Không kết nối được. Kiểm tra mạng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  InputDecoration _o(String nhan) => InputDecoration(
        labelText: nhan,
        suffixIcon: IconButton(
          tooltip: _an ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          icon: Icon(_an ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _an = !_an),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(widget.coMatKhau ? 'Đổi mật khẩu' : 'Đặt mật khẩu'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.coMatKhau)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Tài khoản này tạo bằng Google. Đặt mật khẩu để đăng nhập được '
                    'cả bằng email + mật khẩu.',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                  ),
                ),
              if (widget.coMatKhau)
                TextFormField(
                  controller: _cu,
                  obscureText: _an,
                  autofillHints: const [AutofillHints.password],
                  decoration: _o('Mật khẩu hiện tại'),
                  validator: (v) => (v ?? '').isEmpty ? 'Nhập mật khẩu hiện tại' : null,
                ),
              TextFormField(
                controller: _moi,
                obscureText: _an,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _o('Mật khẩu mới (ít nhất 8 ký tự)'),
                validator: (v) => (v ?? '').length < 8 ? 'Cần ít nhất 8 ký tự' : null,
              ),
              TextFormField(
                controller: _lai,
                obscureText: _an,
                decoration: _o('Nhập lại mật khẩu mới'),
                validator: (v) => v != _moi.text ? 'Hai lần nhập chưa khớp' : null,
              ),
              const SizedBox(height: 10),
              const Text(
                'Đổi xong, các máy khác đang đăng nhập tài khoản này sẽ phải đăng nhập lại.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
              ),
              if (_loi != null) ...[
                const SizedBox(height: 10),
                Text(_loi!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _dangGui ? null : () => Navigator.pop(context, false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _dangGui ? null : _gui,
          child: Text(_dangGui ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
    );
  }
}
