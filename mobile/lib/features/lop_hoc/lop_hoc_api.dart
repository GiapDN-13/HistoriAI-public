import '../../core/api_client.dart';

/// Gọi API chế độ kiểm tra cho lớp học (backend/app/api/routes/lop_hoc.py).
///
/// Trả thẳng Map/List như máy chủ gửi — các màn tự đọc trường cần dùng. Giai đoạn 1
/// còn ít màn, chưa đáng dựng lớp dữ liệu riêng cho từng loại.
class LopHocApi {
  LopHocApi([ApiClient? api]) : _api = api ?? ApiClient();

  final ApiClient _api;

  bool get daDangNhap => _api.isSignedIn;

  // ---- giáo viên ----
  Future<void> lamGiaoVien(String ma) => _api.post('/auth/lam-giao-vien', {'ma': ma});

  Future<List<Map<String, dynamic>>> khoCau() async =>
      (await _api.get('/lop/kho-cau') as List).cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> taoDe(String tieuDe, List<int> cauIds, int giayMoiCau) async =>
      (await _api.post('/lop/de', {
        'tieu_de': tieuDe,
        'cau_ids': cauIds,
        'giay_moi_cau': giayMoiCau,
      }) as Map)
          .cast<String, dynamic>();

  Future<List<Map<String, dynamic>>> dsDe() async =>
      (await _api.get('/lop/de') as List).cast<Map<String, dynamic>>();

  /// [cheDo]: 'bai_tap' (mỗi em tự làm) hoặc 'truc_tiep' (giáo viên chuyển từng câu).
  /// [lopId]: mở cho một lớp cố định (giai đoạn 3) — vào thống kê của lớp.
  Future<Map<String, dynamic>> moPhong(int deId,
          {int? hanPhut, bool tronCau = true, String cheDo = 'bai_tap', int? lopId}) async =>
      (await _api.post('/lop/phong', {
        'de_id': deId,
        if (hanPhut != null) 'han_phut': hanPhut,
        'tron_cau': tronCau,
        if (cheDo != 'bai_tap') 'che_do': cheDo,
        if (lopId != null) 'lop_id': lopId,
      }) as Map)
          .cast<String, dynamic>();

  Future<List<Map<String, dynamic>>> dsPhong() async =>
      (await _api.get('/lop/phong') as List).cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> bang(String ma) async =>
      (await _api.get('/lop/phong/$ma/bang') as Map).cast<String, dynamic>();

  Future<void> dongPhong(String ma) => _api.post('/lop/phong/$ma/dong', {});

  Future<String> csv(String ma) => _api.getText('/lop/phong/$ma/csv');

  /// Bảng điểm Excel thật (.xlsx, 3 trang: Bảng điểm / Từng câu / Chi tiết).
  Future<List<int>> excel(String ma) => _api.getBytes('/lop/phong/$ma/xlsx');

  // ---- giai đoạn 3: câu tự soạn (backend/app/api/routes/lop_hoc_mo_rong.py) ----
  Future<List<Map<String, dynamic>>> dsCauRieng() async =>
      (await _api.get('/lop/cau-rieng') as List).cast<Map<String, dynamic>>();

  /// [cau]: question, option_a…d, correct_option, explanation, event_slug.
  Future<Map<String, dynamic>> taoCauRieng(Map<String, dynamic> cau) async =>
      (await _api.post('/lop/cau-rieng', cau) as Map).cast<String, dynamic>();

  Future<Map<String, dynamic>> suaCauRieng(int id, Map<String, dynamic> doi) async =>
      (await _api.patch('/lop/cau-rieng/$id', doi) as Map).cast<String, dynamic>();

  Future<void> xoaCauRieng(int id) => _api.delete('/lop/cau-rieng/$id');

  /// Dán nhiều câu: [luu] = false chỉ xem trước (máy chủ chỉ ra câu lỗi).
  Future<Map<String, dynamic>> nhapNhieuCau(String vanBan, {required bool luu}) async =>
      (await _api.post('/lop/cau-rieng/nhap', {'van_ban': vanBan, 'luu': luu}) as Map)
          .cast<String, dynamic>();

  // ---- giai đoạn 3: lớp cố định + thống kê ----
  Future<List<Map<String, dynamic>>> dsLop() async =>
      (await _api.get('/lop/lop-hoc') as List).cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> taoLop(String ten) async =>
      (await _api.post('/lop/lop-hoc', {'ten': ten}) as Map).cast<String, dynamic>();

