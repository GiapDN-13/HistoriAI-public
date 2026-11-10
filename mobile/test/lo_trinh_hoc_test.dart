import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:historiai/core/analytics.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/data/ghi_nho.dart';
import 'package:historiai/data/lo_trinh_hoc.dart';
import 'package:historiai/data/models.dart';
import 'package:historiai/features/timeline/event_detail_screen.dart';

/// Mục "Bài học theo lộ trình" ở màn chi tiết sự kiện — dữ liệu từ GET /lo-trinh
/// (backend/data/lo_trinh.json, nhập từ tài liệu nhóm bằng tools/nhap_lo_trinh.py).

Map<String, dynamic> _bai(String slug, String tenNgan, {String? cauChot}) => {
      'slug': slug,
      'ten': 'Trận $tenNgan',
      'ten_ngan': tenNgan,
      'muc_tieu': 'Mục tiêu của $tenNgan.',
      'boi_canh': ['Bối cảnh một của $tenNgan.', 'Bối cảnh hai của $tenNgan.'],
      'kien_thuc': {
        'tieu_de': 'Kiến thức cần nhớ',
        'y': ['Kiến thức của $tenNgan.'],
      },
      'dien_bien': ['Bước đầu của $tenNgan.', 'Bước sau của $tenNgan.'],
      'ket_qua': ['Kết quả của $tenNgan.'],
      'cau_chot': cauChot ?? 'Câu chốt API của $tenNgan.',
    };

List<Map<String, dynamic>> _loTrinh() => [
      {
        'ma': 'bach-dang-938__bach-dang-1288',
        'ten': 'Bạch Đằng 938 – Kháng chiến chống Tống 981 – Bạch Đằng 1288',
        'su_kien': [
          _bai('bach-dang-938', 'Bạch Đằng 938'),
          _bai('khang-chien-tong-981', 'Chống Tống 981'),
          _bai('bach-dang-1288', 'Bạch Đằng 1288'),
        ],
      },
    ];

/// Máy chủ giả. [hong] = mất mạng; [maLoi] = máy chủ trả lỗi (vd máy chủ cũ chưa có
/// /lo-trinh → 404); đếm số lần gọi /lo-trinh vào [soLanGoi].
ApiClient _mayChu({bool hong = false, int? maLoi, List<int>? soLanGoi}) => ApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/lo-trinh')) {
          soLanGoi?.add(1);
          if (hong) throw const SocketException('mất mạng');
          if (maLoi != null) return http.Response('{"detail":"Not Found"}', maLoi);
          return http.Response(jsonEncode(_loTrinh()), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('{}', 404);
      }),
    );

Future<void> _mo(WidgetTester t, String slug) async {
  await t.pumpWidget(MaterialApp(
    home: EventDetailScreen(
      event: HistoricalEvent(slug: slug, title: 'Trận thử', year: 981, features: 'quiz,timeline'),
    ),
  ));
  await t.pump();
  await t.pump();
}

