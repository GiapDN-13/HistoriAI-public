import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'services/ga4.dart';

/// Tên các hành vi được đo. Dùng hằng thay vì gõ chuỗi thẳng vào màn hình:
/// gõ sai một chữ là đến lúc làm báo cáo mất luôn số của cả tính năng.
///
/// Danh sách này phải khớp với `EVENT_NAMES` trong
/// `backend/app/services/analytics.py` — backend từ chối tên lạ.
class Ev {
  // Vòng đời
  static const appOpen = 'app_open';
  static const signupStart = 'signup_start';
  static const signupSuccess = 'signup_success';
  static const loginSuccess = 'login_success';
  // Khám phá nội dung
  static const timelineView = 'timeline_view';
  static const eventOpen = 'event_open';
  static const videoPlay = 'video_play';
  static const arOpen = 'ar_open';
  static const arView = 'ar_view';
  // Ba tính năng cốt lõi
  static const chatOpen = 'chat_open';
  static const chatMessageSent = 'chat_message_sent';
  static const chatVoicePlay = 'chat_voice_play';
  static const quizStart = 'quiz_start';
  static const quizSubmit = 'quiz_submit';
  static const quizResultView = 'quiz_result_view';
  // Chỉ dẫn tại chỗ trong từng màn — target là tên màn, value là số bước.
  static const chiDanView = 'chi_dan_view';
  static const chiDanDone = 'chi_dan_done';
  static const chiDanSkip = 'chi_dan_skip';
  // Hướng dẫn lần đầu — value là SỐ TRANG, nhờ đó biết người ta bỏ ngang ở đâu.
  static const onboardingView = 'onboarding_view';
  static const onboardingDone = 'onboarding_done';
  static const onboardingSkip = 'onboarding_skip';
  // Doanh thu
  static const premiumView = 'premium_view';
  static const premiumCtaClick = 'premium_cta_click';
}

/// Ghi lại người dùng làm gì trong app.
///
/// Mỗi hành vi được gửi tới **hai nơi**:
///   1. Backend của nhóm (`POST /analytics/track`) — số hiện ngay, không phụ
///      thuộc tài khoản Google, và là nguồn cho trang dashboard.
///   2. Google Analytics 4 — chỉ chạy trên web và chỉ khi build có truyền
///      `--dart-define=GA4_ID=G-XXXXXXX`; dùng để đối chiếu và xem retention.
///
/// Nguyên tắc: **đo lường không bao giờ được làm hỏng trải nghiệm**. Mọi lỗi
/// mạng đều bị nuốt, không có await nào chặn giao diện.
class Analytics {
  Analytics._();

  static final Analytics instance = Analytics._();

  static const _khoaClientId = 'analytics_client_id';

  /// Gom event rồi gửi theo lô cho đỡ tốn request; 2 giây là đủ ngắn để
  /// không mất mấy khi người dùng đóng tab, đủ dài để gộp được một cụm thao tác.
  static const _doTre = Duration(seconds: 2);
  static const _nguongGuiNgay = 10;   // đủ 10 event thì gửi luôn, không đợi
  static const _toiDaMoiLo = 50;      // backend chặn quá 50 event một lần
  static const _toiDaHangDoi = 200;   // mạng hỏng lâu thì bỏ bớt, không phình mãi

  ApiClient? _api;
  String? _clientId;
  late String _sessionId;
  bool _batDau = false;
  bool _dangGui = false;
  bool _tat = false;   // chỉ test bật, để không timer nào sống sót

  final List<Map<String, dynamic>> _hangDoi = [];
  Timer? _hen;

