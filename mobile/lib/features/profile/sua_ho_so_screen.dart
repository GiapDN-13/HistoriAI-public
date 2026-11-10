import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/anh_dai_dien.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_service.dart';

/// Sửa họ tên và chọn ảnh đại diện. Trả về true khi đã lưu (để màn Hồ sơ nạp lại).
class SuaHoSoScreen extends StatefulWidget {
  const SuaHoSoScreen({
    super.key,
    required this.authService,
    required this.hoTen,
    this.anh,
  });

  final AuthService authService;
  final String hoTen;
  final String? anh;

  @override
  State<SuaHoSoScreen> createState() => _SuaHoSoScreenState();
}

class _SuaHoSoScreenState extends State<SuaHoSoScreen> {
  late final _tenCtl = TextEditingController(text: widget.hoTen);
  final _formKey = GlobalKey<FormState>();
  late String? _anh = widget.anh;
  bool _dangLuu = false;
  String? _loi;

  @override
  void dispose() {
    _tenCtl.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      await widget.authService.capNhatHoSo(
        hoTen: _tenCtl.text.trim(),
        // Chỉ gửi khi chọn một ảnh TRONG BỘ có sẵn và có đổi — ảnh tự tải lên đã lưu
        // ngay lúc tải; gửi mã "tl-…" qua đây máy chủ sẽ báo "không có trong bộ ảnh".
        anh: AnhDaiDien.bo.containsKey(_anh) && _anh != widget.anh ? _anh : null,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Không kết nối được. Kiểm tra mạng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  bool _dangTaiAnh = false;

  Future<void> _taiAnh() async {
    final chon = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Thu nhỏ ngay trên máy: ảnh điện thoại 4–6 MB tải lâu, máy chủ chỉ giữ 320×320
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (chon == null) return;
    setState(() {
      _dangTaiAnh = true;
      _loi = null;
    });
    try {
      final me = await widget.authService.taiAnhDaiDien(await chon.readAsBytes(), chon.name);
      if (!mounted) return;
      setState(() => _anh = me['avatar'] as String?);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Chưa tải được ảnh. Kiểm tra mạng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _dangTaiAnh = false);
    }
  }

  Future<void> _goAnh() async {
    setState(() => _dangTaiAnh = true);
    try {
      await widget.authService.goAnhDaiDien();
      if (!mounted) return;
      setState(() => _anh = null);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Chưa gỡ được ảnh. Thử lại sau nhé.');
    } finally {
      if (mounted) setState(() => _dangTaiAnh = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: const Text('SỬA HỒ SƠ'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Center(child: AnhDaiDien.vong(_anh, size: 96)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _dangTaiAnh ? null : _taiAnh,
                  icon: _dangTaiAnh
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_camera_rounded),
                  label: Text(_dangTaiAnh ? 'Đang tải…' : 'Tải ảnh của em'),
                ),
                if (AnhDaiDien.laAnhTaiLen(_anh))
                  TextButton(onPressed: _dangTaiAnh ? null : _goAnh, child: const Text('Gỡ ảnh')),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Ảnh hiện trên hồ sơ và bảng vàng — các bạn cùng lớp sẽ thấy.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
            ),
            const SizedBox(height: 20),
            const Text('Hoặc chọn một ảnh có sẵn',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final ma in AnhDaiDien.bo.keys)
                  Semantics(
                    button: true,
                    selected: _anh == ma,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _anh = ma),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _anh == ma ? AppColors.red : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: AnhDaiDien.vong(ma, size: 52),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _tenCtl,
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                helperText: 'Bảng vàng chỉ hiện tên gọi + chữ đầu của họ (vd "An N.").',
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 2) return 'Họ tên cần ít nhất 2 ký tự';
                return null;
              },
            ),
            if (_loi != null) ...[
              const SizedBox(height: 12),
              Text(_loi!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _dangLuu ? null : _luu,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(_dangLuu ? 'Đang lưu…' : 'Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }
}
