import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/api_client.dart';
import '../lop_hoc_api.dart';

/// Một đường WebSocket — tách thành giao diện để test thay bằng kênh giả.
abstract class KenhTrucTiep {
  Future<void> get sanSang;
  Stream<dynamic> get nhan;
  void gui(String tin);
  int? get maDong;
  Future<void> dong();
}

class _KenhWs implements KenhTrucTiep {
  _KenhWs(Uri uri) : _c = WebSocketChannel.connect(uri);

  final WebSocketChannel _c;

  @override
  Future<void> get sanSang => _c.ready;
  @override
  Stream<dynamic> get nhan => _c.stream;
  @override
  void gui(String tin) => _c.sink.add(tin);
  @override
  int? get maDong => _c.closeCode;
  @override
  Future<void> dong() async {
    try {
      await _c.sink.close();
    } catch (_) {}
  }
}

typedef MoKenh = KenhTrucTiep Function(Uri uri);

enum DuongNoi { dangNoi, websocket, hoiDinhKy }

/// Giữ kết nối tới MỘT phòng thi trực tiếp, cho cả máy học sinh lẫn máy giáo viên.
///
/// Đường chính: WebSocket (máy chủ đẩy câu mới xuống ngay). Hỏng thì tự chuyển sang HỎI
/// LẠI ĐỊNH KỲ endpoint trạng thái (2 giây/lần) và thử nối lại WebSocket sau 1, 2, 4… giây
/// — mạng trường hay chặn WebSocket, hoặc proxy cắt kết nối im lặng. Màn hình không cần
/// biết đang đi đường nào: chỉ đọc [trangThai].
///
/// Máy chủ gửi TRỌN trạng thái mỗi lần (không gửi phần thay đổi), nên mất gói tin hay nối
/// lại giữa chừng cũng không lệch: gói kế tiếp là đúng. Gói tới lệch thứ tự thì bỏ gói
/// có `phien` nhỏ hơn.
class KetNoiTrucTiep extends ChangeNotifier {
  KetNoiTrucTiep({
    required this.ma,
    LopHocApi? api,
    MoKenh? moKenh,
    this.nhipHoi = const Duration(seconds: 2),
  })  : api = api ?? LopHocApi(),
        _moKenh = moKenh ?? _KenhWs.new;

  final String ma;
  final LopHocApi api;
  final MoKenh _moKenh;
  final Duration nhipHoi;

  Map<String, dynamic>? trangThai;

  /// Lúc đồng hồ câu hiện tại về 0, theo đồng hồ CỦA MÁY NÀY (máy chủ gửi số mili-giây còn
  /// lại chứ không gửi giờ tuyệt đối — đồng hồ điện thoại lệch vài giây là chuyện thường).
  DateTime? hanLuc;
  DuongNoi duong = DuongNoi.dangNoi;

  /// Lỗi không nối lại được (hết phiên, không thuộc phòng) — màn hình nên mời vào lại.
  String? loiChet;

  /// Câu báo ngắn (vd "Hết giờ mất rồi.") — màn hình hiện rồi tự xoá khi sang câu mới.
  String? thongBao;

  final Map<int, String> _daChon = {};
  int? _choXacNhan;
  KenhTrucTiep? _kenh;
  StreamSubscription<dynamic>? _nghe;
  Timer? _ping;
  Timer? _hoi;
  Timer? _noiLai;
  int _lanHong = 0;
  int _phien = 0;
  bool _huy = false;

  String get pha => '${trangThai?['pha'] ?? ''}';
  int? get cauSo => (trangThai?['cau_so'] as num?)?.toInt();
  bool get laGiaoVien => trangThai?['vai'] == 'gv';

  /// Đáp án em đã chọn cho câu [cau] — máy chủ xác nhận thì lấy của máy chủ.
  String? daChon(int? cau) {
    if (cau == null) return null;
    final cuaToi = trangThai?['cua_toi'];
    if (cau == cauSo && cuaToi is Map && cuaToi['da_chon'] != null) return '${cuaToi['da_chon']}';
    return _daChon[cau];
  }

  void batDau() => _noi();

  Future<void> _noi() async {
    if (_huy || loiChet != null) return;
    final tok = api.maDangNhap;
    if (tok == null) {
      _chet('Phiên đăng nhập đã hết. Hãy vào lại phòng.');
      return;
    }
    final KenhTrucTiep kenh;
    try {
      kenh = _moKenh(api.wsUri(ma));
    } catch (_) {
      _hong(null);
      return;
    }
    _kenh = kenh;
    try {
      await kenh.sanSang.timeout(const Duration(seconds: 8));
    } catch (_) {
      _hong(kenh);
      return;
    }
    if (_huy || !identical(kenh, _kenh)) {
      unawaited(kenh.dong());
      return;
    }
    kenh.gui(jsonEncode({'loai': 'xac_thuc', 'token': tok}));
    _nghe = kenh.nhan.listen(
      _nhanTin,
      onDone: () => _hong(kenh),
      onError: (Object _) => _hong(kenh),
      cancelOnError: true,
    );
    _ping?.cancel();
    // Cloudflare cắt kết nối im lặng quá 100 giây — sảnh chờ có thể im cả phút.
    _ping = Timer.periodic(const Duration(seconds: 25), (_) => _guiWs({'loai': 'ping'}));
  }

