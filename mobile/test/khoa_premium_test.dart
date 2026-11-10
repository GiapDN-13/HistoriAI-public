import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:historiai/core/analytics.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/data/lo_trinh_hoc.dart';
import 'package:historiai/data/models.dart';
import 'package:historiai/features/profile/lich_su_hoc_screen.dart';
import 'package:historiai/features/timeline/event_detail_screen.dart';

/// Ba quyền lợi Premium thêm ngày 30/10: bài học lộ trình, ôn câu sai (bản tin phụ
/// huynh khoá ở máy chủ, test bên backend). Máy chủ mới là nơi cắt dữ liệu — ở đây
/// chỉ kiểm app hiện đúng cái máy chủ gửi và có lối sang Premium.

const _json = {'content-type': 'application/json; charset=utf-8'};

http.Response _ok(Object body) =>
    http.Response(jsonEncode(body), 200, headers: _json);

Map<String, dynamic> _bai(String slug, String tenNgan, {bool khoa = false}) => {
      'slug': slug,
      'ten': 'Trận $tenNgan',
      'ten_ngan': tenNgan,
      'muc_tieu': 'Mục tiêu của $tenNgan.',
      // Bài khoá: máy chủ gửi rỗng các mục dài, chỉ còn mục tiêu + câu chốt.
      'boi_canh': khoa ? [] : ['Bối cảnh của $tenNgan.'],
      'kien_thuc': khoa
          ? {'tieu_de': '', 'y': []}
          : {'tieu_de': 'Kiến thức cần nhớ', 'y': ['Kiến thức của $tenNgan.']},
      'dien_bien': khoa ? [] : ['Diễn biến của $tenNgan.'],
      'ket_qua': khoa ? [] : ['Kết quả của $tenNgan.'],
      'cau_chot': 'Câu chốt của $tenNgan.',
      'khoa': khoa,
    };

List<Map<String, dynamic>> _loTrinh({required bool khoa}) => [
      {
        'ma': 'bach-dang-938__bach-dang-1288',
        'ten': 'Bạch Đằng 938 – Chống Tống 981 – Bạch Đằng 1288',
        'su_kien': [
          _bai('bach-dang-938', 'Bạch Đằng 938'),
          _bai('khang-chien-tong-981', 'Chống Tống 981', khoa: khoa),
          _bai('bach-dang-1288', 'Bạch Đằng 1288', khoa: khoa),
        ],
      },
    ];

Map<String, dynamic> _cau(int id) => {
      'id': id,
      'question': 'Câu sai số $id?',
      'option_a': 'A',
      'option_b': 'B',
      'option_c': 'C',
      'option_d': 'D',
      'difficulty': 1,
    };

const _khungChu = 'Bài học đầy đủ (bối cảnh, diễn biến, kết quả) dành cho Premium';