Finder _chu(String s) => find.text(s, skipOffstage: false);

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

  test('đọc JSON thiếu trường không vỡ, bỏ ý rỗng', () {
    final lt = LoTrinhHoc.fromJson({
      'ma': 'x',
      'ten': 'X',
      'su_kien': [
        {'slug': 'bach-dang-938', 'muc_tieu': 'M', 'boi_canh': ['  ', 'Ý thật']},
        {'muc_tieu': 'không có slug — bỏ'},
      ],
    });
    expect(lt.suKien, hasLength(1));
    expect(lt.suKien.single.boiCanh, ['Ý thật']);
    expect(lt.suKien.single.kienThuc.y, isEmpty);
    expect(lt.suKien.single.cauChot, '');
  });

  testWidgets('mặc định gập: hiện lộ trình + Mục tiêu; bấm là thấy đủ bài', (t) async {
    tiem(_mayChu());
    await _mo(t, 'khang-chien-tong-981');

    expect(_chu('BÀI HỌC THEO LỘ TRÌNH'), findsOneWidget);
    expect(
        _chu('Theo lộ trình: Bạch Đằng 938 → Chống Tống 981 → Bạch Đằng 1288 (bài 2/3)'),
        findsOneWidget);
    expect(_chu('Mục tiêu'), findsOneWidget);
    expect(_chu('Mục tiêu của Chống Tống 981.'), findsOneWidget);
    expect(_chu('Bối cảnh một của Chống Tống 981.'), findsNothing, reason: 'đang gập');
    expect(_chu('Diễn biến cần nhớ'), findsNothing);

    await t.ensureVisible(find.byKey(const Key('lo-trinh-mo-rong')));
    await t.pump();
    await t.tap(find.byKey(const Key('lo-trinh-mo-rong')));
    await t.pump();

    for (final s in [
      'Bối cảnh',
      'Bối cảnh một của Chống Tống 981.',
      'Bối cảnh hai của Chống Tống 981.',
      'Kiến thức cần nhớ', // tiêu đề mục c) lấy nguyên từ tài liệu
      'Kiến thức của Chống Tống 981.',
      'Diễn biến cần nhớ',
      'Bước đầu của Chống Tống 981.',
      'Bước sau của Chống Tống 981.',
      'Kết quả',
      'Kết quả của Chống Tống 981.',
    ]) {
      expect(_chu(s), findsOneWidget, reason: s);
    }
    // Diễn biến đánh số theo thứ tự tài liệu.
    expect(_chu('1.'), findsOneWidget);
    expect(_chu('2.'), findsOneWidget);
    expect(find.byKey(const Key('lo-trinh-mo-rong')), findsNothing);

    await t.ensureVisible(find.byKey(const Key('lo-trinh-thu-gon')));
    await t.pump();
    await t.tap(find.byKey(const Key('lo-trinh-thu-gon')));
    await t.pump();
    expect(_chu('Bối cảnh một của Chống Tống 981.'), findsNothing);
  });

  testWidgets('câu chốt lấy từ API khi có, không dùng bảng ghi_nho.dart', (t) async {
    tiem(_mayChu());
    await _mo(t, 'bach-dang-938');
    expect(_chu('Câu chốt API của Bạch Đằng 938.'), findsOneWidget);
    expect(_chu(ghiNhoNhanh['bach-dang-938']!), findsNothing);
    expect(_chu('Theo lộ trình: Bạch Đằng 938 → Chống Tống 981 → Bạch Đằng 1288 (bài 1/3)'),
        findsOneWidget);
  });

  testWidgets('mất mạng: ẩn mục bài học, Ghi nhớ nhanh dùng bản dự phòng', (t) async {
    tiem(_mayChu(hong: true));
    await _mo(t, 'bach-dang-1288');
    await t.pump(const Duration(seconds: 3)); // ApiClient thử lại một lần sau 2 giây
    await t.pump();

    expect(find.byKey(const Key('bai-hoc-lo-trinh'), skipOffstage: false), findsNothing);
    expect(_chu('BÀI HỌC THEO LỘ TRÌNH'), findsNothing);
    expect(_chu(ghiNhoNhanh['bach-dang-1288']!), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing, reason: 'không báo lỗi to');
  });

  testWidgets('trận chưa thuộc lộ trình đã duyệt: không hiện mục', (t) async {
    tiem(_mayChu());
    await _mo(t, 'lam-son-1428');
    expect(find.byKey(const Key('bai-hoc-lo-trinh'), skipOffstage: false), findsNothing);
  });

  test('mở nhiều trận chỉ tải /lo-trinh một lần; tải hỏng thì lần sau thử lại', () async {
    final goi = <int>[];
    // Máy chủ cũ chưa có /lo-trinh: 404 — không được nhớ lỗi này mãi.
    tiem(_mayChu(maLoi: 404, soLanGoi: goi));
    expect(await KhoLoTrinh.timBai('bach-dang-938'), isNull);
    expect(goi, hasLength(1));
    api!.dispose();

    goi.clear();
    tiem(_mayChu(soLanGoi: goi));
    expect((await KhoLoTrinh.timBai('bach-dang-938'))?.soBai, 1);
    expect((await KhoLoTrinh.timBai('bach-dang-1288'))?.soBai, 3);
    expect((await KhoLoTrinh.timBai('khang-chien-tong-981'))?.tongSoBai, 3);
    expect(goi, hasLength(1), reason: 'ba trận, một lượt tải');
  });
}
