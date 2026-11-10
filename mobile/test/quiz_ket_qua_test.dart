import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:historiai/core/analytics.dart';
import 'package:historiai/core/widgets/phao_giay.dart';
import 'package:historiai/data/models.dart';
import 'package:historiai/features/quiz/quiz_result_screen.dart';

/// Màn kết quả là khoảnh khắc đáng ăn mừng nhất trong cả sản phẩm.
///
/// Trước đây thắng và thua dùng CHUNG một khung, chỉ đổi chữ và biểu tượng:
/// không pháo giấy, không rung tay, và thua thì không có đường đánh lại dù
/// tiêu đề đã ghi sẵn "RÈN LUYỆN LẠI". Những test dưới đây khoá lại cả ba.
///
/// KHÔNG dùng pumpAndSettle: pháo giấy và lớp tàn lửa đều là hoạt hoạ chạy
/// liên tục, chờ lắng là treo tới hết giờ.
/// Bơm đủ 3 giây cho MỌI hoạt hoạ một-lần chạy hết: vòng đếm điểm (trễ 300ms
/// rồi chạy 800ms) và pháo giấy (2,6 giây). Dừng sớm là test kết thúc lúc bộ
/// hẹn giờ còn sống và Flutter báo hỏng.
Future<void> lang(WidgetTester t, [int ms = 3000]) async {
  await t.pump();
  await t.pump(Duration(milliseconds: ms));
}

List<QuizSubmitResult> _ketQua(int dung, int tong) => [
      for (var i = 0; i < tong; i++)
        QuizSubmitResult(
          questionId: i,
          correct: i < dung,
          correctOption: 'A',
          explanation: 'Giải thích $i',
        ),
    ];

Widget _man({required int diem, required int mangConLai, int dung = 8}) =>
    MaterialApp(
      home: QuizResultScreen(
        score: diem,
        totalQuestions: 10,
        livesLeft: mangConLai,
        results: _ketQua(dung, 10),
        eventTitle: 'Trận Bạch Đằng 938',
      ),
    );

void main() {
  setUp(() => Analytics.instance.datLaiChoTest());

  testWidgets('Thắng thì bắn pháo giấy', (t) async {
    await t.pumpWidget(_man(diem: 80, mangConLai: 2));
    await lang(t);

    final phao = t.widget<PhaoGiay>(find.byType(PhaoGiay));
    expect(phao.chay, isTrue, reason: 'thắng mà không có gì reo lên thì phí');
    expect(find.text('BẢNG VÀNG KHẮC TÊN'), findsOneWidget);
  });

  testWidgets('Thua thì KHÔNG bắn pháo — mừng lúc người ta thua là chế nhạo',
      (t) async {
    await t.pumpWidget(_man(diem: 0, mangConLai: 0, dung: 3));
    await lang(t);

    final phao = t.widget<PhaoGiay>(find.byType(PhaoGiay));
    expect(phao.chay, isFalse);
    expect(find.text('RÈN LUYỆN LẠI'), findsOneWidget);
  });

  testWidgets('Thua thì có đường đánh lại ngay, không bắt quay về bản đồ tìm lại',
      (t) async {
    await t.pumpWidget(_man(diem: 0, mangConLai: 0, dung: 3));
    await lang(t);

    // Nút nằm dưới khung báo lưu — cuộn tới (ListView chỉ dựng phần đang thấy).
    await t.scrollUntilVisible(find.text('Đánh lại trận này'), 200);
    expect(find.text('Đánh lại trận này'), findsOneWidget,
        reason: 'tiêu đề ghi "RÈN LUYỆN LẠI" thì phải có nút để làm việc đó');
  });

  testWidgets('Thắng thì KHÔNG mời đánh lại — vừa thắng mà giục chơi lại là kỳ',
      (t) async {
    await t.pumpWidget(_man(diem: 80, mangConLai: 2));
    await lang(t);

    await t.scrollUntilVisible(find.text('Nhận giấy khen'), 200);
    expect(find.text('Đánh lại trận này'), findsNothing);
    expect(find.text('Nhận giấy khen'), findsOneWidget);
  });

  testWidgets('Điểm đếm dần lên chứ không nhảy thẳng tới số cuối', (t) async {
    await t.pumpWidget(_man(diem: 80, mangConLai: 2));
    await t.pump();
    await t.pump(const Duration(milliseconds: 450));

    // Vòng đếm bắt đầu trễ 300ms rồi chạy 800ms qua 20 nhịp. Ở mốc 450ms phải
    // đang ở lưng chừng — thấy ngay 80 nghĩa là vòng đếm đã chết.
    expect(find.text('+80'), findsNothing,
        reason: 'đang giữa vòng đếm mà đã ra số cuối');

    await t.pump(const Duration(milliseconds: 900));
    expect(find.text('+80'), findsOneWidget, reason: 'đếm xong phải ra đủ điểm');

    // Xả nốt pháo giấy trước khi test kết thúc.
    await t.pump(const Duration(milliseconds: 2600));
  });

  group('Nói thật bài đã lưu chưa (audit 27/09)', () {
    Widget man(TrangThaiLuu tt, {int? xp, List<QuizSubmitResult>? kq}) => MaterialApp(
          home: QuizResultScreen(
            score: 30,
            totalQuestions: 5,
            livesLeft: 2,
            results: kq ?? const [],
            eventTitle: 'Trận Bạch Đằng 938',
            soCauDung: 3,
            xpNhan: xp,
            trangThaiLuu: tt,
          ),
        );

    testWidgets('Khách: báo chưa vào tài khoản, vẫn đếm đúng số câu', (t) async {
      await t.pumpWidget(man(TrangThaiLuu.khach));
      await lang(t);
      expect(find.textContaining('chưa vào tài khoản'), findsOneWidget);
      expect(find.text('3 / 5 câu đúng'), findsOneWidget);
      expect(find.text('ĐIỂM TRẬN NÀY · CHƯA LƯU'), findsOneWidget);
    });

    testWidgets('Nộp hỏng: báo mất kết nối, không giả vờ đã lưu', (t) async {
      await t.pumpWidget(man(TrangThaiLuu.loi));
      await lang(t);
      expect(find.textContaining('mất kết nối'), findsOneWidget);
    });

    testWidgets('Đã lưu mà 0 XP vì câu đúng từ trước: nói rõ lý do', (t) async {
      await t.pumpWidget(man(TrangThaiLuu.daLuu, xp: 0, kq: _ketQua(3, 5)));
      await lang(t);
      expect(find.textContaining('lần đầu trả lời đúng'), findsOneWidget);
      expect(find.text('XP NHẬN ĐƯỢC'), findsOneWidget);
    });
  });
}
