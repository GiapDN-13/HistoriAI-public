import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:historiai/core/api_client.dart';

/// Client giả trả đúng một phản hồi lỗi, để soi câu chữ mà người dùng sẽ đọc.
ApiClient _clientTraLoi(int ma, String than) => ApiClient(
      baseUrl: 'http://kiem-thu',
      httpClient: MockClient((_) async =>
          http.Response(than, ma, headers: {'content-type': 'application/json'})),
    );

void main() {
  tearDown(() => ApiClient().dispose()); // trả về trạng thái sạch cho test sau

  test('ApiClient() trả về cùng một instance cho mọi màn hình', () {
    final tuManQuiz = ApiClient();
    final tuManChat = ApiClient();
    expect(identical(tuManQuiz, tuManChat), isTrue);
  });

  test('Đăng nhập ở một màn thì màn khác cũng gửi kèm token', () {
    // Lỗi cũ: mỗi màn tự tạo client riêng nên POST /quiz/submit không có
    // token -> backend trả 401 -> điểm quiz không bao giờ được lưu.
    final khiDangNhap = ApiClient();
    expect(khiDangNhap.isSignedIn, isFalse);

    khiDangNhap.setToken('token-that');

    final manQuizNopBai = ApiClient();
    expect(manQuizNopBai.isSignedIn, isTrue);
  });

  test('Đăng xuất xoá token trên toàn app', () {
    ApiClient().setToken('token-that');
    ApiClient().setToken(''); // AuthService.logout() gọi đúng cách này
    expect(ApiClient().isSignedIn, isFalse);
  });

  group('Lỗi từ máy chủ không bao giờ hiện dạng thô cho người dùng', () {
    test('422 với detail dạng mảng -> câu tiếng Việt, không phải JSON', () async {
      // Lỗi cũ: FastAPI trả detail là MẢNG khi dữ liệu không hợp lệ, mã lại ép
      // thẳng sang String nên rơi vào nhánh bắt lỗi và in nguyên khối JSON —
      // màn đăng ký từng hiện `{"detail":[{"type":"value_error",...}]}`.
      final api = _clientTraLoi(422, jsonEncode({
        'detail': [
          {
            'type': 'value_error',
            'loc': ['body', 'email'],
            'msg': 'value is not a valid email address',
          }
        ]
      }));
      addTearDown(api.dispose);

      final loi = await api.post('/auth/register', {}).then<Object?>(
          (_) => null, onError: (Object e) => e) as ApiException;

      expect(loi.message, isNot(contains('{')));
      expect(loi.message, isNot(contains('value_error')));
      expect(loi.message.toLowerCase(), contains('email'));
    });

    test('detail dạng chuỗi vẫn được giữ nguyên', () async {
      final api = _clientTraLoi(400, jsonEncode({'detail': 'Email đã được dùng'}));
      addTearDown(api.dispose);

      final loi = await api.post('/auth/register', {}).then<Object?>(
          (_) => null, onError: (Object e) => e) as ApiException;

      expect(loi.message, 'Email đã được dùng');
    });

    test('sai mật khẩu phải nói đúng là sai mật khẩu', () async {
      // Máy chủ trả detail dạng OBJECT LỒNG NHAU cho lỗi đăng nhập. Trước đây
      // chỉ xử lý chuỗi và mảng nên rơi xuống câu chung theo mã 401 —
      // "Phiên đăng nhập đã hết hạn" — trong khi người dùng vừa gõ sai mật
      // khẩu và chưa từng đăng nhập.
      final api = _clientTraLoi(401, jsonEncode({
        'detail': {
          'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Sai email hoặc mật khẩu'}
        }
      }));
      addTearDown(api.dispose);

      final loi = await api.post('/auth/login', {}).then<Object?>(
          (_) => null, onError: (Object e) => e) as ApiException;

      expect(loi.message, 'Sai email hoặc mật khẩu');
      expect(loi.message, isNot(contains('hết hạn')));
    });

    test('thân phản hồi không đọc được -> vẫn ra câu dễ hiểu', () async {
      final api = _clientTraLoi(500, '<html>Internal Server Error</html>');
      addTearDown(api.dispose);

      final loi = await api.post('/auth/register', {}).then<Object?>(
          (_) => null, onError: (Object e) => e) as ApiException;

      expect(loi.message, isNot(contains('<html>')));
      expect(loi.message, isNotEmpty);
    });
  });
}