void main() {
  ApiClient? api;
  void tiem(ApiClient c) {
    api = c;
    ApiClient.datDungChungChoTest(c);
  }

  setUp(() {
    Analytics.instance.datLaiChoTest();
    SharedPreferences.setMockInitialValues({});
    KhoLoTrinh.datLaiChoTest();
  });
  tearDown(() {
    api?.dispose();
    api = null;
    KhoLoTrinh.datLaiChoTest();
  });

  group('Bài học lộ trình bị khoá', () {
    var khoa = true;
    var soLanGoi = 0;

    ApiClient mayChu() => ApiClient(
          baseUrl: 'http://test',
          httpClient: MockClient((req) async {
            if (req.url.path.endsWith('/lo-trinh')) {
              soLanGoi++;
              return _ok(_loTrinh(khoa: khoa));
            }
            return http.Response('{}', 404); // gồm /thanh-toan/goi → chưa mở bán
          }),
        );

    setUp(() {
      khoa = true;
      soLanGoi = 0;
    });

    Future<void> mo(WidgetTester t, String slug) async {
      await t.pumpWidget(MaterialApp(
        home: EventDetailScreen(
          event: HistoricalEvent(
              slug: slug, title: 'Trận thử', year: 981, features: 'quiz,timeline'),
        ),
      ));
      await t.pump();
      await t.pump();
    }

    testWidgets('khung khoá: có Mục tiêu, có nút Xem Premium, không có bài đầy đủ',
        (t) async {
      tiem(mayChu());
      await mo(t, 'khang-chien-tong-981');

      expect(find.text('Mục tiêu của Chống Tống 981.', skipOffstage: false), findsOneWidget);
      expect(find.text(_khungChu, skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('lo-trinh-khoa'), skipOffstage: false), findsOneWidget);
      expect(find.text('Xem Premium', skipOffstage: false), findsOneWidget);
      // Nút mở rộng biến mất, các mục dài không có mặt.
      expect(find.byKey(const Key('lo-trinh-mo-rong'), skipOffstage: false), findsNothing);
      expect(find.text('Xem bài học đầy đủ', skipOffstage: false), findsNothing);
      expect(find.text('Diễn biến cần nhớ', skipOffstage: false), findsNothing);
      // "Ghi nhớ nhanh" (câu chốt) vẫn miễn phí.
      expect(find.text('Câu chốt của Chống Tống 981.', skipOffstage: false), findsOneWidget);
    });

    testWidgets('bài đầu của lộ trình không bị khoá', (t) async {
      tiem(mayChu());
      await mo(t, 'bach-dang-938');

      expect(find.byKey(const Key('lo-trinh-khoa'), skipOffstage: false), findsNothing);
      expect(find.byKey(const Key('lo-trinh-mo-rong'), skipOffstage: false), findsOneWidget);
    });

    testWidgets('bấm Xem Premium mở màn Premium; quay lại thì nạp lại và mở khoá',
        (t) async {
      tiem(mayChu());
      await mo(t, 'khang-chien-tong-981');
      expect(soLanGoi, 1);

      await t.ensureVisible(find.text('Xem Premium'));
      await t.pump();
      await t.tap(find.text('Xem Premium'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('HISTORIAI PREMIUM'), findsOneWidget);

      // Trong lúc ở màn Premium, người học đã mua xong.
      khoa = false;
      await t.pageBack();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      await t.pump();

      expect(soLanGoi, 2, reason: 'quay lại từ màn Premium phải tải lại /lo-trinh');
      expect(find.byKey(const Key('lo-trinh-khoa'), skipOffstage: false), findsNothing);
      expect(find.byKey(const Key('lo-trinh-mo-rong'), skipOffstage: false), findsOneWidget);
    });

    test('đổi tài khoản thì kho nạp lại; cùng tài khoản thì dùng bản nhớ', () async {
      tiem(mayChu());
      api!.setToken('hoc-sinh-a');
      var ds = await KhoLoTrinh.tai();
      expect(ds.single.suKien[1].khoa, isTrue);
      await KhoLoTrinh.tai();
      expect(soLanGoi, 1, reason: 'cùng tài khoản: một lượt tải');

      khoa = false;
      api!.setToken('hoc-sinh-b'); // đăng nhập tài khoản Premium
      ds = await KhoLoTrinh.tai();
      expect(soLanGoi, 2);
      expect(ds.single.suKien[1].khoa, isFalse);
      expect(ds.single.suKien[1].dienBien, isNotEmpty);

      api!.setToken(''); // đăng xuất
      khoa = true;
      ds = await KhoLoTrinh.tai();
      expect(soLanGoi, 3);
      expect(ds.single.suKien[1].khoa, isTrue);
    });

    test('lamMoi() (vừa mua Premium) bỏ bản nhớ dù token không đổi', () async {
      tiem(mayChu());
      api!.setToken('hoc-sinh-a');
      await KhoLoTrinh.tai();
      khoa = false;
      KhoLoTrinh.lamMoi();
      final ds = await KhoLoTrinh.tai();
      expect(soLanGoi, 2);
      expect(ds.single.suKien[1].khoa, isFalse);
    });

    testWidgets('KhungBaiHocKhoa đứng riêng: chữ đúng và nút gọi onXemPremium', (t) async {
      var xem = 0;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: KhungBaiHocKhoa(onXemPremium: () => xem++)),
      ));
      expect(find.text(_khungChu), findsOneWidget);
      await t.tap(find.text('Xem Premium'));
      expect(xem, 1);
    });
  });

  group('Ôn câu sai', () {
    Object cauSai = const [];

    ApiClient mayChu() => ApiClient(
          baseUrl: 'http://test',
          httpClient: MockClient((req) async {
            final p = req.url.path;
            if (p.endsWith('/me/thong-ke')) {
              return _ok({
                'tong_cau': 20,
                'ti_le_dung': 60,
                'so_su_kien_da_hoc': 2,
                'hang': 3,
                'tong_nguoi': 10,
              });
            }
            if (p.endsWith('/me/lich-su-quiz')) return _ok([]);
            if (p.endsWith('/me/cau-sai')) {
              // App phải xin kèm tổng để biết còn bao nhiêu câu bị giấu.
              expect(req.url.queryParameters['kem_tong'], '1');
              return _ok(cauSai);
            }
            return http.Response('{}', 404);
          }),
        );

    Future<void> mo(WidgetTester t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(const MaterialApp(home: LichSuHocScreen()));
      await t.pump();
      await t.pump();
    }

    testWidgets('bản thường: ôn 5 câu và dòng "Còn N câu nữa — mở bằng Premium"', (t) async {
      cauSai = {
        'cau_hoi': [for (var i = 1; i <= 5; i++) _cau(i)],
        'tong': 8,
        'da_cat': 3,
      };
      tiem(mayChu());
      await mo(t);

      expect(find.text('Ôn 5 câu'), findsOneWidget);
      expect(find.text('Còn 3 câu nữa — mở bằng Premium'), findsOneWidget);
      expect(find.text('Xem Premium'), findsOneWidget);
    });

    testWidgets('bấm Xem Premium mở màn Premium', (t) async {
      cauSai = {
        'cau_hoi': [for (var i = 1; i <= 5; i++) _cau(i)],
        'tong': 7,
        'da_cat': 2,
      };
      tiem(mayChu());
      await mo(t);

      await t.tap(find.text('Xem Premium'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('HISTORIAI PREMIUM'), findsOneWidget);
    });

    testWidgets('Premium (da_cat = 0): ôn hết, không có dòng khoá', (t) async {
      cauSai = {
        'cau_hoi': [for (var i = 1; i <= 8; i++) _cau(i)],
        'tong': 8,
        'da_cat': 0,
      };
      tiem(mayChu());
      await mo(t);

      expect(find.text('Ôn 8 câu'), findsOneWidget);
      expect(find.byKey(const Key('con-cau-sai')), findsNothing);
      expect(find.textContaining('mở bằng Premium'), findsNothing);
    });

    testWidgets('máy chủ cũ trả mảng trơn: vẫn chạy, không có dòng khoá', (t) async {
      cauSai = [for (var i = 1; i <= 3; i++) _cau(i)];
      tiem(mayChu());
      await mo(t);

      expect(find.text('Ôn 3 câu'), findsOneWidget);
      expect(find.byKey(const Key('con-cau-sai')), findsNothing);
    });

    testWidgets('DongConCauSai đứng riêng: nút gọi onXemPremium', (t) async {
      var xem = 0;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: DongConCauSai(soCon: 4, onXemPremium: () => xem++)),
      ));
      expect(find.text('Còn 4 câu nữa — mở bằng Premium'), findsOneWidget);
      await t.tap(find.text('Xem Premium'));
      expect(xem, 1);
    });
  });
}
