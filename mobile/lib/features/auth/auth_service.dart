import 'package:shared_preferences/shared_preferences.dart';
import '../../core/analytics.dart';
import '../../core/api_client.dart';
import '../../core/app_preferences.dart';
import '../../core/bai_lam_cho.dart';
import '../../core/nguon_truy_cap.dart';
import 'dang_nhap_google.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  final ApiClient _api;

  AuthService(this._api) {
    _api.khiHetPhien = () => SharedPreferences.getInstance()
        .then((prefs) => prefs.remove(_tokenKey));
  }

  Future<String?> get storedToken async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _api.postForm('/auth/login', {
      'username': email,
      'password': password,
    });
    final token = data['access_token'] as String;
    await _saveToken(token);
    _api.setToken(token);
    // Ghi ở đây, không ghi ở màn hình: mọi lối đăng nhập đều đi qua hàm này.
    Analytics.instance.log(Ev.loginSuccess);
    _guiBaiCho();
    return data;
  }

  Future<void> register(
    String fullName,
    String email,
    String password, {
    int? lop,
  }) async {
    // Đăng ký kèm nguồn đầu tiên của máy này — trả lời "người này đăng ký từ đâu"
    // ngay trên tài khoản, kể cả khi sau này họ đăng nhập từ máy khác.
    final nguon = await NguonTruyCap.dauTienDaNho();
    await _api.post('/auth/register', {
      'full_name': fullName,
      'email': email,
      'password': password,
      'role': 'student',
      if (lop != null) 'grade': lop,
      if (nguon != null) ...{
        'nguon': nguon.nguon,
        if (nguon.kenh != null) 'kenh': nguon.kenh,
        if (nguon.chienDich != null) 'chien_dich': nguon.chienDich,
      },
    });
    if (lop != null) await AppPreferences.setLopHoc(lop);
    Analytics.instance.log(Ev.signupSuccess);
  }

  /// Đăng nhập / đăng ký bằng ID token Google. Trả về true nếu tài khoản vừa tạo.
  /// Gửi kèm nguồn đầu tiên và lớp như đăng ký thường — máy chủ chỉ dùng khi tạo mới.
  Future<bool> dangNhapGoogle(String idToken, {int? lop}) async {
    final nguon = await NguonTruyCap.dauTienDaNho();
    final data = (await _api.post('/auth/google', {
      'id_token': idToken,
      if (lop != null) 'grade': lop,
      if (nguon != null) ...{
        'nguon': nguon.nguon,
        if (nguon.kenh != null) 'kenh': nguon.kenh,
        if (nguon.chienDich != null) 'chien_dich': nguon.chienDich,
      },
    }) as Map)
        .cast<String, dynamic>();
    final token = data['access_token'] as String;
    await _saveToken(token);
    _api.setToken(token);
    final moiTao = data['moi_tao'] == true;
    _guiBaiCho();
    if (moiTao && lop != null) await AppPreferences.setLopHoc(lop);
    Analytics.instance.log(moiTao ? Ev.signupSuccess : Ev.loginSuccess,
        them: {'cach': 'google'});
    return moiTao;
  }

  /// Đổi lớp đang học. Lưu trên máy trước để giao diện đổi ngay; đã đăng nhập
  /// thì gửi lên máy chủ — gửi lỗi cũng không sao, lần sau mở hồ sơ sẽ khớp lại.
  Future<void> capNhatLop(int? lop) async {
    await AppPreferences.setLopHoc(lop);
    if (!_api.isSignedIn) return;
    try {
      await _api.patch('/auth/me', {'grade': lop});
    } on ApiException {
      // giữ lựa chọn trên máy
    }
  }

  Future<bool> tryAutoLogin() async {
    final token = await storedToken;
    if (token == null || token.isEmpty) return false;
    _api.setToken(token);
    _guiBaiCho();   // bài nộp hỏng lần trước (mất mạng) — gửi lại
    return true;
  }

  Future<Map<String, dynamic>> fetchMe() async {
    final res = (await _api.get('/auth/me') as Map).cast<String, dynamic>();
    // Máy chủ là nguồn đúng khi đã có lớp; chưa có thì giữ lựa chọn trên máy.
    final lop = (res['grade'] as num?)?.toInt();
    if (lop != null && lop != AppPreferences.lopHoc.value) {
      await AppPreferences.setLopHoc(lop);
    }
    return res;
  }

  /// Đăng xuất: báo máy chủ thu hồi mã rồi mới xoá trên máy.
  ///
  /// Đăng xuất thường: máy chủ lỗi/mất mạng vẫn xoá trên máy — người dùng bấm
  /// đăng xuất thì phải ra được. [moiNoi] (mọi thiết bị) thì ngược lại: lỗi là
  /// báo lên, vì người dùng đang tin rằng các máy khác đã bị đá ra.
  Future<void> logout({bool moiNoi = false}) async {
    if (_api.isSignedIn) {
      try {
        await _api.post('/auth/logout${moiNoi ? '?moi_noi=true' : ''}', {});
      } catch (_) {
        if (moiNoi) rethrow;
      }
    }
    _api.setToken('');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await dangXuatGoogle();
  }

  /// Xin thư đặt lại mật khẩu. Trả về câu máy chủ báo (giống nhau dù email
  /// có tài khoản hay không).
  Future<String> quenMatKhau(String email) async {
    final res = await _api.post('/auth/quen-mat-khau', {'email': email});
    return (res is Map ? res['message'] as String? : null) ??
        'Nếu email này đã đăng ký, thư hướng dẫn sẽ tới trong vài phút.';
  }

  /// Lưu mã đăng nhập nhận được từ nơi khác /auth/login — vd vào phòng kiểm tra bằng
  /// tài khoản nhanh (tên + PIN). Từ đây em đó là người dùng đã đăng nhập như thường.
  Future<void> luuPhien(String token) async {
    await _saveToken(token);
    _api.setToken(token);
  }

  /// Bài quiz làm lúc là khách hoặc nộp hỏng → cộng vào tài khoản vừa đăng nhập.
  /// Chạy nền, lỗi thì để lần sau (xem core/bai_lam_cho.dart).
  void _guiBaiCho() {
    BaiLamCho.guiHet(_api).catchError((_) => 0);
  }

  /// Sửa họ tên / ảnh đại diện. Trả về hồ sơ mới từ máy chủ.
  Future<Map<String, dynamic>> capNhatHoSo({String? hoTen, String? anh}) async {
    final res = await _api.patch('/auth/me', {
      if (hoTen != null) 'full_name': hoTen,
      if (anh != null) 'avatar': anh,
    });
    return (res as Map).cast<String, dynamic>();
  }

  /// Tải ảnh đại diện riêng. Máy chủ cắt vuông, thu nhỏ, bỏ thông tin GPS trong ảnh.
  Future<Map<String, dynamic>> taiAnhDaiDien(List<int> bytes, String tenTep) async =>
      ((await _api.postFile('/auth/me/anh-dai-dien', 'anh', bytes, tenTep)) as Map)
          .cast<String, dynamic>();

  Future<Map<String, dynamic>> goAnhDaiDien() async =>
      ((await _api.delete('/auth/me/anh-dai-dien')) as Map).cast<String, dynamic>();

  /// Đổi mật khẩu (hoặc đặt lần đầu cho tài khoản Google — [cu] để null).
  /// Máy chủ đăng xuất mọi máy khác và trả mã mới cho máy này.
  Future<void> doiMatKhau({String? cu, required String moi}) async {
    final data = (await _api.post('/auth/doi-mat-khau', {
      if (cu != null) 'mat_khau_cu': cu,
      'mat_khau_moi': moi,
    }) as Map)
        .cast<String, dynamic>();
    final token = data['access_token'] as String;
    await _saveToken(token);
    _api.setToken(token);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Xoá vĩnh viễn tài khoản và toàn bộ tiến độ học.
  ///
  /// Xoá trên máy chủ trước rồi mới bỏ token: đảo thứ tự là mất token trong
  /// khi tài khoản vẫn còn, và người dùng không còn cách nào xoá nữa.
  Future<void> xoaTaiKhoan() async {
    await _api.delete('/auth/me');
    _api.setToken('');   // tài khoản đã xoá, không còn gì để thu hồi
    await logout();
  }
}
