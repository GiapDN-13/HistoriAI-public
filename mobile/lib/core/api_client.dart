import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Render free tier "ngủ" sau 15 phút; request đầu phải chờ server thức dậy
// (~30-50s). Để 60s để không bị timeout trong lúc cold-start.
const _defaultTimeout = Duration(seconds: 60);

class ApiException implements Exception {
  const ApiException({
    this.statusCode,
    required this.message,
    this.isConnectionError = false,
    this.chiTiet,
  });

  final int? statusCode;
  final String message;
  final bool isConnectionError;

  /// `detail` của máy chủ khi nó là một object — vd 402 hết lượt chat trả
  /// `{"ma":"het_luot_ngay","thong_bao":"...","gioi_han":10}`. Giữ lại để màn
  /// hình rẽ nhánh theo `ma` thay vì phải đoán từ câu chữ của `message`.
  final Map<String, dynamic>? chiTiet;

  /// Mã lỗi nghiệp vụ trong [chiTiet] (`detail.ma`), nếu có.
  String? get ma => chiTiet?['ma'] as String?;

  @override
  String toString() {
    if (isConnectionError) return 'Kết nối thất bại: $message';
    final code = statusCode ?? 0;
    return 'Lỗi API [$code]: $message';
  }
}

class ApiClient {
  /// `ApiClient()` luôn trả về **một instance dùng chung cho cả app**.
  ///
  /// Trước đây mỗi màn tự tạo một client riêng, nên token đăng nhập đặt ở
  /// màn này không tới được màn kia — `POST /quiz/submit` bị 401 và điểm
  /// không bao giờ lưu. Truyền [baseUrl] hoặc [httpClient] để tạo bản
  /// riêng (dùng trong test).
  factory ApiClient({String? baseUrl, http.Client? httpClient}) {
    if (baseUrl != null || httpClient != null) {
      return ApiClient._(baseUrl: baseUrl, httpClient: httpClient);
    }
    return _shared ??= ApiClient._();
  }

  ApiClient._({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl,
        _client = httpClient ?? http.Client();

  static String get _defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) return 'http://localhost:8000';
    return 'http://10.0.2.2:8000';
  }

  static ApiClient? _shared;

  /// Thay bản dùng chung bằng bản giả trong test màn hình (màn nào cũng gọi
  /// `ApiClient()`). Gọi `dispose()` của bản đó sau test để trả lại như cũ.
  @visibleForTesting
  static void datDungChungChoTest(ApiClient c) => _shared = c;

  final String baseUrl;
  final http.Client _client;
  String? _token;

  /// Đã có token đăng nhập hay chưa (dùng để hiện đúng trạng thái tài khoản).
  bool get isSignedIn => _token != null;

  /// Mã đăng nhập hiện tại — WebSocket không gắn được header, phải tự gửi mã
  /// trong gói đầu (lib/features/lop_hoc/truc_tiep/ket_noi_truc_tiep.dart).
  String? get maDangNhap => _token;

  void setToken(String token) => _token = token.isEmpty ? null : token;

  /// Gọi khi máy chủ từ chối mã đăng nhập (401): mã đã hết hạn, đã đăng xuất
  /// ở máy khác bằng "mọi thiết bị", hoặc mật khẩu vừa được đặt lại. AuthService
  /// gắn vào đây để xoá mã đã lưu — không thì app cứ tưởng còn đăng nhập, mọi
  /// lần lưu điểm đều hỏng lặng lẽ.
  void Function()? khiHetPhien;

  /// Mã máy bền, do lớp đo lường sinh và lưu lại.
  ///
  /// Gửi kèm mọi request để backend giới hạn tốc độ gọi LLM theo TỪNG MÁY chứ
  /// không theo địa chỉ IP. Cả lớp ngồi chung một wifi là chung một IP — siết
  /// theo IP thì người thứ hai trong lớp đã bị chặn.
  String? _maMay;