  Future<void> doiTenLop(int id, String ten) => _api.patch('/lop/lop-hoc/$id', {'ten': ten});

  Future<void> xoaLop(int id) => _api.delete('/lop/lop-hoc/$id');

  Future<Map<String, dynamic>> chiTietLop(int id) async =>
      (await _api.get('/lop/lop-hoc/$id') as Map).cast<String, dynamic>();

  Future<void> themThanhVien(int lopId, String ten) =>
      _api.post('/lop/lop-hoc/$lopId/thanh-vien', {'ten': ten});

  Future<void> boThanhVien(int lopId, int tvId) => _api.delete('/lop/lop-hoc/$lopId/thanh-vien/$tvId');

  /// [lopId] null = gỡ phòng khỏi lớp.
  Future<void> ganLop(String ma, int? lopId) => _api.post('/lop/phong/$ma/gan-lop', {'lop_id': lopId});

  Future<Map<String, dynamic>> thongKeLop(int id) async =>
      (await _api.get('/lop/lop-hoc/$id/thong-ke') as Map).cast<String, dynamic>();

  /// Tài khoản nhanh (tên + PIN) thêm email thật + mật khẩu. Trả mã đăng nhập MỚI —
  /// mã cũ hết hiệu lực, bên gọi phải lưu lại (AuthService.luuPhien).
  Future<String> giuTaiKhoan(String email, String matKhau) async =>
      ((await _api.post('/auth/giu-tai-khoan', {'email': email, 'mat_khau': matKhau}) as Map)['access_token'])
          as String;

  // ---- học sinh ----
  Future<Map<String, dynamic>> xemPhong(String ma) async =>
      (await _api.get('/phong/$ma') as Map).cast<String, dynamic>();

  /// Chưa đăng nhập thì cần [hoTen] + [pin]; đã đăng nhập thì chỉ cần [lop] (tuỳ).
  Future<Map<String, dynamic>> vao(String ma, {String? hoTen, String? pin, String? lop}) async =>
      (await _api.post('/phong/$ma/vao', {
        if (hoTen != null) 'ho_ten': hoTen,
        if (pin != null) 'pin': pin,
        if (lop != null && lop.isNotEmpty) 'lop': lop,
      }) as Map)
          .cast<String, dynamic>();

  Future<Map<String, dynamic>> layDe(String ma) async =>
      (await _api.get('/phong/$ma/de') as Map).cast<String, dynamic>();

  Future<bool> traLoi(String ma, int cau, String chon) async =>
      ((await _api.post('/phong/$ma/tra-loi', {'question_id': cau, 'chon': chon}) as Map)['dung']) ==
      true;

  Future<Map<String, dynamic>> nop(String ma) async =>
      (await _api.post('/phong/$ma/nop', {}) as Map).cast<String, dynamic>();

  /// Bảng vàng của phòng cho học sinh: top 10 + hạng của em (sau khi nộp / hết trận).
  Future<Map<String, dynamic>> bangVang(String ma) async =>
      (await _api.get('/phong/$ma/xep-hang') as Map).cast<String, dynamic>();

  // ---- chế độ trực tiếp (backend/app/api/routes/lop_hoc_truc_tiep.py) ----
  // Đường chính là WebSocket; ba hàm REST dưới là đường DỰ PHÒNG khi WebSocket hỏng.
  String? get maDangNhap => _api.maDangNhap;

  Uri wsUri(String ma) {
    final goc = Uri.parse(_api.baseUrl.isEmpty ? Uri.base.origin : _api.baseUrl);
    return goc.replace(
      scheme: goc.scheme == 'https' ? 'wss' : 'ws',
      path: '${goc.path.replaceAll(RegExp(r'/$'), '')}/api/v1/ws/phong/$ma',
    );
  }

  Future<Map<String, dynamic>> trangThaiTrucTiep(String ma) async =>
      (await _api.get('/phong/$ma/truc-tiep') as Map).cast<String, dynamic>();

  Future<void> traLoiTrucTiep(String ma, int cauSo, String chon) =>
      _api.post('/phong/$ma/truc-tiep/tra-loi', {'cau_so': cauSo, 'chon': chon});

  Future<Map<String, dynamic>> dieuKhienTrucTiep(String ma, String lenh, int? tuCau) async =>
      (await _api.post('/lop/phong/$ma/truc-tiep', {'lenh': lenh, 'tu_cau': tuCau}) as Map)
          .cast<String, dynamic>();
}
