import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_service.dart';
import 'lam_bai_screen.dart';
import 'lop_hoc_api.dart';
import 'giao_dien/san_choi.dart';
import 'truc_tiep/thi_truc_tiep_screen.dart';

/// Học sinh vào phòng kiểm tra: quét QR (mở thẳng historiai.org/vao/<mã>) hoặc gõ mã.
///
/// Chưa có tài khoản thì ĐĂNG KÝ NHANH: họ tên + lớp + PIN 4 số — không email, không mật
/// khẩu dài, làm xong trong ~20 giây. Vào lại đúng tên + PIN (máy khác, lỡ tắt trang) là
/// lấy lại bài đang làm.
class VaoPhongScreen extends StatefulWidget {
  const VaoPhongScreen({super.key, this.authService, this.ma, this.api});

  final AuthService? authService;
  final String? ma;
  final LopHocApi? api;

  @override
  State<VaoPhongScreen> createState() => _VaoPhongScreenState();
}

class _VaoPhongScreenState extends State<VaoPhongScreen> {
  late final _api = widget.api ?? LopHocApi();
  late final _maCtl = TextEditingController(text: widget.ma ?? '');
  final _tenCtl = TextEditingController();
  final _lopCtl = TextEditingController();
  final _pinCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _phong;
  bool _dangTai = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    if ((widget.ma ?? '').length == 6) _timPhong();
  }

  @override
  void dispose() {
    for (final c in [_maCtl, _tenCtl, _lopCtl, _pinCtl]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _ma => _maCtl.text.trim();

  Future<void> _timPhong() async {
    if (_ma.length != 6) {
      setState(() => _loi = 'Mã phòng gồm 6 chữ số.');
      return;
    }
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final p = await _api.xemPhong(_ma);
      if (mounted) setState(() => _phong = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _loi = 'Không kết nối được. Kiểm tra mạng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  Future<void> _vao() async {
    if (!_api.daDangNhap && !_formKey.currentState!.validate()) return;
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final r = await _api.vao(
        _ma,
        hoTen: _api.daDangNhap ? null : _tenCtl.text.trim(),
        pin: _api.daDangNhap ? null : _pinCtl.text.trim(),
        lop: _lopCtl.text.trim(),
      );
      // Tài khoản nhanh cũng là tài khoản thật: lưu phiên như đăng nhập thường, để điểm
      // vào lịch sử học và lần sau mở app vẫn là em.
      await (widget.authService ?? AuthService(ApiClient()))
          .luuPhien(r['access_token'] as String);
      if (!mounted) return;
      final tieuDe = '${_phong?['tieu_de'] ?? 'Bài kiểm tra'}';
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => _phong?['che_do'] == 'truc_tiep'
            ? ThiTrucTiepScreen(
                ma: _ma, tieuDe: tieuDe) // sảnh chờ, câu hiện theo nhịp thầy cô
            : LamBaiScreen(ma: _ma, tieuDe: tieuDe),
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _loi = 'Không kết nối được. Kiểm tra mạng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _phong;
    return KhungLopHoc(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        title: const Text('VÀO PHÒNG KIỂM TRA'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          if (p == null) ...[
            const LoiChaoSanChoi(
                tieuDe: 'Cả lớp cùng thử tài',
                moTa: 'Nhập mã thầy cô đưa. Sân chơi lịch sử đang chờ em!'),
            const SizedBox(height: 24),
            const Text('Nhập mã phòng thầy cô đưa (6 chữ số)',
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
            const SizedBox(height: 10),
            TextField(
              controller: _maCtl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 28,
                letterSpacing: 8,
              ),
              decoration:
                  const InputDecoration(counterText: '', hintText: '000000'),
              onSubmitted: (_) => _timPhong(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _dangTai ? null : _timPhong,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              child: Text(_dangTai ? 'Đang tìm…' : 'Tìm phòng'),
            ),
          ] else ...[
            _TheThongTin(phong: p),
            const SizedBox(height: 20),
            if (p['dang_mo'] != true)
              const Text(
                  'Phòng đã đóng — không nhận bài mới. Nếu em đã vào từ trước, nhập đúng tên và PIN để xem lại bài.',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      color: AppColors.danger)),
            if (_api.daDangNhap) ...[
              const Text(
                  'Em đang đăng nhập — bài sẽ lưu vào tài khoản hiện tại.',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      color: AppColors.inkSoft)),
              const SizedBox(height: 10),
              TextField(
                  controller: _lopCtl,
                  decoration: const InputDecoration(
                      labelText: 'Lớp (vd 8A2) — không bắt buộc')),
            ] else
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _tenCtl,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 60,
                    decoration: const InputDecoration(
                        labelText: 'Họ và tên', counterText: ''),
                    validator: (v) =>
                        (v ?? '').trim().length < 2 ? 'Nhập họ tên' : null,
                  ),
                  TextFormField(
                    controller: _lopCtl,
                    maxLength: 20,
                    decoration: const InputDecoration(
                        labelText: 'Lớp (vd 8A2)', counterText: ''),
                  ),
                  TextFormField(
                    controller: _pinCtl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Tự đặt mã PIN 4 số',
                      helperText: 'Nhớ PIN để vào lại và làm tiếp.',
                      counterText: '',
                    ),
                    validator: (v) =>
                        RegExp(r'^\d{4}$').hasMatch((v ?? '').trim())
                            ? null
                            : 'PIN gồm 4 chữ số',
                  ),
                ]),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _dangTai ? null : _vao,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: Text(_dangTai ? 'Đang vào…' : 'Vào làm bài'),
            ),
            TextButton(
              onPressed: _dangTai ? null : () => setState(() => _phong = null),
              child: const Text('Nhập mã khác'),
            ),
          ],
          if (_loi != null) ...[
            const SizedBox(height: 12),
            Text(_loi!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

class _TheThongTin extends StatelessWidget {
  const _TheThongTin({required this.phong});

  final Map<String, dynamic> phong;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: imperialDarkGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold.withValues(alpha: .7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${phong['tieu_de']}',
                style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppColors.onRed)),
            const SizedBox(height: 6),
            Text(
                '${phong['so_cau']} câu · ${phong['giay_moi_cau']} giây mỗi câu'
                '${(phong['giao_vien'] ?? '').toString().isNotEmpty ? ' · ${phong['giao_vien']}' : ''}',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    color: AppColors.onRed.withValues(alpha: .85))),
            const SizedBox(height: 6),
            Text('Mã phòng ${phong['ma']}',
                style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldBright,
                    letterSpacing: 1)),
          ],
        ),
      );
}
