import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:historiai/core/api_client.dart';
import 'package:historiai/features/profile/ban_tin_phu_huynh.dart';

/// Bản tin tuần cho phụ huynh — góp ý "chưa biết rõ từng bài trong app liên quan đến
/// phần kiến thức nào con đang học trên lớp". Sheet phải hiện đúng link máy chủ trả,
/// chép được để dán vào Zalo, và mất mạng thì nói thật là chưa tạo được.

const _url = 'https://historiai.org/api/v1/ban-tin/MTIzLjE3OTk5OTk5OTk.chu-ky-thu';

Widget _man() => const MaterialApp(
      home: Scaffold(body: Center(child: TheBanTinPhuHuynh())),
    );

void main() {
  late ApiClient api;
  late List<http.Request> daGoi;
  late int soLanHong;   // số lần đầu máy chủ giả "mất mạng"
  String? daChep;

  setUp(() {
    daGoi = [];
    soLanHong = 0;
    daChep = null;
    api = ApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient((req) async {
        daGoi.add(req);
        if (req.method == 'POST' && req.url.path == '/api/v1/me/ban-tin/link') {
          if (soLanHong > 0) {
            soLanHong--;
            throw const SocketException('mất mạng');
          }
          return http.Response(jsonEncode({'url': _url, 'het_han': '2026-11-04T12:00:00+00:00'}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('{}', 404);
      }),
    );
    ApiClient.datDungChungChoTest(api);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        daChep = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    api.dispose();
  });

  testWidgets('bấm thẻ: tạo link qua POST /me/ban-tin/link, hiện link và hạn', (t) async {
    await t.pumpWidget(_man());
    expect(find.text('Gửi bản tin tuần cho phụ huynh'), findsOneWidget);

    await t.tap(find.byType(TheBanTinPhuHuynh));
    await t.pumpAndSettle();

    expect(daGoi.where((r) => r.method == 'POST' && r.url.path.endsWith('/me/ban-tin/link')),
        hasLength(1));
    final link = t.widget<SelectableText>(find.byKey(const Key('ban-tin-link')));
    expect(link.data, _url, reason: 'hiện đúng link máy chủ trả, chọn chữ được');
    expect(find.byKey(const Key('ban-tin-chep')), findsOneWidget);
    expect(find.byKey(const Key('ban-tin-xem')), findsOneWidget);
    expect(find.textContaining('Link có hạn 14 ngày (tới 04/11/2026)'), findsOneWidget);
    expect(find.textContaining('Ai có link đều xem được'), findsOneWidget);
  });

  testWidgets('Chép link: ghi đúng link vào bộ nhớ tạm và báo dán vào Zalo', (t) async {
    await t.pumpWidget(_man());
    await t.tap(find.byType(TheBanTinPhuHuynh));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('ban-tin-chep')));
    await t.pumpAndSettle();

    expect(daChep, _url);
    expect(find.text('Đã chép — dán vào Zalo gửi bố mẹ nhé'), findsOneWidget);
    expect(find.byKey(const Key('ban-tin-link')), findsNothing, reason: 'chép xong thì đóng bảng');

    await t.pump(const Duration(seconds: 5)); // cho SnackBar tự tắt
    await t.pumpAndSettle();
  });

  testWidgets('mất mạng: báo rõ chưa tạo được, không hiện link giả; Thử lại thì được', (t) async {
    soLanHong = 1;
    await t.pumpWidget(_man());
    await t.tap(find.byType(TheBanTinPhuHuynh));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('ban-tin-loi')), findsOneWidget);
    expect(find.textContaining('Chưa tạo được link'), findsOneWidget);
    expect(find.byKey(const Key('ban-tin-link')), findsNothing);
    expect(find.byKey(const Key('ban-tin-chep')), findsNothing);

    await t.tap(find.text('Thử lại'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('ban-tin-loi')), findsNothing);
    expect(t.widget<SelectableText>(find.byKey(const Key('ban-tin-link'))).data, _url);
  });
}
