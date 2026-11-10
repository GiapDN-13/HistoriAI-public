import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/features/lop_hoc/lop_hoc_api.dart';
import 'package:historiai/features/lop_hoc/mo_rong/cau_rieng_screen.dart';
import 'package:historiai/features/lop_hoc/mo_rong/giu_tai_khoan.dart';
import 'package:historiai/features/lop_hoc/mo_rong/lop_co_dinh_screen.dart';
import 'package:historiai/features/lop_hoc/mo_rong/thong_ke_lop_screen.dart';

/// Lớp học giai đoạn 3: câu tự soạn, lớp cố định, thống kê nhiều buổi, giữ tài khoản nhanh.
void main() {
  http.Response j(Object o, [int ma = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(o)), ma,
          headers: {'content-type': 'application/json'});

  LopHocApi apiGia(Future<http.Response> Function(http.Request) xuLy) =>
      LopHocApi(
          ApiClient(baseUrl: 'http://kiem-thu', httpClient: MockClient(xuLy))
            ..setToken('ma'));

  test('nhận ra tài khoản nhanh theo miền email tổng hợp', () {
    expect(laTaiKhoanNhanh('hs-a1b2c3@nhanh.historiai.org'), isTrue);
    expect(laTaiKhoanNhanh('HS-A1@NHANH.HISTORIAI.ORG'), isTrue);
    expect(laTaiKhoanNhanh('an@gmail.com'), isFalse);
    expect(laTaiKhoanNhanh(null), isFalse);
  });

  testWidgets('thống kê lớp: điểm từng buổi, tiến bộ từng em, câu yếu',
      (t) async {
    final api = apiGia((req) async => j({
          'lop': {'id': 1, 'ten': '8A2', 'si_so': 2, 'so_buoi': 2},
          'buoi': [
            {
              'ma': '111111',
              'tieu_de': 'Bạch Đằng',
              'ngay': '2026-09-20T02:00:00+00:00',
              'dang_mo': false,
              'so_bai': 3,
              'so_tinh': 2,
              'diem_tb': 6.25
            },
            {
              'ma': '222222',
              'tieu_de': 'Lam Sơn',
              'ngay': '2026-09-27T02:00:00+00:00',
              'dang_mo': true,
              'so_bai': 1,
              'so_tinh': 1,
              'diem_tb': 10
            },
          ],
          'hoc_sinh': [
            {
              'ten': 'An',
              'diem': [2.5, 10.0],
              'so_buoi': 2,
              'diem_tb': 6.25,
              'thay_doi': 7.5
            },
            {
              'ten': 'Cường',
              'diem': [null, null],
              'so_buoi': 0,
              'diem_tb': null,
              'thay_doi': null
            },
          ],
          'cau_yeu': [
            {
              'id': -3,
              'question': 'Câu cô tự soạn?',
              'rieng': true,
              'su_kien': null,
              'so_tra_loi': 4,
              'ti_le_dung': 25
            },
          ],
          'su_kien_yeu': [
            {
              'su_kien': 'Khởi nghĩa Lam Sơn',
              'so_tra_loi': 6,
              'ti_le_dung': 50
            },
          ],
        }));
    await t.pumpWidget(MaterialApp(home: ThongKeLopScreen(api: api, lopId: 1)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(find.text('THỐNG KÊ 8A2'), findsOneWidget);
    expect(find.text('20/09 · Bạch Đằng'), findsOneWidget);
    expect(find.text('6.25'), findsOneWidget,
        reason: 'điểm TB buổi giữ như sổ điểm, không làm tròn thêm');
    expect(find.text('TB 6.25 · 2/2 buổi'), findsOneWidget);
    expect(find.text('▲ 7.5'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Chưa có bài được tính'), 150, scrollable: find.byType(Scrollable).first);
    expect(find.text('Chưa có bài được tính'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Câu cô tự soạn?'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('câu tự soạn'), findsOneWidget);
    expect(find.text('Khởi nghĩa Lam Sơn'), findsOneWidget);
  });

  testWidgets('soạn câu riêng gửi đủ 4 phương án + đáp án đúng đã chọn',
      (t) async {
    Map<String, dynamic>? daGui;
    final api = apiGia((req) async {
      if (req.url.path.endsWith('/lop/kho-cau')) {
        return j([
          {
            'event_slug': 'bach-dang-938',
            'event_title': 'Bạch Đằng 938',
            'cau': []
          },
        ]);
      }
      if (req.method == 'POST' && req.url.path.endsWith('/lop/cau-rieng')) {
        daGui = (jsonDecode(req.body) as Map).cast<String, dynamic>();
        return j({...daGui!, 'id': -1, 'cau_rieng_id': 1}, 201);
      }
      return j({}, 404);
    });
    await t.pumpWidget(MaterialApp(home: SoanCauScreen(api: api)));
    await t.pump();

    final o = find.byType(TextFormField);
    await t.enterText(o.at(0), 'Ai lãnh đạo khởi nghĩa Lam Sơn?');
    await t.enterText(o.at(1), 'Trần Hưng Đạo');
    await t.enterText(o.at(2), 'Lê Lợi');
    await t.enterText(o.at(3), 'Quang Trung');
    await t.enterText(o.at(4), 'Ngô Quyền');
    await t.tap(find.widgetWithText(ChoiceChip, 'B'));
    await t.pump();
    await t.tap(find.text('Lưu câu'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(daGui, isNotNull);
    expect(daGui!['correct_option'], 'B');
    expect(daGui!['option_b'], 'Lê Lợi');
    expect(daGui!['event_slug'], isNull);
  });

  testWidgets('mở phòng: chọn lớp trong hộp, bấm ra ngoài là huỷ', (t) async {
    final api = apiGia((req) async => j([
          {'id': 7, 'ten': '8A2', 'si_so': 30, 'so_buoi': 1},
        ]));
    ChonLop? kq;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => kq = await chonLopChoPhong(ctx, api),
          child: const Text('mở'),
        ),
      ),
    ));
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();
    await t.tap(find.text('8A2 · 30 em'));
    await t.pumpAndSettle();
    expect(kq?.huy, isFalse);
    expect(kq?.lopId, 7);

    await t.tap(find.text('mở'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(5, 5)); // chạm ra ngoài hộp
    await t.pumpAndSettle();
    expect(kq?.huy, isTrue);
  });

  testWidgets('chưa có lớp nào thì không hỏi, mở phòng lẻ', (t) async {
    final api = apiGia((req) async => j([]));
    ChonLop? kq;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => kq = await chonLopChoPhong(ctx, api),
          child: const Text('mở'),
        ),
      ),
    ));
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsNothing);
    expect(kq?.huy, isFalse);
    expect(kq?.lopId, isNull);
  });
}
