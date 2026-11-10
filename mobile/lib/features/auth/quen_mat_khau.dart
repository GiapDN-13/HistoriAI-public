import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'auth_service.dart';

/// Hộp "Quên mật khẩu?": nhập email → máy chủ gửi link đặt lại mật khẩu.
///
/// Link trong thư mở trang web `/dat-lai-mat-khau/` (cả người dùng bản cài
/// Android cũng đặt mật khẩu ở đó), rồi quay lại app đăng nhập bằng mật khẩu mới.
Future<void> hoiQuenMatKhau(
  BuildContext context,
  AuthService authService, {
  String email = '',
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _HopQuenMatKhau(authService: authService, email: email),
  );
}

class _HopQuenMatKhau extends StatefulWidget {
  const _HopQuenMatKhau({required this.authService, required this.email});

  final AuthService authService;
  final String email;

  @override
  State<_HopQuenMatKhau> createState() => _HopQuenMatKhauState();
}

class _HopQuenMatKhauState extends State<_HopQuenMatKhau> {
  late final _emailCtl = TextEditingController(text: widget.email);
  final _formKey = GlobalKey<FormState>();
  bool _dangGui = false;
  String? _loi;
  String? _daGui;

  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      final chu = await widget.authService.quenMatKhau(_emailCtl.text.trim());
      if (mounted) setState(() => _daGui = chu);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loi = 'Không kết nối được. Kiểm tra mạng rồi thử lại.');
      }
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daGui = _daGui;
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Quên mật khẩu'),
      content: daGui != null
          ? Text(daGui)
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhập email bạn đã dùng để đăng ký. Chúng tôi sẽ gửi link đặt lại mật khẩu.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autofocus: widget.email.isEmpty,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Hãy nhập email';
                      if (!t.contains('@') || !t.contains('.')) {
                        return 'Email chưa đúng định dạng';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _dangGui ? null : _gui(),
                  ),
                  if (_loi != null) ...[
                    const SizedBox(height: 10),
                    Text(_loi!, style: const TextStyle(color: AppColors.danger)),
                  ],
                ],
              ),
            ),
      actions: daGui != null
          ? [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: _dangGui ? null : _gui,
                child: Text(_dangGui ? 'Đang gửi…' : 'Gửi thư'),
              ),
            ],
    );
  }
}