  set maMay(String? ma) => _maMay = (ma == null || ma.isEmpty) ? null : ma;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
        if (_maMay != null) 'X-Client-Id': _maMay!,
      };

  Future<dynamic> get(String path) => _request(
        () => _client.get(
          Uri.parse('$baseUrl/api/v1$path'),
          headers: _headers,
        ),
        // Thử lại 1 lần: cú GET đầu có thể trúng lúc Render đang thức dậy.
        retries: 1,
      );

  /// GET trả về CHỮ (vd tệp CSV) thay vì JSON.
  Future<String> getText(String path) async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/api/v1$path'), headers: _headers)
          .timeout(_defaultTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return utf8.decode(res.bodyBytes);
      }
      return _decode(res) as String; // ném ApiException với câu lỗi đọc được
    } on TimeoutException {
      throw const ApiException(
          message: 'Server không phản hồi.', isConnectionError: true);
    }
  }

  /// GET trả về BYTE (vd tệp Excel).
  Future<List<int>> getBytes(String path) async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/api/v1$path'), headers: _headers)
          .timeout(_defaultTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
      _decode(res); // ném ApiException với câu lỗi đọc được
      return const [];
    } on TimeoutException {
      throw const ApiException(message: 'Server không phản hồi.', isConnectionError: true);
    }
  }

  /// Không thử lại: DELETE không phải thao tác lặp lại vô hại.
  Future<dynamic> delete(String path) => _request(
        () => _client.delete(
          Uri.parse('$baseUrl/api/v1$path'),
          headers: _headers,
        ),
      );

  Future<dynamic> post(String path, Map<String, dynamic> body) => _request(
        () => _client.post(
          Uri.parse('$baseUrl/api/v1$path'),
          headers: _headers,
          body: jsonEncode(body),
        ),
      );

  Future<dynamic> patch(String path, Map<String, dynamic> body) => _request(
        () => _client.patch(
          Uri.parse('$baseUrl/api/v1$path'),
          headers: _headers,
          body: jsonEncode(body),
        ),
      );

  /// POST với body là list (dùng cho quiz submit).
  Future<dynamic> postJson(String path, Object body) => _request(
        () => _client.post(
          Uri.parse('$baseUrl/api/v1$path'),
          headers: _headers,
          body: jsonEncode(body),
        ),
      );

  Future<dynamic> postForm(String path, Map<String, String> fields) => _request(
        () => _client.post(
          Uri.parse('$baseUrl/api/v1$path'),
          headers: {
            if (_token != null) 'Authorization': 'Bearer $_token',
          },
          body: fields,
        ),
      );

  /// Gửi một tệp (multipart) — vd ảnh đại diện. Không thử lại.
  Future<dynamic> postFile(String path, String truong, List<int> bytes, String tenTep) => _request(
        () async {
          final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1$path'))
            ..files.add(http.MultipartFile.fromBytes(truong, bytes, filename: tenTep));
          if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
          if (_maMay != null) req.headers['X-Client-Id'] = _maMay!;
          return http.Response.fromStream(await _client.send(req));
        },
      );

  void dispose() {
    _client.close();
    // Bản dùng chung bị đóng thì bỏ luôn, lần gọi sau sẽ tạo client mới.
    if (identical(this, _shared)) _shared = null;
  }

  Future<dynamic> _request(
    Future<http.Response> Function() fn, {
    int retries = 0,
  }) async {
    try {
      final res = await fn().timeout(_defaultTimeout);
      // 502/503/504: server đang thức dậy (Render cold-start) -> thử lại.
      if (retries > 0 &&
          (res.statusCode == 502 ||
              res.statusCode == 503 ||
              res.statusCode == 504)) {
        await Future.delayed(const Duration(seconds: 2));
        return await _request(fn, retries: retries - 1);
      }
      if (res.statusCode == 401 && _token != null) {
        _token = null;
        khiHetPhien?.call();
      }
      return _decode(res);
    } on SocketException catch (e) {
      if (retries > 0) {
        await Future.delayed(const Duration(seconds: 2));
        return await _request(fn, retries: retries - 1);
      }
      throw ApiException(
        message: 'Không thể kết nối đến server'
            '${e.osError != null ? ' (${e.osError!.message})' : ''}.',
        isConnectionError: true,
      );
    } on HttpException catch (e) {
      throw ApiException(
        message: 'Lỗi mạng: ${e.message}',
        isConnectionError: true,
      );
    } on TimeoutException {
      if (retries > 0) {
        return await _request(fn, retries: retries - 1);
      }
      throw ApiException(
        message: 'Server không phản hồi sau $_defaultTimeout.',
        isConnectionError: true,
      );
    }
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    }

    final body = res.body.isNotEmpty ? utf8.decode(res.bodyBytes) : null;

    String message;
    Map<String, dynamic>? chiTiet;
    if (body != null && body.startsWith('{')) {
      try {
        final parsed = jsonDecode(body) as Map<String, dynamic>;
        message = _docLoi(parsed) ?? _loiChung(res.statusCode);
        final d = parsed['detail'];
        if (d is Map) chiTiet = d.cast<String, dynamic>();
      } catch (_) {
        message = _loiChung(res.statusCode);
      }
    } else {
      message = _loiChung(res.statusCode);
    }

    throw ApiException(
        statusCode: res.statusCode, message: message, chiTiet: chiTiet);
  }

  /// Rút một câu tiếng Việt đọc được từ thân phản hồi lỗi.
  ///
  /// Trả về null khi không hiểu được — tuyệt đối **không** ném nguyên JSON ra
  /// màn hình. Trước đây màn đăng ký in cả khối
  /// `{"detail":[{"type":"value_error",...}]}` cho người dùng đọc, vì FastAPI
  /// trả `detail` dạng **mảng** khi dữ liệu không hợp lệ, mà chỗ này lại ép
  /// kiểu thẳng sang String nên rơi vào nhánh bắt lỗi và in thô.
  static String? _docLoi(Map<String, dynamic> parsed) {
    final chiTiet = parsed['detail'] ?? parsed['message'];
    if (chiTiet is String && chiTiet.trim().isNotEmpty) return chiTiet;

    // `detail` dạng object lồng nhau, ví dụ đăng nhập sai mật khẩu:
    //   {"detail":{"error":{"code":"INVALID_CREDENTIALS","message":"Sai email
    //    hoặc mật khẩu"}}}
    // Thiếu nhánh này thì rơi xuống câu chung theo mã 401 — "Phiên đăng nhập
    // đã hết hạn" — nói sai hẳn chuyện đang xảy ra và làm người dùng đi tìm
    // nhầm nguyên nhân.
    if (chiTiet is Map) {
      for (final k in const ['message', 'msg', 'detail', 'thong_bao']) {
        final v = chiTiet[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
      final loi = chiTiet['error'];
      if (loi is Map) {
        final v = loi['message'];
        if (v is String && v.trim().isNotEmpty) return v;
      }
    }

    if (chiTiet is List && chiTiet.isNotEmpty) {
      final dau = chiTiet.first;
      if (dau is Map) {
        final truong = (dau['loc'] as List?)?.whereType<String>().last;
        final ten = _tenTruong[truong];
        final msg = dau['msg'];
        if (ten != null) return '$ten chưa hợp lệ. Hãy kiểm tra lại.';
        if (msg is String && msg.isNotEmpty) return msg;
      }
    }
    return null;
  }

  static String _loiChung(int ma) => switch (ma) {
        400 || 422 => 'Thông tin chưa hợp lệ. Hãy kiểm tra lại.',
        401 => 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.',
        403 => 'Bạn không có quyền thực hiện việc này.',
        404 => 'Không tìm thấy nội dung.',
        402 => 'Tính năng này cần HistoriAI Premium.',
        429 => 'Bạn thao tác hơi nhanh. Chờ một chút rồi thử lại.',
        _ => 'Hệ thống đang bận. Hãy thử lại sau ít phút.',
      };

  static const _tenTruong = {
    'email': 'Địa chỉ email',
    'password': 'Mật khẩu',
    'full_name': 'Họ và tên',
    'username': 'Tên đăng nhập',
  };

  /// SSE stream cho chat — gọi POST /chat/stream, trả về từng chunk text.
  ///
  /// [lichSu]: các lượt trước (cũ → mới) dạng {role, content} — để vĩ nhân nhớ
  /// ngữ cảnh ("vậy sau đó thì sao?"). Máy chủ chỉ dùng vài lượt cuối.
  Stream<String> streamChat(String figureSlug, String message,
      {List<Map<String, String>> lichSu = const []}) async* {
    final uri = Uri.parse('$baseUrl/api/v1/chat/stream');
    final request = http.Request('POST', uri)
      ..headers.addAll(_headers)
      ..body = jsonEncode({
        'figure_slug': figureSlug,
        'message': message,
        if (lichSu.isNotEmpty) 'history': lichSu,
        'nhan_nguon': true,   // hiểu dòng "[NGUON]…" — xem chat_screen.dart
      });
    final response = await _client.send(request);
    // Lỗi TRƯỚC khi stream (402 hết lượt, 429, 5xx) là một phản hồi JSON thường,
    // không có dòng "data: ". Không kiểm mã thì stream chỉ im lặng kết thúc và
    // người dùng nhận một câu trả lời rỗng thay vì biết mình đã hết lượt.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(await http.Response.fromStream(response)); // luôn ném ApiException
      return;
    }
    yield* response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data: '))
        .map((line) => line.substring(6))
        .takeWhile((chunk) => chunk != '[DONE]')
        // Backend escape '\n' -> '\\n' để giữ khung SSE; giải mã lại khi hiển thị.
        .map((chunk) => chunk.replaceAll('\\n', '\n'));
  }
}
