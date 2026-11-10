import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:historiai/core/analytics.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/core/lo_trinh_dau.dart';
import 'package:historiai/core/utils/scholarly_rank.dart';
import 'package:historiai/core/widgets/giai_thich_diem.dart';
import 'package:historiai/data/models.dart';
import 'package:historiai/features/dashboard/bat_dau_tu_day.dart';
import 'package:historiai/features/dashboard/the_cai_iphone.dart';
import 'package:historiai/features/quiz/quiz_play_screen.dart';
import 'package:historiai/features/timeline/event_detail_screen.dart';

/// Khoá lại các sửa theo góp ý người dùng đợt 21/10 (docs/RA_SOAT_PHAN_HOI_21-10.md).

Map<String, dynamic> _cau(int id, String hoi) => {
      'id': id,
      'question': hoi,
      'option_a': 'Ngô Quyền',
      'option_b': 'Kiều Công Tiễn',
      'option_c': 'Lưu Hoằng Tháo',
      'option_d': 'Lưu Cung',
      'difficulty': 1,
    };

/// Máy chủ giả: 2 câu; câu 1 đáp án B (có lời giải), câu 2 đáp án A.
ApiClient _mayChuGia() => ApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient((req) async {
        final p = req.url.path;
        if (p.endsWith('/quiz/bach-dang-938')) {
          return http.Response(
              jsonEncode([_cau(1, 'Ai giết Dương Đình Nghệ?'), _cau(2, 'Câu thứ hai?')]),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (p.endsWith('/quiz/check')) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final id = body['question_id'] as int;
          final dung = id == 1 ? 'B' : 'A';
          return http.Response(
              jsonEncode({
                'question_id': id,
                'correct': body['selected_option'] == dung,
                'correct_option': dung,
                'explanation': id == 1 ? 'Kiều Công Tiễn giết Dương Đình Nghệ năm 937.' : null,
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('{}', 404);
      }),
    );

Widget _quiz() => const MaterialApp(
      home: QuizPlayScreen(eventSlug: 'bach-dang-938', eventTitle: 'Trận Bạch Đằng 938'),
    );

void main() {
  late ApiClient api;

  setUp(() {
    Analytics.instance.datLaiChoTest();
    SharedPreferences.setMockInitialValues({});
    LoTrinhDau.datLaiChoTest();
    api = _mayChuGia();
    ApiClient.datDungChungChoTest(api);
  });
  tearDown(() => api.dispose());

  group('Đấu trường — góp ý "chọn sai không hiện đáp án đúng"', () {
    testWidgets('chọn sai: hiện đáp án đúng + lời giải, CHỜ bấm "Câu tiếp theo"', (t) async {
      await t.pumpWidget(_quiz());
      await t.pump();
      await t.pump();
      expect(find.text('Ai giết Dương Đình Nghệ?'), findsOneWidget);

      await t.tap(find.text('Ngô Quyền')); // sai — đúng là B
      await t.pump();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400)); // cuộn xuống thẻ giải thích

      expect(find.byKey(const Key('quiz-giai-thich')), findsOneWidget);
      expect(find.text('Đáp án đúng', skipOffstage: false), findsOneWidget,
          reason: 'ô B phải được đánh dấu');
      expect(find.text('Kiều Công Tiễn giết Dương Đình Nghệ năm 937.'), findsOneWidget);

      // Không tự sang câu nữa: chờ quá 1,4 giây vẫn ở câu 1.
      await t.pump(const Duration(seconds: 3));
      expect(find.text('Ai giết Dương Đình Nghệ?'), findsOneWidget);

      await t.tap(find.byKey(const Key('quiz-cau-tiep')));
      await t.pump();
      expect(find.text('Câu thứ hai?'), findsOneWidget);

      await t.pumpWidget(const SizedBox()); // huỷ đồng hồ đếm giờ
    });

    testWidgets('chọn đúng: không chặn lại, tự sang câu sau', (t) async {
      await t.pumpWidget(_quiz());
      await t.pump();
      await t.pump();
      await t.tap(find.text('Kiều Công Tiễn'));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('quiz-cau-tiep')), findsNothing);
      await t.pump(const Duration(milliseconds: 1500));
      expect(find.text('Câu thứ hai?'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('Điểm, cấp, chuỗi ngày — góp ý "không hiểu XP và streak dùng để làm gì"', () {
    test('cấp tính đúng công thức máy chủ ⌊√(điểm/100)⌋ + 1', () {
      for (final (xp, cap) in [(0, 1), (99, 1), (100, 2), (399, 2), (400, 3), (900, 4), (2500, 6)]) {
        expect(ScholarlyRank.capTuDiem(xp), cap, reason: '$xp điểm');
      }
    });

    test('mỗi danh hiệu có nghĩa dễ hiểu, không còn chữ "mưu lược"', () {
      for (final r in ScholarlyRank.allRanks) {
        expect(r.nghia.trim(), isNotEmpty);
        expect(r.description.toLowerCase(), isNot(contains('mưu lược')));
      }
    });

    testWidgets('bảng giải thích có đủ 4 mục và chỉ đúng danh hiệu hiện tại', (t) async {
      await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: GiaiThichDiem(xp: 150, streak: 3, daDangNhap: true)),
      ));
      for (final muc in ['Điểm (XP)', 'Cấp độ', 'Chuỗi ngày học', 'Bảng vàng']) {
        expect(find.text(muc), findsOneWidget);
      }
      expect(find.textContaining('150 điểm · cấp 2 · chuỗi 3 ngày'), findsOneWidget);
      expect(find.text('Bạn ở đây'), findsOneWidget);
    });
  });

  group('Bắt đầu từ đây — góp ý "chưa biết nên xem video, làm quiz hay chat trước"', () {
    final e938 = HistoricalEvent(slug: 'bach-dang-938', title: 'Trận Bạch Đằng 938', year: 938);

    testWidgets('hiện 3 bước; bước tự đánh dấu khi người dùng làm thật', (t) async {
      await LoTrinhDau.khoiDong();
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: BatDauTuDay(suKien: [e938]))),
      ));
      expect(find.textContaining('Bước 1'), findsOneWidget);
      expect(find.textContaining('Bước 3'), findsOneWidget);
      expect(find.text('0/3'), findsOneWidget);

      Analytics.instance.log(Ev.quizSubmit, target: 'bach-dang-938');
      await t.pump();
      expect(find.text('1/3'), findsOneWidget);
      expect(LoTrinhDau.daXong.value, contains(LoTrinhDau.lamQuiz));
    });

    testWidgets('bấm ẩn thì thẻ biến mất', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: BatDauTuDay(suKien: [e938]))),
      ));
      await t.tap(find.byTooltip('Ẩn thẻ này'));
      await t.pump();
      expect(find.byKey(const Key('bat-dau-tu-day')), findsNothing);
    });

    testWidgets('không có Bạch Đằng 938 trong kho thì không hiện', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BatDauTuDay(
                suKien: [HistoricalEvent(slug: 'lam-son-1428', title: 'Lam Sơn', year: 1428)])),
      ));
      expect(find.byKey(const Key('bat-dau-tu-day')), findsNothing);
    });
  });

  test('chương trình học: bỏ dòng chủ đề tách hỏng (chỉ còn "XVIII")', () {
    final e = HistoricalEvent(
      slug: 'lam-son-1428',
      title: 'Lam Sơn',
      year: 1428,
      grades: const [7, 8, 11],
      curriculum: const [
        CurriculumRef(ma: 'THCS-7-05', lop: 7, chuDe: 'VIỆT NAM TỪ ĐẦU THẾ KỈ X ĐẾN ĐẦU THẾ KỈ XVI'),
        CurriculumRef(ma: 'THCS-8-04', lop: 8, chuDe: 'XVIII'),
        CurriculumRef(ma: 'THPT-11-04', lop: 11, chuDe: 'CHIẾN TRANH BẢO VỆ TỔ QUỐC'),
      ],
    );
    expect(e.chuongTrinhHopLe.map((c) => c.ma), ['THCS-7-05', 'THPT-11-04']);
    expect(e.lopHoc, [7, 11]);
  });

  group('Màn chi tiết sự kiện', () {
    Future<void> mo(WidgetTester t, String slug, String features) async {
      await t.pumpWidget(MaterialApp(
        home: EventDetailScreen(
          event: HistoricalEvent(slug: slug, title: 'Trận thử', year: 1000, features: features),
        ),
      ));
      await t.pump();
    }

    testWidgets('trận có phim gốc chờ dựng: hiện "Phim đang được dựng" + Ghi nhớ nhanh', (t) async {
      await mo(t, 'khang-chien-tong-981', 'quiz,timeline');
      expect(find.byKey(const Key('ghi-nho-nhanh'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('phim-dang-dung'), skipOffstage: false), findsOneWidget);
      expect(find.text('PHIM ĐANG ĐƯỢC DỰNG', skipOffstage: false), findsOneWidget);
    });

    testWidgets('trận chưa có phim gốc (Bạch Đằng 1288): không hứa phim', (t) async {
      await mo(t, 'bach-dang-1288', 'chat,timeline,quiz');
      expect(find.byKey(const Key('ghi-nho-nhanh'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('phim-dang-dung'), skipOffstage: false), findsNothing);
    });

    testWidgets('trận không có câu chốt trong tài liệu nhóm: không hiện Ghi nhớ nhanh', (t) async {
      await mo(t, 'lam-son-1428', 'quiz,timeline');
      expect(find.byKey(const Key('ghi-nho-nhanh'), skipOffstage: false), findsNothing);
    });
  });

  testWidgets('thẻ iPhone: "Xem cách" mở 3 bước Thêm vào MH chính', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: TheCaiIphone(onAn: () {}))));
    await t.tap(find.text('Xem cách'));
    await t.pumpAndSettle();
    expect(find.text('Thêm HistoriAI vào màn hình chính'), findsOneWidget);
    expect(find.text('Chọn "Thêm vào MH chính"'), findsOneWidget);
  });
}
