import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:historiai/core/analytics.dart';
import 'package:historiai/core/widgets/chi_dan.dart';

/// Bơm khung cho hoạt hoạ hiện ra chạy xong.
///
/// KHÔNG dùng pumpAndSettle — lớp chỉ dẫn nằm trong dialog và nền app có thể
/// còn hoạt hoạ lặp, chờ lắng là treo.
Future<void> lang(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(ChiDan.datLaiChoTest);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Analytics.instance.datLaiChoTest();
  });

  /// Màn giả có ba ô để chỉ vào.
  Widget manGia(GlobalKey a, GlobalKey b, {VoidCallback? khiDung}) {
    return MaterialApp(
      home: Builder(builder: (ctx) {
        return Scaffold(
          body: Column(
            children: [
              Container(key: a, height: 80, color: Colors.red),
              const SizedBox(height: 40),
              Container(key: b, height: 80, color: Colors.blue),
              ElevatedButton(
                onPressed: () {
                  khiDung?.call();
                  ChiDan.chay(
                    ctx,
                    khoa: 'thu-nghiem',
                    doTre: Duration.zero,
                    cacBuoc: [
                      BuocChiDan(khoa: a, tieuDe: 'Bước một', noiDung: 'Mô tả một'),
                      BuocChiDan(khoa: b, tieuDe: 'Bước hai', noiDung: 'Mô tả hai'),
                    ],
                  );
                },
                child: const Text('chay'),
              ),
            ],
          ),
        );
      }),
    );
  }

  testWidgets('đi hết các bước rồi tự đóng', (t) async {
    final a = GlobalKey(), b = GlobalKey();
    await t.pumpWidget(manGia(a, b));
    await t.tap(find.text('chay'));
    await lang(t);

    expect(find.text('Bước một'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);

    await t.tap(find.text('Tiếp'));
    await lang(t);
    expect(find.text('Bước hai'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    // Bước cuối phải đổi chữ, không thể mời "Tiếp" khi hết chỗ để đi.
    expect(find.text('Đã hiểu'), findsOneWidget);

    await t.tap(find.text('Đã hiểu'));
    await lang(t);
    expect(find.text('Bước hai'), findsNothing);
  });

  testWidgets('chỉ chạy một lần cho mỗi màn', (t) async {
    final a = GlobalKey(), b = GlobalKey();
    await t.pumpWidget(manGia(a, b));

    await t.tap(find.text('chay'));
    await lang(t);
    await t.tap(find.text('Tiếp'));
    await lang(t);
    await t.tap(find.text('Đã hiểu'));
    await lang(t);

    // Lần thứ hai không được hiện lại.
    await t.tap(find.text('chay'));
    await lang(t);
    expect(find.text('Bước một'), findsNothing);
  });

  testWidgets('bỏ qua cũng tính là đã xem', (t) async {
    final a = GlobalKey(), b = GlobalKey();
    await t.pumpWidget(manGia(a, b));
    await t.tap(find.text('chay'));
    await lang(t);

    await t.tap(find.text('Bỏ qua'));
    await lang(t);
    expect(find.text('Bước một'), findsNothing);
    expect(await ChiDan.daXem('thu-nghiem'), isTrue);
  });

  testWidgets('xoaHet bật lại chỉ dẫn — nút "Xem lại hướng dẫn" dựa vào đây',
      (t) async {
    await ChiDan.danhDauDaXem('mot-man-nao-do');
    expect(await ChiDan.daXem('mot-man-nao-do'), isTrue);

    await ChiDan.xoaHet();
    expect(await ChiDan.daXem('mot-man-nao-do'), isFalse);
  });

  testWidgets('widget đích chưa dựng thì bỏ qua bước đó, không dựng ô trống',
      (t) async {
    final a = GlobalKey();
    final chuaDung = GlobalKey();  // không gắn vào cây widget nào

    await t.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        return Scaffold(
          body: Column(children: [
            Container(key: a, height: 80, color: Colors.red),
            ElevatedButton(
              onPressed: () => ChiDan.chay(
                ctx,
                khoa: 'thieu-dich',
                doTre: Duration.zero,
                cacBuoc: [
                  BuocChiDan(
                      khoa: chuaDung, tieuDe: 'Không có', noiDung: 'x'),
                  BuocChiDan(khoa: a, tieuDe: 'Có thật', noiDung: 'y'),
                ],
              ),
              child: const Text('chay'),
            ),
          ]),
        );
      }),
    ));

    await t.tap(find.text('chay'));
    await lang(t);

    // Bước hỏng bị loại, bước còn lại hiện bình thường và là bước duy nhất.
    expect(find.text('Không có'), findsNothing);
    expect(find.text('Có thật'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
  });

  testWidgets('không còn bước nào dựng được thì không mở gì cả', (t) async {
    final ma = GlobalKey();
    await t.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () => ChiDan.chay(
              ctx,
              khoa: 'rong',
              doTre: Duration.zero,
              cacBuoc: [BuocChiDan(khoa: ma, tieuDe: 'Ma', noiDung: 'x')],
            ),
            child: const Text('chay'),
          ),
        );
      }),
    ));

    await t.tap(find.text('chay'));
    // Bơm đủ 3 giây: bộ chỉ dẫn CỐ Ý thử lại 10 nhịp trước khi bỏ cuộc, phòng
    // trường hợp widget đích chỉ xuất hiện sau khi dữ liệu về. Không bơm đủ
    // thì test kết thúc lúc bộ hẹn giờ còn sống và Flutter báo hỏng.
    await t.pump();
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 320));
    }
    expect(find.text('Ma'), findsNothing);
    // Không được đánh dấu đã xem: lần sau màn dựng đủ thì vẫn phải chỉ.
    expect(await ChiDan.daXem('rong'), isFalse);
  });

  testWidgets('tab đang ẩn thì chưa chỉ; mở tab ra mới chỉ (lỗi chồng chỉ dẫn 27/09)',
      (t) async {
    final dich = GlobalKey();
    final hien = ValueNotifier(false);
    await t.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<bool>(
        valueListenable: hien,
        builder: (_, bat, __) => TickerMode(
          enabled: bat,
          child: Builder(builder: (ctx) {
            return Scaffold(
              body: Column(children: [
                SizedBox(key: dich, width: 50, height: 50),
                ElevatedButton(
                  onPressed: () => ChiDan.chay(ctx,
                      khoa: 'tab-an',
                      doTre: Duration.zero,
                      cacBuoc: [BuocChiDan(khoa: dich, tieuDe: 'Chỉ ở đây', noiDung: 'x')]),
                  child: const Text('chay'),
                ),
              ]),
            );
          }),
        ),
      ),
    ));
    await t.tap(find.text('chay'));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Chỉ ở đây'), findsNothing, reason: 'tab ẩn không được hiện chỉ dẫn');
    hien.value = true;
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Chỉ ở đây'), findsOneWidget, reason: 'mở tab thì phải chỉ');
    ChiDan.datLaiChoTest();
  });
}
