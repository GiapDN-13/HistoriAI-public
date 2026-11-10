import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:historiai/core/analytics.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/features/premium/het_luot_ngay.dart';
import 'package:historiai/features/premium/premium_chung.dart';
import 'package:historiai/features/premium/premium_screen.dart';
import 'package:historiai/features/premium/thanh_toan_screen.dart';

/// Luồng thanh toán Premium: màn giới thiệu, màn chuyển khoản, thẻ hết lượt chat.

const _json = {'content-type': 'application/json; charset=utf-8'};

http.Response _ok(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code, headers: _json);

/// Máy chủ giả. Đổi [bat], [trangThai], [premiumDen] giữa chừng để mô phỏng
/// tiền về / đơn hết hạn.
class _MayChuGia {
  bool bat = true;
  bool coGoiThu = false;
  bool loiMang = false;
  String trangThai = 'cho';
  String? premiumDen = '2026-12-01T00:00:00Z';
  bool laPremium = false;
  int soDonDaTao = 0;
  int soLanHoi = 0;

  ApiClient client() => ApiClient(
        baseUrl: 'http://test',
        httpClient: MockClient((req) async {
          final p = req.url.path;
          if (p.endsWith('/thanh-toan/goi')) {
            if (loiMang) throw http.ClientException('mất mạng');
            return _ok({
              'bat': bat,
              'goi': [
                {'ma': 'thang', 'ten': 'Premium 30 ngày', 'so_tien': 39000, 'so_ngay': 30},
                if (coGoiThu)
                  {'ma': 'thu', 'ten': 'Thử', 'so_tien': 2000, 'so_ngay': 1},
              ],
            });
          }
          if (p.endsWith('/thanh-toan/don') && req.method == 'POST') {
            soDonDaTao++;
            return _ok({
              'ma_don': 'HJ00000$soDonDaTao',
              'so_tien': 39000,
              'noi_dung': 'HJ00000$soDonDaTao',
              'ngan_hang': {'ten': 'MB Bank', 'so_tk': '0123456789', 'chu_tk': 'NGUYEN VAN A'},
              'qr_chuoi': '00020101021238570010A000000727012700069704220113012345678900208QRIBFTTA53037045405390005802VN6304ABCD',
              'het_han': DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(),
              'trang_thai': 'cho',
            });
          }
          if (p.contains('/thanh-toan/don/')) {
            soLanHoi++;
            return _ok({
              'ma_don': p.split('/').last,
              'trang_thai': trangThai,
              'so_tien': 39000,
              'premium_den': trangThai == 'da_tra' ? premiumDen : null,
            });
          }
          if (p.endsWith('/auth/me')) {
            return _ok({
              'full_name': 'Học sinh',
              'la_premium': laPremium,
              'premium_den': laPremium ? premiumDen : null,
            });
          }
          if (p.endsWith('/chat/stream')) {
            return _ok({
              'detail': {
                'ma': 'het_luot_ngay',
                'thong_bao': 'Bạn đã hết lượt hôm nay.',
                'gioi_han': 10,
              },
            }, 402);
          }
          return http.Response('{}', 404);
        }),
      );
}

const _bonQuyenLoi = [
  'Hỏi vĩ nhân không giới hạn',
  'Bản tin phụ huynh đầy đủ',
  'Ôn toàn bộ câu sai',
  'Trọn bài học theo lộ trình',
];