  /// Bật đo lường. Gọi một lần trong `main()`, không cần await.
  Future<void> khoiDong(ApiClient api) async {
    if (_tat || _batDau) return;
    _batDau = true;
    _api = api;
    _sessionId = _sinhMa();

    // client_id sống lâu hơn phiên: nhờ nó mà đếm được "bao nhiêu người
    // quay lại hôm sau", kể cả người chưa bao giờ đăng nhập.
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_khoaClientId);
      if (id == null || id.isEmpty) {
        id = _sinhMa();
        await prefs.setString(_khoaClientId, id);
      }
      _clientId = id;
    } catch (_) {
      // Trình duyệt chặn localStorage (chế độ ẩn danh) — vẫn đo được, chỉ là
      // mỗi lần mở app bị tính như một người mới.
      _clientId = _sinhMa();
    }

    // Chia mã máy cho ApiClient: backend siết tốc độ gọi LLM theo mã này thay
    // vì theo IP, nhờ đó cả lớp ngồi chung một wifi vẫn dùng được bình thường.
    ApiClient().maMay = _clientId;

    Ga4.khoiDong();

    // Vài event đầu (app_open) có thể đã xếp hàng trong lúc đọc
    // shared_preferences — giờ mới đủ client_id để gửi.
    if (_hangDoi.isNotEmpty) unawaited(guiNgay());
  }

  final _nguoiNghe = <void Function(String ten, String? target)>[];

  /// Đăng ký nghe mọi hành vi được ghi. Không gửi đi đâu, chỉ gọi lại trong app.
  void nghe(void Function(String ten, String? target) ham) => _nguoiNghe.add(ham);

  /// Ghi một hành vi.
  ///
  /// [target] là slug của thứ người dùng đang xem (sự kiện, vĩ nhân, hiện vật).
  /// [value] là con số đi kèm — số câu đúng, số giây xem video.
  void log(String ten, {String? target, int? value, Map<String, dynamic>? them}) {
    // Báo cho phần trong app cần biết người dùng vừa làm gì (vd thẻ "Bắt đầu từ
    // đây" đánh dấu bước đã xong) — chạy cả khi đo lường tắt.
    for (final nghe in List.of(_nguoiNghe)) {
      try {
        nghe(ten, target);
      } catch (_) {}
    }
    if (_tat || !_batDau) return;

    Ga4.gui(ten, target: target, value: value, them: them);

    _hangDoi.add({
      'name': ten,
      'session_id': _sessionId,
      'platform': _nenTang,
      if (target != null) 'target': target,
      if (value != null) 'value': value,
      if (them != null) 'params': them,
      'client_ts': DateTime.now().toUtc().toIso8601String(),
    });

    // Mạng hỏng kéo dài thì bỏ những event cũ nhất, giữ cái mới hơn.
    if (_hangDoi.length > _toiDaHangDoi) {
      _hangDoi.removeRange(0, _hangDoi.length - _toiDaHangDoi);
    }

    if (_hangDoi.length >= _nguongGuiNgay) {
      unawaited(guiNgay());
    } else {
      _hen?.cancel();
      _hen = Timer(_doTre, () => unawaited(guiNgay()));
    }
  }

  /// Đẩy hết những gì đang chờ lên backend. Lỗi thì giữ lại để gửi lần sau.
  Future<void> guiNgay() async {
    _hen?.cancel();
    _hen = null;
    if (_dangGui || _hangDoi.isEmpty) return;

    final api = _api;
    final clientId = _clientId;
    // khoiDong() còn đang đọc shared_preferences: cứ để event nằm trong hàng
    // đợi, chính khoiDong() sẽ gọi lại hàm này khi xong.
    if (api == null || clientId == null) return;

    _dangGui = true;
    final lo = _hangDoi.take(_toiDaMoiLo).toList();
    var xong = false;
    try {
      await api.post('/analytics/track', {
        'events': [
          for (final e in lo) {...e, 'client_id': clientId},
        ],
      });
      _hangDoi.removeRange(0, lo.length);
      xong = true;
    } catch (_) {
      // Nuốt lỗi: Render free hay ngủ, và số liệu không đáng để người dùng
      // nhìn thấy một thông báo lỗi. Lô này nằm lại, đi kèm lần gửi sau.
    } finally {
      _dangGui = false;
    }

    // Chỉ hẹn tiếp khi vừa gửi trót lọt mà hàng đợi còn dư. Hẹn lại sau khi
    // lỗi là tự tạo vòng lặp vô tận — đốt pin, dội request, và treo test.
    if (xong && _hangDoi.isNotEmpty) {
      _hen = Timer(_doTre, () => unawaited(guiNgay()));
    }
  }

  String get _nenTang {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }

  /// Mã ngẫu nhiên 22 ký tự — đủ để không đụng nhau ở quy mô của nhóm,
  /// không cần kéo thêm gói uuid.
  String _sinhMa() {
    const bang = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    final phan = List.generate(10, (_) => bang[r.nextInt(bang.length)]).join();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$phan';
  }

  /// Chỉ dùng trong test. Không truyền [api] thì đo lường tắt hẳn — gọi ở
  /// `setUp()` của widget test để không có timer nào sống sót qua bài test.
  @visibleForTesting
  void datLaiChoTest({ApiClient? api, String clientId = 'test-client'}) {
    _hen?.cancel();
    _hen = null;
    _hangDoi.clear();
    // Không có api = tắt hẳn, kể cả khi main() gọi khoiDong() sau đó.
    _tat = api == null;
    _batDau = api != null;
    _api = api;
    _clientId = clientId;
    // Đặt lên đúng client đang dùng trong test, không đụng tới bản dùng chung.
    (api ?? ApiClient()).maMay = clientId;
    _sessionId = 'test-session';
    _dangGui = false;
  }

  @visibleForTesting
  int get soDangCho => _hangDoi.length;
}