  void _hong(KenhTrucTiep? kenh) {
    if (_huy || (kenh != null && !identical(kenh, _kenh))) return;
    _ping?.cancel();
    _nghe?.cancel();
    _nghe = null;
    _kenh = null;
    final ma = kenh?.maDong;
    if (ma == 4401 || ma == 4403 || ma == 4404) {
      _chet(thongBao ??
          (ma == 4401 ? 'Phiên đăng nhập đã hết. Hãy vào lại phòng.' : 'Em chưa vào phòng này.'));
      return;
    }
    _lanHong++;
    duong = DuongNoi.hoiDinhKy;
    notifyListeners();
    _batHoi();
    final cho = Duration(seconds: [1, 2, 4, 8, 15][(_lanHong - 1).clamp(0, 4)]);
    _noiLai?.cancel();
    _noiLai = Timer(cho, _noi);
  }

  void _chet(String loi) {
    loiChet = loi;
    _ping?.cancel();
    _hoi?.cancel();
    _noiLai?.cancel();
    notifyListeners();
  }

  void _batHoi() {
    if (_hoi != null) return;
    _hoiMot();
    _hoi = Timer.periodic(nhipHoi, (_) => _hoiMot());
  }

  void _dungHoi() {
    _hoi?.cancel();
    _hoi = null;
  }

  Future<void> _hoiMot() async {
    try {
      final t = await api.trangThaiTrucTiep(ma);
      if (!_huy) _apDung(t);
    } on ApiException catch (e) {
      if (_huy) return;
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) _chet(e.message);
    } catch (_) {
      // mất mạng hẳn — lần hỏi sau thử lại
    }
  }

  void _nhanTin(dynamic raw) {
    final Object? t;
    try {
      t = jsonDecode('$raw');
    } catch (_) {
      return;
    }
    if (t is! Map) return;
    final tin = t.cast<String, dynamic>();
    switch (tin['loai']) {
      case 'trang_thai':
        if (duong != DuongNoi.websocket) {
          duong = DuongNoi.websocket;
          _lanHong = 0;
          _dungHoi();
        }
        _apDung(tin);
      case 'da_nhan':
        _choXacNhan = null;
        final cs = (tin['cau_so'] as num?)?.toInt();
        if (cs != null) _daChon[cs] = '${tin['chon']}';
        notifyListeners();
      case 'loi':
        thongBao = '${tin['thong_bao'] ?? ''}';
        if (_choXacNhan != null) {
          _daChon.remove(_choXacNhan); // máy chủ không nhận (hết giờ…) → bỏ lựa chọn tạm
          _choXacNhan = null;
        }
        notifyListeners();
    }
  }

  void _apDung(Map<String, dynamic> t) {
    if (t['loai'] != null && t['loai'] != 'trang_thai') return;
    final p = (t['phien'] as num?)?.toInt() ?? 0;
    if (p != 0 && p < _phien) return;
    _phien = p;
    final cu = cauSo;
    final phaCu = pha;
    trangThai = t;
    final ms = (t['con_lai_ms'] as num?)?.toInt();
    hanLuc = (t['pha'] == 'dang_hoi' && ms != null) ? DateTime.now().add(Duration(milliseconds: ms)) : null;
    if (cu != cauSo || phaCu != pha) thongBao = null;
    notifyListeners();
  }

  void _guiWs(Map<String, dynamic> tin) {
    try {
      _kenh?.gui(jsonEncode(tin));
    } catch (_) {
      _hong(_kenh);
    }
  }

  Future<void> traLoi(int cau, String chon) async {
    if (daChon(cau) != null || pha != 'dang_hoi' || cau != cauSo) return;
    _daChon[cau] = chon; // hiện ngay là đã chọn, không chờ máy chủ
    thongBao = null;
    notifyListeners();
    if (duong == DuongNoi.websocket && _kenh != null) {
      _choXacNhan = cau;
      _guiWs({'loai': 'tra_loi', 'cau_so': cau, 'chon': chon});
      return;
    }
    try {
      await api.traLoiTrucTiep(ma, cau, chon);
    } on ApiException catch (e) {
      _daChon.remove(cau);
      thongBao = e.message;
      notifyListeners();
    } catch (_) {
      _daChon.remove(cau);
      thongBao = 'Chưa gửi được — mạng chập chờn, chọn lại nhé.';
      notifyListeners();
    }
  }

  /// Lệnh của giáo viên: bat_dau | ket_thuc_cau | cau_tiep | ket_thuc. Gửi kèm câu ĐANG
  /// THẤY để bấm đúp không nhảy hai câu (máy chủ bỏ lệnh cũ).
  Future<void> dieuKhien(String lenh) async {
    final tuCau = cauSo;
    if (duong == DuongNoi.websocket && _kenh != null) {
      _guiWs({'loai': 'dieu_khien', 'lenh': lenh, 'tu_cau': tuCau});
      return;
    }
    try {
      _apDung(await api.dieuKhienTrucTiep(ma, lenh, tuCau));
    } on ApiException catch (e) {
      thongBao = e.message;
      notifyListeners();
    } catch (_) {
      thongBao = 'Không gửi được lệnh — kiểm tra mạng.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _huy = true;
    _ping?.cancel();
    _hoi?.cancel();
    _noiLai?.cancel();
    _nghe?.cancel();
    final k = _kenh;
    if (k != null) unawaited(k.dong());
    super.dispose();
  }
}
