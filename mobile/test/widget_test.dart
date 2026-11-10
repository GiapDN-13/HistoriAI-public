import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/core/analytics.dart';
import 'package:historiai/features/onboarding/huong_dan_screen.dart';
import 'package:historiai/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Tắt đo lường: nó gom event rồi gửi sau 2 giây, mà một timer còn sống
    // lúc bài test kết thúc là Flutter báo hỏng ngay.
    Analytics.instance.datLaiChoTest();
  });

  testWidgets('Chưa đăng nhập: mở app vào màn Sign In', (tester) async {
    SharedPreferences.setMockInitialValues(
        {HuongDanScreen.khoaDaXem: true});  // bỏ qua hướng dẫn lần đầu
    await tester.pumpWidget(const HistoriAIApp());

    // Splash chờ 2,4s rồi chuyển màn, kèm hào quang quay LẶP VÔ HẠN — nên
    // không dùng `pumpAndSettle` (sẽ treo), mà bơm khung theo mốc thời gian.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 700));

    // Phải có đường đăng nhập: không đăng nhập thì điểm quiz không lưu được.
    expect(find.text('Đăng nhập'), findsOneWidget);
    // Vẫn giữ lối xem thử nhanh để demo, nay là hành động phụ rõ ràng.
    expect(find.text('Dùng thử không cần tài khoản'), findsOneWidget);
  });

  testWidgets('Kiem tra cac widget tren man hinh', (tester) async {
    SharedPreferences.setMockInitialValues(
        {HuongDanScreen.khoaDaXem: true});  // bỏ qua hướng dẫn lần đầu
    await tester.pumpWidget(const HistoriAIApp());
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(HistoriAIApp), findsOneWidget);
  });

  testWidgets('Mở app lần đầu thì vào phần hướng dẫn, chưa vào đăng nhập',
      (tester) async {
    // Người mở lần đầu — kể cả hội đồng chấm — cần biết sản phẩm làm được gì
    // trước khi bị hỏi tài khoản.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HistoriAIApp());
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Hỏi thẳng người trong cuộc'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsNothing);
  });

  testWidgets('Bỏ qua hướng dẫn thì PHẢI sang được màn đăng nhập', (tester) async {
    // Lỗi cũ: màn hướng dẫn gọi ngược về SplashScreen để chuyển màn, nhưng
    // Splash đã tự thay chính nó nên State đã huỷ — lời gọi rơi vào hư không,
    // không lỗi không log. Người mở app lần đầu bấm gì cũng đứng yên, phải
    // tải lại trang mới thoát. Test này khoá lại đường ra.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HistoriAIApp());
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Bỏ qua'), findsOneWidget, reason: 'phải đang ở hướng dẫn');

    await tester.tap(find.text('Bỏ qua'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Đăng nhập'), findsOneWidget,
        reason: 'bỏ qua hướng dẫn mà vẫn kẹt lại là ngõ cụt');
    expect(find.text('Bỏ qua'), findsNothing);
  });
}
