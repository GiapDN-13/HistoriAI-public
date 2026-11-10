import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/features/lop_hoc/bang_vang.dart';
import 'package:historiai/features/lop_hoc/lop_hoc_api.dart';

class _ApiBang extends LopHocApi {
  _ApiBang(this.du);
  final Map<String, dynamic> du;
  @override
  Future<Map<String, dynamic>> bangVang(String ma) async => du;
}

/// Giấy vinh danh: đủ chữ, không tràn trên máy hẹp, danh hiệu đúng theo hạng.
void main() {
  Map<String, dynamic> du({int hang = 1, String ten = 'Nguyễn Văn An'}) => {
        'tieu_de': 'Ôn tập Bạch Đằng 938 — 7A2',
        'giao_vien': 'Cô Lan',
        'ngay': '2026-10-05T03:00:00Z',
        'tong_hoc_sinh': 32,
        'tong_cau': 10,
        'top': [],
        'cua_toi': {
          'ten': ten,
          'lop': '7A2',
          'hang': hang,
          'so_dung': 9,
          'diem': null,
          'diem_10': 9.0,
          'vuot_pct': 97
        },
      };

  test('danh hiệu theo hạng và điểm', () {
    expect(danhHieu(1, 3).$1, 'Trạng Nguyên');
    expect(danhHieu(3, 3).$1, 'Thám Hoa');
    expect(danhHieu(7, 8.5).$1, 'Xuất sắc');
    expect(danhHieu(20, 4).$1, 'Đã hoàn thành');
  });

  for (final rong in [320.0, 412.0, 1280.0]) {
    testWidgets('màn giấy đổi được khổ và boundary cố định $rong', (t) async {
      t.view.physicalSize = Size(rong, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
          home: GiayVinhDanhScreen(
              du: du(ten: 'Tôn Nữ Hoàng Phương Thảo Nguyên'))));
      final giay = find.byType(GiayVinhDanh);
      expect(t.getSize(giay), const Size(480, 600));
      await t.tap(find.text('Bài đăng 4:5 · đổi sang story'));
      await t.pumpAndSettle();
      expect(t.getSize(giay).width, 420);
      expect(t.getSize(giay).height, closeTo(420 * 16 / 9, .01));
      expect(t.takeException(), isNull);
    });
    testWidgets('giấy vinh danh không tràn ở bề ngang $rong', (t) async {
      t.view.physicalSize = Size(rong, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: GiayVinhDanh(
                      du: du(ten: 'Tôn Nữ Hoàng Phương Thảo Nguyên'))))));
      expect(t.takeException(), isNull);
      expect(find.text('TRẠNG NGUYÊN'), findsOneWidget);
      expect(find.text('Vượt 97% các bạn cùng làm bài'), findsOneWidget);
      expect(find.textContaining('Điểm 9/10'), findsOneWidget);
    });
  }
  testWidgets('em ngoài top 10 vẫn có dòng riêng khi hạng null', (t) async {
    final d = du(ten: 'Tôn Nữ Hoàng Phương Thảo Nguyên');
    d['cua_toi']['hang'] = null;
    d['tong_cau'] = null;
    d['top'] = List.generate(10, (i) => {'ten': 'Bạn ${i + 1}', 'hang': i + 1});
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: BangVangPhong(ma: '123456', api: _ApiBang(d))))));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.textContaining('Thảo Nguyên  (em)'), 200);
    expect(find.textContaining('Thảo Nguyên  (em)'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final story in [false, true]) {
    testWidgets('giấy ${story ? '9:16' : '4:5'} hạng thấp không hiện Hạng',
        (t) async {
      final d = du(hang: 28, ten: 'Tôn Nữ Hoàng Phương Thảo Nguyên');
      d['cua_toi']['vuot_pct'] = 10;
      await t.pumpWidget(
          MaterialApp(home: Scaffold(body: GiayVinhDanh(du: d, story: story))));
      expect(find.textContaining('Hạng'), findsNothing);
      expect(t.takeException(), isNull);
    });
    testWidgets('giấy ${story ? '9:16' : '4:5'} các trường null không tràn',
        (t) async {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: GiayVinhDanh(du: const {'cua_toi': null}, story: story))));
      expect(find.textContaining('null'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}
