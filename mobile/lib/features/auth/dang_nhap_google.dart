import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'auth_service.dart';
import 'nut_google_stub.dart' if (dart.library.js_interop) 'nut_google_web.dart';

/// Client ID loại "Web application" trong Google Cloud Console. Dựng kèm
/// `--dart-define=GOOGLE_CLIENT_ID=...` mới hiện nút; trống = ẩn hẳn.
/// Android dùng CHÍNH ID này làm serverClientId (để Google cấp ID token mà máy
/// chủ kiểm được), cộng một client ID Android khai SHA-1 của khoá phát hành.
const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

bool get googleDangBat => googleClientId.isNotEmpty;

Future<void>? _khoiDong;

Future<void> _damBaoKhoiDong() => _khoiDong ??= GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? googleClientId : null,
      serverClientId: kIsWeb ? null : googleClientId,
    );

/// Bỏ phiên Google trên máy (để lần sau chọn được tài khoản khác). Lỗi thì thôi.
Future<void> dangXuatGoogle() async {
  if (!googleDangBat || _khoiDong == null) return;
  try {
    await GoogleSignIn.instance.signOut();
  } catch (_) {}
}

/// Nút "Tiếp tục với Google" — một nút cho cả đăng nhập lẫn đăng ký.
class NutGoogle extends StatefulWidget {
  const NutGoogle({
    super.key,
    required this.authService,
    required this.khiXong,
    this.lop,
    this.disabled = false,
  });

  final AuthService authService;

  /// Gọi khi đã có phiên HistoriAI. `moiTao`: tài khoản vừa được tạo.
  final void Function(bool moiTao) khiXong;

  /// Lớp đang chọn ở màn đăng ký (chỉ dùng khi tạo tài khoản mới).
  final int? lop;
  final bool disabled;

  @override
  State<NutGoogle> createState() => _NutGoogleState();
}

class _NutGoogleState extends State<NutGoogle> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _nghe;
  bool _dangXuLy = false;
  bool _sanSang = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    if (!googleDangBat) return;
    _damBaoKhoiDong().then((_) {
      if (!mounted) return;
      // Web: mã về qua luồng sự kiện sau khi bấm nút GIS. Android thì lấy thẳng
      // từ authenticate() — không nghe luồng để khỏi xử lý hai lần.
      if (kIsWeb) {
        _nghe = GoogleSignIn.instance.authenticationEvents.listen((e) {
          if (e is GoogleSignInAuthenticationEventSignIn) {
            _guiMa(e.user.authentication.idToken);
          }
        }, onError: (_) => _baoLoi('Chưa đăng nhập được bằng Google. Hãy thử lại.'));
      }
      setState(() => _sanSang = true);
    }).catchError((_) {
      if (mounted) _baoLoi('Không mở được đăng nhập Google trên máy này.');
    });
  }

  @override
  void dispose() {
    _nghe?.cancel();
    super.dispose();
  }

  void _baoLoi(String chu) => setState(() {
        _loi = chu;
        _dangXuLy = false;
      });

  Future<void> _bamAndroid() async {
    setState(() {
      _dangXuLy = true;
      _loi = null;
    });
    try {
      final tk = await GoogleSignIn.instance.authenticate();
      await _guiMa(tk.authentication.idToken);
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      if (e.code == GoogleSignInExceptionCode.canceled) {
        setState(() => _dangXuLy = false);   // người dùng tự đóng — không phải lỗi
      } else {
        _baoLoi('Chưa đăng nhập được bằng Google. Hãy thử lại.');
      }
    } catch (_) {
      if (mounted) _baoLoi('Chưa đăng nhập được bằng Google. Hãy thử lại.');
    }
  }

  Future<void> _guiMa(String? idToken) async {
    if (idToken == null) {
      _baoLoi('Google không trả về thông tin đăng nhập. Hãy thử lại.');
      return;
    }
    setState(() {
      _dangXuLy = true;
      _loi = null;
    });
    try {
      final moiTao = await widget.authService.dangNhapGoogle(idToken, lop: widget.lop);
      if (!mounted) return;
      setState(() => _dangXuLy = false);
      widget.khiXong(moiTao);
    } on ApiException catch (e) {
      if (mounted) _baoLoi(e.message);
    } catch (_) {
      if (mounted) _baoLoi('Không kết nối được. Kiểm tra mạng rồi thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!googleDangBat) return const SizedBox.shrink();
    final Widget nut;
    if (_dangXuLy) {
      nut = const SizedBox(
          height: 44,
          child: Center(
              child: SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))));
    } else if (kIsWeb) {
      nut = _sanSang ? nutGoogleWeb() : const SizedBox(height: 44);
    } else {
      nut = OutlinedButton.icon(
        onPressed: (!_sanSang || widget.disabled) ? null : _bamAndroid,
        icon: const Text('G',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF4285F4))),
        label: const Text('Tiếp tục với Google'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: AppColors.ink.withValues(alpha: 0.25)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(child: Divider(color: AppColors.ink.withValues(alpha: 0.15))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('hoặc',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
          ),
          Expanded(child: Divider(color: AppColors.ink.withValues(alpha: 0.15))),
        ]),
        const SizedBox(height: 10),
        Center(child: nut),
        if (_loi != null) ...[
          const SizedBox(height: 8),
          Text(_loi!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger, fontSize: 13)),
        ],
      ],
    );
  }
}