/// Khổ điện thoại 360x800 — cũng là khổ nhỏ nhất màn phải dùng được.
///
/// [cao]: màn Premium nay dài (bốn quyền lợi + bảng so sánh) nên ListView không dựng
/// hết phần dưới ở khổ 800 — test nào cần thấy nút cuối màn thì cho cao hơn.
void _khoDienThoai(WidgetTester t, {double cao = 2400}) {
  t.view.physicalSize = Size(1080, cao);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

Future<void> _doiMayChu(WidgetTester t, [int lan = 4]) async {
  for (var i = 0; i < lan; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late _MayChuGia may;
  late ApiClient api;

  setUp(() {
    Analytics.instance.datLaiChoTest();
    SharedPreferences.setMockInitialValues({});
    may = _MayChuGia();
    api = may.client();
    ApiClient.datDungChungChoTest(api);
  });
  tearDown(() => api.dispose());

  group('Màn Premium', () {
    testWidgets('bat=false: chỉ có nút "Tôi quan tâm", không có nút thanh toán', (t) async {
      _khoDienThoai(t, cao: 5000);
      may.bat = false;
      await t.pumpWidget(const MaterialApp(home: PremiumScreen()));
      await _doiMayChu(t);

      expect(find.text('Tôi quan tâm'), findsOneWidget);
      expect(find.text('Thanh toán bằng chuyển khoản'), findsNothing);
      // Đúng BỐN quyền lợi đã chốt; các thứ chưa chốt không được nhắc.
      for (final loi in _bonQuyenLoi) {
        expect(find.text(loi), findsOneWidget, reason: loi);
      }
      expect(find.textContaining('phim'), findsNothing);
      expect(find.textContaining('Bảo tàng'), findsNothing);
      expect(find.textContaining('AR'), findsNothing);

      await t.tap(find.text('Tôi quan tâm'));
      await t.pump();
      expect(find.text('Đã ghi nhận. Cảm ơn bạn.'), findsOneWidget);
    });

    testWidgets('mất mạng khi hỏi gói: giữ hành vi cũ, không vỡ màn', (t) async {
      _khoDienThoai(t, cao: 5000);
      may.loiMang = true;
      await t.pumpWidget(const MaterialApp(home: PremiumScreen()));
      await _doiMayChu(t);

      expect(find.text('Tôi quan tâm'), findsOneWidget);
      expect(find.text('Thanh toán bằng chuyển khoản'), findsNothing);
    });

    testWidgets('bat=true: có nút thanh toán, giá 39.000đ và bảng so sánh (khổ 360)', (t) async {
      _khoDienThoai(t, cao: 5000);
      await t.pumpWidget(const MaterialApp(home: PremiumScreen()));
      await _doiMayChu(t);

      expect(find.text('Thanh toán bằng chuyển khoản'), findsOneWidget);
      expect(find.text('39.000'), findsOneWidget);
      expect(find.text('đ / 30 ngày'), findsOneWidget);
      // Bảng so sánh Miễn phí / Premium cho cả bốn quyền lợi.
      expect(find.text('Miễn phí'), findsOneWidget);
      expect(find.text('10 câu mỗi ngày'), findsOneWidget);
      expect(find.text('Không giới hạn'), findsOneWidget);
      expect(find.text('5 câu gần nhất'), findsOneWidget);
      expect(find.text('Bài đầu mỗi lộ trình'), findsOneWidget);
      for (final loi in _bonQuyenLoi) {
        expect(find.text(loi), findsOneWidget, reason: loi);
      }
      expect(find.text('Tôi quan tâm'), findsNothing);
      // Chỉ quản trị mới thấy gói thử.
      expect(find.textContaining('quản trị'), findsNothing);
    });

    testWidgets('quản trị (API trả gói thu): thêm nút thử 2.000đ', (t) async {
      _khoDienThoai(t, cao: 5000);
      may.coGoiThu = true;
      await t.pumpWidget(const MaterialApp(home: PremiumScreen()));
      await _doiMayChu(t);

      expect(find.text('Thử thanh toán 2.000đ (quản trị)'), findsOneWidget);
    });

    testWidgets('đã là Premium: hiện ngày hết hạn và nút gia hạn', (t) async {
      _khoDienThoai(t, cao: 5000);
      may.laPremium = true;
      api.setToken('tok');
      await t.pumpWidget(const MaterialApp(home: PremiumScreen()));
      await _doiMayChu(t);

      expect(find.textContaining('Premium đến ngày'), findsOneWidget);
      expect(find.text('Gia hạn thêm 30 ngày'), findsOneWidget);
      expect(find.text('Thanh toán bằng chuyển khoản'), findsNothing);
    });
  });

  group('Màn chuyển khoản', () {
    Widget man() => const MaterialApp(
          home: ThanhToanScreen(
            goi: GoiPremium(ma: 'thang', ten: 'Premium', soTien: 39000, soNgay: 30),
          ),
        );

    testWidgets('hiện mã đơn, số tiền, QR và lời nhắc giữ nguyên nội dung', (t) async {
      _khoDienThoai(t);
      await t.pumpWidget(man());
      await _doiMayChu(t);

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('HJ000001'), findsOneWidget); // nội dung = mã đơn
      expect(find.text('39.000đ'), findsOneWidget);
      expect(find.text('0123456789'), findsOneWidget);
      expect(find.text('MB Bank'), findsOneWidget);
      expect(find.text('NGUYEN VAN A'), findsOneWidget);
      expect(find.textContaining('Mã hết hạn sau'), findsOneWidget);
      // Màn dài hơn khổ 360x800 → cuộn xuống mới thấy lời nhắc cuối.
      await t.scrollUntilVisible(
          find.textContaining('Giữ nguyên nội dung chuyển khoản'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Giữ nguyên nội dung chuyển khoản'), findsOneWidget);

      await t.pumpWidget(const SizedBox()); // huỷ Timer
    });

    testWidgets('hỏi lại ra da_tra thì hiện thành công kèm ngày hết hạn', (t) async {
      _khoDienThoai(t);
      await t.pumpWidget(man());
      await _doiMayChu(t);

      // Chưa về: sau 4 giây hỏi một lần, vẫn ở màn chờ.
      await t.pump(const Duration(seconds: 4));
      await _doiMayChu(t);
      expect(may.soLanHoi, 1);
      expect(find.byType(QrImageView), findsOneWidget);

      may.trangThai = 'da_tra';
      await t.pump(const Duration(seconds: 4));
      await _doiMayChu(t);

      expect(find.textContaining('Đã kích hoạt Premium đến'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      // Xong rồi thì không hỏi nữa.
      final truoc = may.soLanHoi;
      await t.pump(const Duration(seconds: 12));
      expect(may.soLanHoi, truoc);

      await t.pumpWidget(const SizedBox());
    });

    testWidgets('het_han thì báo hết hạn và có nút "Tạo mã mới" tạo đơn khác', (t) async {
      _khoDienThoai(t);
      await t.pumpWidget(man());
      await _doiMayChu(t);

      may.trangThai = 'het_han';
      await t.pump(const Duration(seconds: 4));
      await _doiMayChu(t);

      expect(find.text('Mã thanh toán đã hết hạn'), findsOneWidget);
      expect(find.text('Tạo mã mới'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      may.trangThai = 'cho';
      await t.tap(find.text('Tạo mã mới'));
      await _doiMayChu(t);
      expect(may.soDonDaTao, 2);
      expect(find.text('HJ000002'), findsOneWidget);

      await t.pumpWidget(const SizedBox());
    });

    testWidgets('rời màn thì Timer bị huỷ, không hỏi nữa', (t) async {
      _khoDienThoai(t);
      await t.pumpWidget(man());
      await _doiMayChu(t);
      await t.pumpWidget(const SizedBox());
      final truoc = may.soLanHoi;
      await t.pump(const Duration(seconds: 20));
      expect(may.soLanHoi, truoc);
    });

    testWidgets('không tạo được đơn: báo lỗi rõ, có nút thử lại, không giả thành công', (t) async {
      final hong = ApiClient(
        baseUrl: 'http://test',
        httpClient: MockClient((req) async => _ok({'detail': 'x'}, 503)),
      );
      ApiClient.datDungChungChoTest(hong);
      await t.pumpWidget(man());
      await _doiMayChu(t);

      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('Đã kích hoạt'), findsNothing);
      hong.dispose();
    });
  });

  group('Hết lượt chat (402)', () {
    test('streamChat ném ApiException giữ nguyên detail của 402', () async {
      Object? loi;
      try {
        await api.streamChat('quang-trung', 'xin chào').toList();
      } catch (e) {
        loi = e;
      }
      expect(loi, isA<ApiException>());
      final e = loi as ApiException;
      expect(e.statusCode, 402);
      expect(e.ma, 'het_luot_ngay');
      expect(e.chiTiet?['gioi_han'], 10);
      expect(e.message, 'Bạn đã hết lượt hôm nay.');
      expect(soCauKhiHetLuot(e), 10);
    });

    test('lỗi khác không bị nhận nhầm là hết lượt', () {
      expect(soCauKhiHetLuot(const ApiException(statusCode: 429, message: 'x')), isNull);
      expect(
        soCauKhiHetLuot(const ApiException(
            statusCode: 402, message: 'x', chiTiet: {'ma': 'khac'})),
        isNull,
      );
      expect(soCauKhiHetLuot(StateError('x')), isNull);
    });

    testWidgets('thẻ hiện "hết N câu miễn phí", nút Xem Premium và Để mai', (t) async {
      var xem = 0;
      var deMai = 0;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TheHetLuotNgay(
            soCau: 10,
            onXemPremium: () => xem++,
            onDeMai: () => deMai++,
          ),
        ),
      ));

      expect(find.text('Hôm nay bạn đã hỏi hết 10 câu miễn phí'), findsOneWidget);
      // Thẻ cũng liệt kê đúng bốn quyền lợi, cùng danh sách với màn Premium.
      for (final loi in _bonQuyenLoi) {
        expect(find.text(loi), findsOneWidget, reason: loi);
      }
      await t.tap(find.text('Xem Premium'));
      await t.tap(find.text('Để mai'));
      expect(xem, 1);
      expect(deMai, 1);
    });

    testWidgets('bottom sheet: "Xem Premium" mở màn Premium', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => hienHetLuotNgay(ctx, soCau: 5),
              child: const Text('mo'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('mo'));
      await _doiMayChu(t, 12); // sheet trượt lên
      expect(find.text('Hôm nay bạn đã hỏi hết 5 câu miễn phí'), findsOneWidget);

      await t.tap(find.text('Xem Premium'));
      await _doiMayChu(t, 12);
      expect(find.text('HISTORIAI PREMIUM'), findsOneWidget);
    });
  });

  group('Tình trạng Premium', () {
    test('docThoiDiem: chuỗi không có múi giờ được hiểu là UTC', () {
      final a = docThoiDiem('2026-12-01T00:00:00')!;
      final b = docThoiDiem('2026-12-01T00:00:00Z')!;
      expect(a, b);
    });

    test('còn lại làm tròn lên và nhắc gia hạn trong 3 ngày cuối', () {
      final bayGio = DateTime.utc(2026, 12, 1, 7);
      TinhTrangPremium con(Duration d) => TinhTrangPremium(
          la: true, den: bayGio.add(d).toLocal());

      expect(con(const Duration(hours: 5)).ngayConLai(bayGio), 1);
      expect(con(const Duration(days: 3)).ngayConLai(bayGio), 3);
      expect(con(const Duration(days: 3)).canNhacGiaHan(bayGio), isTrue);
      expect(con(const Duration(days: 4)).canNhacGiaHan(bayGio), isFalse);
      expect(con(const Duration(days: -1)).canNhacGiaHan(bayGio), isFalse);
      expect(TinhTrangPremium.khong.canNhacGiaHan(bayGio), isFalse);
    });

    test('dinhDangTien / dinhDangNgay', () {
      expect(dinhDangTien(39000), '39.000');
      expect(dinhDangTien(2000), '2.000');
      expect(dinhDangTien(1500000), '1.500.000');
      expect(dinhDangNgay(DateTime(2026, 3, 5)), '05/03/2026');
    });
  });
}
