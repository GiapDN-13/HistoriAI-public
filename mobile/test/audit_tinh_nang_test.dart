import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/core/bai_lam_cho.dart';
import 'package:historiai/core/widgets/daily_history_card.dart';
import 'package:historiai/data/models.dart';
import 'package:historiai/features/chat/lich_su_chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Audit tính năng 27/09: lịch sử chat trên máy, bài quiz chờ gửi, mốc sử hôm nay.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ApiClient().dispose());

  group('Lịch sử chat lưu trên máy', () {
    test('ghi rồi đọc lại đúng thứ tự, đúng vai', () async {
      await LichSuChat.ghi('tran-hung-dao', const [
        LuotDaLuu(laNguoiDung: true, noiDung: 'Trận Bạch Đằng năm nào?'),
        LuotDaLuu(laNguoiDung: false, noiDung: 'Năm 1288.'),
      ]);
      final ds = await LichSuChat.doc('tran-hung-dao');
      expect(ds.map((l) => l.choMayChu()['role']), ['user', 'assistant']);
      expect(ds.last.noiDung, 'Năm 1288.');
      expect(await LichSuChat.doc('quang-trung'), isEmpty, reason: 'mỗi vĩ nhân một cuộc riêng');
    });

    test('chỉ giữ ${LichSuChat.toiDa} lượt cuối; xoá là mất hẳn', () async {
      await LichSuChat.ghi('x', [
        for (var i = 0; i < 100; i++) LuotDaLuu(laNguoiDung: i.isEven, noiDung: 'c$i'),
      ]);
      final ds = await LichSuChat.doc('x');
      expect(ds.length, LichSuChat.toiDa);
      expect(ds.last.noiDung, 'c99');
      await LichSuChat.xoa('x');
      expect(await LichSuChat.doc('x'), isEmpty);
    });

    test('xoá hết: mọi vĩ nhân, không đụng dữ liệu khác', () async {
      SharedPreferences.setMockInitialValues({'tu_doc': true});
      const mot = [LuotDaLuu(laNguoiDung: true, noiDung: 'hỏi')];
      await LichSuChat.ghi('tran-hung-dao', mot);
      await LichSuChat.ghi('quang-trung', mot);
      expect(await LichSuChat.xoaHet(), 2);
      expect(await LichSuChat.doc('tran-hung-dao'), isEmpty);
      expect(await LichSuChat.doc('quang-trung'), isEmpty);
      expect((await SharedPreferences.getInstance()).getBool('tu_doc'), isTrue);
      expect(await LichSuChat.xoaHet(), 0);
    });
  });

  group('Bài quiz chờ gửi (khách / mất mạng)', () {
    test('khách: giữ lại, đăng nhập xong gửi hết rồi xoá', () async {
      await BaiLamCho.them([{'question_id': 1, 'selected_option': 'A'}]);
      await BaiLamCho.them([{'question_id': 2, 'selected_option': ''}]);
      expect(await BaiLamCho.soLuot(), 2);

      final gui = <Object?>[];
      final api = ApiClient(
        baseUrl: 'http://kiem-thu',
        httpClient: MockClient((req) async {
          gui.add(jsonDecode(req.body));
          return http.Response('[]', 200);
        }),
      );
      expect(await BaiLamCho.guiHet(api), 0, reason: 'chưa đăng nhập thì chưa gửi');
      api.setToken('ma');
      expect(await BaiLamCho.guiHet(api), 2);
      expect(gui.length, 2);
      expect(await BaiLamCho.soLuot(), 0);
    });

    test('lỗi máy chủ thì giữ lại lần sau; bị từ chối hẳn (422) thì bỏ', () async {
      await BaiLamCho.them([{'question_id': 1, 'selected_option': 'A'}]);
      await BaiLamCho.them([{'question_id': 999, 'selected_option': 'Z'}]);
      var lan = 0;
      final api = ApiClient(
        baseUrl: 'http://kiem-thu',
        httpClient: MockClient((_) async =>
            http.Response('{}', lan++ == 0 ? 503 : 422)),
      )..setToken('ma');
      expect(await BaiLamCho.guiHet(api), 0);
      expect(await BaiLamCho.soLuot(), 1, reason: 'lượt 503 giữ lại, lượt 422 bỏ');
    });
  });

  group('Mốc sử hôm nay', () {
    final ds = [
      for (var i = 0; i < 5; i++) HistoricalEvent(slug: 's$i', title: 'T$i', year: 900 + i),
    ];

    test('cùng một ngày luôn ra cùng một sự kiện, ngày sau đổi', () {
      final a = DailyHistoryCard.cuaNgay(ds, DateTime(2026, 9, 27, 7));
      final b = DailyHistoryCard.cuaNgay(ds, DateTime(2026, 9, 27, 22));
      final c = DailyHistoryCard.cuaNgay(ds, DateTime(2026, 9, 28));
      expect(a!.slug, b!.slug);
      expect(c!.slug, isNot(a.slug));
    });

    test('kho rỗng thì không có gì để hiện', () {
      expect(DailyHistoryCard.cuaNgay(const [], DateTime(2026, 9, 27)), isNull);
    });
  });
}
