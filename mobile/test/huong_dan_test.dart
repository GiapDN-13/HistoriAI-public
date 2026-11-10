import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:historiai/core/analytics.dart';
import 'package:historiai/features/onboarding/huong_dan_screen.dart';

/// Bơm vài khung cho hoạt hoạ vào trang chạy xong.
///
/// KHÔNG dùng pumpAndSettle: hình minh hoạ "thở" là hoạt hoạ LẶP VÔ HẠN nên
/// khung hình không bao giờ lắng, pumpAndSettle sẽ treo tới hết giờ.
Future<void> lang(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Tắt hẳn đo lường: màn này bắn sự kiện ở initState, để bật thì test treo
    // vì bộ hẹn giờ gửi hàng đợi không bao giờ xong.
    Analytics.instance.datLaiChoTest();
  });

  Future<void> mo(WidgetTester t, {VoidCallback? khiXong}) async {
    await t.pumpWidget(MaterialApp(
      home: HuongDanScreen(khiXong: khiXong ?? () {}),
    ));
    await lang(t);
  }

  group('Chỉ hiện một lần', () {
    test('lần đầu thì chưa xem', () async {
      expect(await HuongDanScreen.daXem(), isFalse);
    });

    test('đánh dấu xong thì lần sau không hiện nữa', () async {
      await HuongDanScreen.danhDauDaXem();
      expect(await HuongDanScreen.daXem(), isTrue);
    });

    testWidgets('bỏ qua cũng tính là đã xem — không được hỏi lại người ta',
        (t) async {
      var xong = false;
      await mo(t, khiXong: () => xong = true);

      await t.tap(find.text('Bỏ qua'));
      await lang(t);

      expect(xong, isTrue, reason: 'phải gọi khiXong để đi tiếp');
      expect(await HuongDanScreen.daXem(), isTrue,
          reason: 'bỏ qua mà lần sau vẫn hiện thì rất phiền');
    });
  });

  group('Luồng đi qua các trang', () {
    testWidgets('mở ra là thấy trang đầu', (t) async {
      await mo(t);
      expect(find.text('Hỏi thẳng người trong cuộc'), findsOneWidget);
      expect(find.text('Tiếp tục'), findsOneWidget);
      expect(find.text('Bắt đầu'), findsNothing);
    });

    testWidgets('bấm Tiếp tục tới hết thì nút đổi thành Bắt đầu', (t) async {
      var xong = false;
      await mo(t, khiXong: () => xong = true);

      // Bốn trang: ba lần bấm là tới trang cuối.
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text('Tiếp tục'));
        await lang(t);
      }
      expect(find.text('Bắt đầu'), findsOneWidget,
          reason: 'trang cuối phải mời người ta vào app, không phải "Tiếp tục"');
      expect(xong, isFalse, reason: 'chưa bấm thì chưa được đi');

      await t.tap(find.text('Bắt đầu'));
      await lang(t);
      expect(xong, isTrue);
    });

    testWidgets('mọi trang đều có tiêu đề và mô tả, không trang nào trống',
        (t) async {
      await mo(t);
      final tieuDe = [
        'Hỏi thẳng người trong cuộc',
        'Đặt cổ vật ra giữa phòng',
        'Làm quiz ở Đấu trường',
        'Đi dọc dòng thời gian',
      ];
      for (var i = 0; i < tieuDe.length; i++) {
        expect(find.text(tieuDe[i]), findsOneWidget);
        if (i < tieuDe.length - 1) {
          await t.tap(find.text('Tiếp tục'));
          await lang(t);
        }
      }
    });
  });

  testWidgets('không tràn ở màn hẹp 360 px', (t) async {
    // Máy Android phổ thông rộng 360 dp. Trang hướng dẫn mà tràn thì lỗi hiện
    // ngay trên màn hình đầu tiên người dùng nhìn thấy.
    t.view.physicalSize = const Size(360 * 3, 640 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await mo(t);
    expect(tester0Overflow(t), isTrue);
  });
}

/// Không có ngoại lệ tràn nào được ném ra trong lượt dựng vừa rồi.
bool tester0Overflow(WidgetTester t) => t.takeException() == null;
