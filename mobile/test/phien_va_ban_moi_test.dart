import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/core/ban_moi.dart';
import 'package:historiai/features/auth/auth_service.dart';
import 'package:historiai/main.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Báo bản cài mới', () {
    const moi = {
      'phien_ban': '0.3.0',
      'build': 3,
      'link': 'https://historiai.org/tai-app/',
    };

    test('có bản mới hơn thì báo', () {
      final tt = BanMoi.canBao(buildDangChay: 2, duLieu: moi, daBaoBuild: null);
      expect(tt?.build, 3);
      expect(tt?.phienBan, '0.3.0');
    });

    test('đang chạy bản mới nhất hoặc mới hơn thì im', () {
      expect(BanMoi.canBao(buildDangChay: 3, duLieu: moi, daBaoBuild: null), isNull);
      expect(BanMoi.canBao(buildDangChay: 4, duLieu: moi, daBaoBuild: null), isNull);
    });

    test('mỗi bản chỉ hỏi một lần — trừ khi bắt buộc', () {
      expect(BanMoi.canBao(buildDangChay: 2, duLieu: moi, daBaoBuild: 3), isNull);
      final batBuoc = {...moi, 'bat_buoc': true};
      expect(BanMoi.canBao(buildDangChay: 2, duLieu: batBuoc, daBaoBuild: 3), isNotNull);
    });

    test('tệp hỏng thì im lặng, không ném lỗi', () {
      expect(BanMoi.canBao(buildDangChay: 2, duLieu: const {}, daBaoBuild: null), isNull);
      expect(BanMoi.canBao(buildDangChay: 2, duLieu: const {'build': 9}, daBaoBuild: null),
          isNull);
    });
  });

  test('số build của bản tách theo loại máy (2009, 1009) vẫn so đúng', () {
    const moi = {'build': 2010, 'link': 'https://historiai.org/tai-app/'};
    expect(BanMoi.canBao(buildDangChay: 2009, duLieu: moi, daBaoBuild: null)?.build, 10);
    expect(BanMoi.canBao(buildDangChay: 1009, duLieu: moi, daBaoBuild: null), isNotNull);
    expect(BanMoi.canBao(buildDangChay: 2010, duLieu: moi, daBaoBuild: null), isNull);
    expect(BanMoi.canBao(buildDangChay: 1010, duLieu: moi, daBaoBuild: null), isNull);
    // mỗi bản chỉ hỏi một lần: số đã lưu là số thật
    expect(BanMoi.canBao(buildDangChay: 2009, duLieu: moi, daBaoBuild: 10), isNull);
  });

  group('Tự tải bản cài', () {
    Map<String, dynamic> du(Map<String, dynamic> apk) =>
        {'build': 3, 'link': 'https://historiai.org/tai-app/', 'apk': apk};

    test('đọc link bản cài theo loại máy', () {
      final tt = BanMoi.canBao(buildDangChay: 2, daBaoBuild: null, duLieu: du({
        'arm64': {'url': 'https://historiai.org/tai-app/a64.apk?v=1', 'byte': 100},
        'arm32': {'url': 'https://historiai.org/tai-app/a32.apk?v=1'},
      }))!;
      expect(tt.apk['arm64']!.byte, 100);
      expect(tt.apk['arm32']!.byte, isNull);
    });

    test('không tải từ nơi khác historiai.org hoặc không https', () {
      final tt = BanMoi.canBao(buildDangChay: 2, daBaoBuild: null, duLieu: du({
        'arm64': {'url': 'https://ke-xau.com/a.apk'},
        'arm32': {'url': 'http://historiai.org/a.apk'},
      }))!;
      expect(tt.apk, isEmpty);
    });

    test('phien-ban.json cũ (chưa có apk) vẫn báo, chỉ không tự tải', () {
      final tt = BanMoi.canBao(
          buildDangChay: 2, daBaoBuild: null,
          duLieu: const {'build': 3, 'link': 'https://historiai.org/tai-app/'})!;
      expect(tt.apk, isEmpty);
    });

    test('chọn đúng bản theo loại máy', () {
      const a64 = BanCai('u64', 1), a32 = BanCai('u32', 1);
      const ca2 = {'arm64': a64, 'arm32': a32};
      expect(BanMoi.chonBanCai(['arm64-v8a', 'armeabi-v7a'], ca2), a64);
      expect(BanMoi.chonBanCai(['armeabi-v7a', 'armeabi'], ca2), a32);
      expect(BanMoi.chonBanCai(['x86_64'], ca2), isNull);
      expect(BanMoi.chonBanCai(['arm64-v8a'], const {'arm32': a32}), isNull);
    });
  });

  group('Phiên đăng nhập', () {
    tearDown(() => ApiClient().dispose());

    test('máy chủ trả 401 thì bỏ mã và báo AuthService', () async {
      var daBao = false;
      final api = ApiClient(
        baseUrl: 'http://kiem-thu',
        httpClient: MockClient((_) async => http.Response('{"detail":"x"}', 401)),
      )
        ..setToken('ma-da-thu-hoi')
        ..khiHetPhien = () => daBao = true;
      await expectLater(api.get('/auth/me'), throwsA(isA<ApiException>()));
      expect(api.isSignedIn, isFalse);
      expect(daBao, isTrue);
    });

    test('đăng xuất báo máy chủ thu hồi, mất mạng vẫn ra được', () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'ma'});
      final goi = <String>[];
      final api = ApiClient(
        baseUrl: 'http://kiem-thu',
        httpClient: MockClient((req) async {
          goi.add(req.url.toString());
          throw http.ClientException('mất mạng');
        }),
      )..setToken('ma');
      await AuthService(api).logout();
      expect(goi.single, 'http://kiem-thu/api/v1/auth/logout');
      expect(api.isSignedIn, isFalse);
      expect((await SharedPreferences.getInstance()).getString('auth_token'), isNull);
    });

    test('đăng xuất mọi thiết bị mà lỗi thì báo lên, không giả vờ xong', () async {
      final api = ApiClient(
        baseUrl: 'http://kiem-thu',
        httpClient: MockClient((_) async => http.Response('', 500)),
      )..setToken('ma');
      await expectLater(AuthService(api).logout(moiNoi: true), throwsA(anything));
    });
  });

  test('Sentry: bỏ header và chuỗi truy vấn', () {
    final e = SentryEvent(
      request: SentryRequest(
        url: 'https://historiai.org/?utm_source=fb&key=bimat',
        method: 'GET',
        headers: const {'Authorization': 'Bearer x'},
      ),
    );
    final ra = locSuKienSentry(e, Hint())!;
    expect(ra.request?.url, 'https://historiai.org/');
    expect(ra.request?.headers, isEmpty);
  });
}
