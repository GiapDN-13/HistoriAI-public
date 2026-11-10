import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:historiai/core/analytics.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/core/widgets/app_widgets.dart';
import 'package:historiai/data/models.dart';
import 'package:historiai/features/timeline/timeline_screen.dart';

/// Khoá lại phần gộp banner bài học (nhánh feat/banner-bai-hoc-cinematic của Mẫn):
/// banner nằm trong `assets/events/` và ĐÃ IN SẴN CHỮ, nên chỗ nào dùng banner thì
/// không được vẽ thêm tiêu đề/chip đè lên, còn ảnh máy chủ vẫn giữ nguyên.

Map<String, dynamic> _suKien(String slug, String tieuDe, int nam, String trieuDai) => {
      'slug': slug,
      'title': tieuDe,
      'year': nam,
      'period': trieuDai,
      'summary': 'Tóm tắt $tieuDe',
      'features': 'timeline,quiz',
      'thumbnail_url': '/thumbnails/$slug.jpg',
      'quiz_count': 10,
    };

/// Máy chủ giả: một trận có banner (938) và một sự kiện chưa có banner.
ApiClient _mayChuGia() => ApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/events')) {
          return http.Response(
              jsonEncode([
                _suKien('bach-dang-938', 'Trận Bạch Đằng 938', 938, 'Ngô Quyền'),
                _suKien('trong-dong-dong-son', 'Văn hoá Đông Sơn', -700, 'Văn Lang'),
              ]),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('{}', 404);
      }),
    );

bool _laAnhAsset(Widget w, [String? ten]) =>
    w is Image && w.image is AssetImage && (ten == null || (w.image as AssetImage).assetName == ten);

bool _laAnhMang(Widget w) => w is Image && w.image is NetworkImage;

void main() {
  late ApiClient api;

  setUp(() {
    Analytics.instance.datLaiChoTest();
    SharedPreferences.setMockInitialValues({});
    api = _mayChuGia();
    ApiClient.datDungChungChoTest(api);
  });
  tearDown(() => api.dispose());

  group('CoverImage — chỉ "assets/..." mới là ảnh trong app', () {
    Future<void> ve(WidgetTester t, String url) => t.pumpWidget(MaterialApp(
          home: Scaffold(body: CoverImage(url: url, width: 240, height: 100)),
        ));

    testWidgets('assets/events/... dùng Image.asset', (t) async {
      await ve(t, 'assets/events/bach_dang_938.jpg');
      expect(find.byWidgetPredicate((w) => _laAnhAsset(w, 'assets/events/bach_dang_938.jpg')),
          findsOneWidget);
      expect(find.byWidgetPredicate(_laAnhMang), findsNothing);
    });

    testWidgets('đường dẫn tương đối của máy chủ (/thumbnails/...) đi Image.network', (t) async {
      await ve(t, '/thumbnails/x.jpg');
      expect(find.byWidgetPredicate(_laAnhMang), findsOneWidget);
      expect(find.byWidgetPredicate(_laAnhAsset), findsNothing);
    });
  });

  test('fromJson giữ thumbnailUrl máy chủ trả, banner nằm riêng ở bannerAsset', () {
    final e = HistoricalEvent.fromJson(_suKien('bach-dang-938', 'Trận Bạch Đằng 938', 938, 'Ngô Quyền'));
    expect(e.thumbnailUrl, '/thumbnails/bach-dang-938.jpg');
    expect(e.bannerAsset, 'assets/events/bach_dang_938.jpg');
    expect(e.hasIntegratedBanner, isTrue);

    final khongBanner = HistoricalEvent.fromJson(_suKien('trong-dong-dong-son', 'Văn hoá Đông Sơn', -700, 'Văn Lang'));
    expect(khongBanner.thumbnailUrl, '/thumbnails/trong-dong-dong-son.jpg');
    expect(khongBanner.bannerAsset, isNull);
    expect(khongBanner.hasIntegratedBanner, isFalse);
  });

  test('mọi banner có tệp thật và nhẹ (≤ 200 KB — web tải ở trang chủ, dòng thời gian)', () {
    for (final duongDan in HistoricalEvent.eventBanners.values) {
      final tep = File(duongDan);
      expect(tep.existsSync(), isTrue, reason: '$duongDan không có trong mobile/');
      expect(tep.lengthSync(), lessThanOrEqualTo(200 * 1024), reason: '$duongDan quá nặng');
    }
  });

  testWidgets('dòng thời gian: thẻ có banner không vẽ lại tiêu đề, năm, triều đại', (t) async {
    // Rộng hơn điện thoại một chút: phông chữ test vẽ mỗi chữ thành ô vuông, tiêu đề
    // "DÒNG THỜI GIAN" trên thanh trên tràn ở 412 px dù máy thật thì không.
    t.view.physicalSize = const Size(480, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(const MaterialApp(home: TimelineScreen(isTabRoot: false)));
    await t.pump();
    await t.pump();

    // Trận có banner: chữ đã in trong ảnh, không vẽ đè lần nữa…
    expect(find.text('Trận Bạch Đằng 938'), findsNothing);
    expect(find.text('Năm 938'), findsNothing);
    expect(find.text('Ngô Quyền'), findsNothing);
    expect(find.byWidgetPredicate((w) => _laAnhAsset(w, 'assets/events/bach_dang_938.jpg')),
        findsOneWidget);
    // …nhưng trình đọc màn hình vẫn đọc được tên trận, ngay đầu nhãn của thẻ.
    expect(find.bySemanticsLabel(RegExp('^Trận Bạch Đằng 938')), findsOneWidget);

    // Sự kiện chưa có banner: vẫn ảnh máy chủ + tiêu đề, năm, triều đại như cũ.
    expect(find.text('Văn hoá Đông Sơn'), findsOneWidget);
    expect(find.text('Năm 700 TCN'), findsOneWidget);
    expect(find.text('Văn Lang'), findsOneWidget);
    expect(find.byWidgetPredicate(_laAnhMang), findsOneWidget);

    await t.pumpWidget(const SizedBox());
  });
}
