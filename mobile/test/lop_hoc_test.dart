import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/features/lop_hoc/lam_bai_screen.dart';
import 'package:historiai/features/lop_hoc/lop_hoc_api.dart';

/// Chế độ kiểm tra (giai đoạn 1): học sinh làm bài trong phòng, nộp, thấy kết quả.
void main() {
  http.Response j(Object o) =>
      http.Response.bytes(utf8.encode(jsonEncode(o)), 200, headers: {'content-type': 'application/json'});

  Map<String, dynamic> cau(int id) => {
        'id': id,
        'question': 'Câu hỏi số $id?',
        'options': {'A': 'Phương án A$id', 'B': 'B$id', 'C': 'C$id', 'D': 'D$id'},
        'da_chon': null,
      };

  testWidgets('làm hết câu → tự nộp → thấy điểm và giải thích', (t) async {
    final daGui = <String>[];
    final api = ApiClient(
      baseUrl: 'http://kiem-thu',
      httpClient: MockClient((req) async {
        final p = req.url.path;
        if (p.endsWith('/de')) {
          return j({
            'bai': {'da_nop': false, 'giay_moi_cau': 30, 'da_lam': 0, 'tong': 2},
            'dang_mo': true,
            'cau': [cau(1), cau(2)],
          });
        }
        if (p.endsWith('/tra-loi')) {
          final b = jsonDecode(req.body) as Map;
          daGui.add('${b['question_id']}:${b['chon']}');
          return j({'dung': b['question_id'] == 1});
        }
        if (p.endsWith('/nop')) {
          return j({
            'so_dung': 1,
            'tong': 2,
            'diem_10': 5.0,
            'cau': [
              {...cau(1), 'chon': 'A', 'dung': true, 'correct_option': 'A', 'explanation': 'Vì lý do một'},
              {...cau(2), 'chon': 'A', 'dung': false, 'correct_option': 'C', 'explanation': 'Vì lý do hai'},
            ],
          });
        }
        return http.Response('{}', 404);
      }),
    )..setToken('ma');

    await t.pumpWidget(MaterialApp(home: LamBaiScreen(ma: '123456', tieuDe: 'Ôn tập', api: LopHocApi(api))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Câu hỏi số 1?'), findsOneWidget);
    expect(find.text('Câu 1/2'), findsOneWidget);

    await t.tap(find.text('Phương án A1'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Chính xác!'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 950));
    expect(find.text('Câu hỏi số 2?'), findsOneWidget);

    await t.tap(find.text('Phương án A2'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Chưa đúng'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 950));
    await t.pump(const Duration(milliseconds: 100));

    expect(daGui, ['1:A', '2:A']);
    expect(find.text('1/2 câu đúng'), findsOneWidget);
    expect(find.text('Điểm 5.0 / 10'), findsOneWidget);
    expect(find.textContaining('Đáp án: C. C2'), findsOneWidget);
    expect(find.text('Vì lý do hai'), findsOneWidget);
  });

  testWidgets('hết giờ một câu → gửi bỏ trống và sang câu sau', (t) async {
    final daGui = <String>[];
    final api = ApiClient(
      baseUrl: 'http://kiem-thu',
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/de')) {
          return j({
            'bai': {'da_nop': false, 'giay_moi_cau': 10, 'da_lam': 0, 'tong': 2},
            'dang_mo': true,
            'cau': [cau(7), cau(8)],
          });
        }
        if (req.url.path.endsWith('/tra-loi')) {
          final b = jsonDecode(req.body) as Map;
          daGui.add('${b['question_id']}:${b['chon']}');
          return j({'dung': false});
        }
        return j({'so_dung': 0, 'tong': 2, 'diem_10': 0, 'cau': []});
      }),
    )..setToken('ma');
    await t.pumpWidget(MaterialApp(home: LamBaiScreen(ma: '123456', tieuDe: 'x', api: LopHocApi(api))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 11; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(daGui, ['7:']);
    expect(find.text('Câu hỏi số 8?'), findsOneWidget);
    // dọn hẹn giờ của câu 8
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('vào lại giữa chừng thì bỏ qua câu đã làm', (t) async {
    final api = ApiClient(
      baseUrl: 'http://kiem-thu',
      httpClient: MockClient((req) async => j({
            'bai': {'da_nop': false, 'giay_moi_cau': 30, 'da_lam': 1, 'tong': 2},
            'dang_mo': true,
            'cau': [
              {...cau(1), 'da_chon': 'B'},
              cau(2),
            ],
          })),
    )..setToken('ma');
    await t.pumpWidget(MaterialApp(home: LamBaiScreen(ma: '123456', tieuDe: 'x', api: LopHocApi(api))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Câu 2/2'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
