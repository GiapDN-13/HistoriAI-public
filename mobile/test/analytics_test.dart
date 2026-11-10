import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/core/analytics.dart';
import 'package:historiai/core/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => Analytics.instance.datLaiChoTest());

  /// ApiClient giả: ghi lại mọi body gửi đi, trả về [ma].
  ({ApiClient api, List<Map<String, dynamic>> daGui}) gia({int ma = 200}) {
    final daGui = <Map<String, dynamic>>[];
    final api = ApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient((req) async {
        daGui.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('{"accepted":1,"rejected":0,"unknown":[]}', ma);
      }),
    );
    return (api: api, daGui: daGui);
  }

  test('Gom nhiều hành vi rồi gửi một lô, mỗi event kèm client_id và phiên', () async {
    final g = gia();
    Analytics.instance.datLaiChoTest(api: g.api, clientId: 'may-cua-an');

    Analytics.instance.log(Ev.appOpen);
    Analytics.instance.log(Ev.quizSubmit, target: 'lam-son-1428', value: 2);
    await Analytics.instance.guiNgay();

    expect(g.daGui.length, 1, reason: 'Hai hành vi phải đi chung một request');
    final events = (g.daGui.first['events'] as List).cast<Map<String, dynamic>>();
    expect(events.length, 2);
    expect(events.every((e) => e['client_id'] == 'may-cua-an'), isTrue);
    expect(events.every((e) => e['session_id'] == 'test-session'), isTrue);

    final quiz = events.firstWhere((e) => e['name'] == Ev.quizSubmit);
    expect(quiz['target'], 'lam-son-1428');
    expect(quiz['value'], 2);
  });

  test('Server lỗi thì không ném ra ngoài, event nằm lại chờ lượt sau', () async {
    final g = gia(ma: 500);
    Analytics.instance.datLaiChoTest(api: g.api, clientId: 'c2');

    Analytics.instance.log(Ev.chatOpen, target: 'tran-hung-dao');
    // Không được ném: đo lường hỏng thì người dùng vẫn phải chat bình thường.
    await Analytics.instance.guiNgay();

    expect(Analytics.instance.soDangCho, 1, reason: 'Phải giữ lại để gửi lần sau');
  });

  test('Đủ 10 hành vi thì gửi luôn, không đợi hết 2 giây', () async {
    final g = gia();
    Analytics.instance.datLaiChoTest(api: g.api, clientId: 'c3');

    for (var i = 0; i < 10; i++) {
      Analytics.instance.log(Ev.chatMessageSent, target: 'le-loi', value: i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(g.daGui.length, 1);
    expect((g.daGui.first['events'] as List).length, 10);
    expect(Analytics.instance.soDangCho, 0);
  });

  test('Tắt đo lường thì không ghi gì, kể cả khi màn hình vẫn gọi log', () async {
    final g = gia();
    Analytics.instance.datLaiChoTest();   // không truyền api = tắt hẳn

    Analytics.instance.log(Ev.appOpen);
    Analytics.instance.log(Ev.quizStart, target: 'bach-dang-1288');
    await Analytics.instance.guiNgay();

    expect(Analytics.instance.soDangCho, 0);
    expect(g.daGui, isEmpty);
  });

  test('Không ghi nội dung câu chat, chỉ ghi độ dài', () async {
    final g = gia();
    Analytics.instance.datLaiChoTest(api: g.api, clientId: 'c4');

    // Đây đúng là cách chat_screen gọi: value = số ký tự, không phải câu chữ.
    const cauHoi = 'Ngài đánh trận Bạch Đằng thế nào?';
    Analytics.instance.log(Ev.chatMessageSent, target: 'tran-hung-dao', value: cauHoi.length);
    await Analytics.instance.guiNgay();

    final body = jsonEncode(g.daGui.first);
    expect(body.contains('Bạch Đằng thế nào'), isFalse, reason: 'Lộ nội dung người dùng');
    expect(body.contains('"value":${cauHoi.length}'), isTrue);
  });
}
