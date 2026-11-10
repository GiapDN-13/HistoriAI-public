import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:historiai/core/analytics.dart';
import 'package:historiai/features/phan_hoi/hoi_phan_hoi.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Analytics.instance.datLaiChoTest();
  });

  group('Lịch tự hỏi phản hồi', () {
    final bayGio = DateTime(2026, 9, 27, 10);

    test('Chưa hỏi bao giờ thì được hỏi', () {
      expect(LichHoiPhanHoi.nenHoi(bayGio: bayGio), isTrue);
    });

    test('Mới hỏi 2 ngày trước thì chưa hỏi lại; đủ 3 ngày thì được', () {
      expect(LichHoiPhanHoi.nenHoi(bayGio: bayGio,
          lanCuoi: bayGio.subtract(const Duration(days: 2))), isFalse);
      expect(LichHoiPhanHoi.nenHoi(bayGio: bayGio,
          lanCuoi: bayGio.subtract(const Duration(days: 3))), isTrue);
    });

    test('Bấm "Để sau" 3 lần thì thôi hẳn, không tự hỏi nữa', () {
      expect(LichHoiPhanHoi.nenHoi(bayGio: bayGio, boQua: 2), isTrue);
      expect(LichHoiPhanHoi.nenHoi(bayGio: bayGio, boQua: 3), isFalse);
    });

    test('Mỗi phiên chỉ tự hỏi một lần', () {
      expect(LichHoiPhanHoi.nenHoi(bayGio: bayGio, daHoiPhienNay: true), isFalse);
    });

    test('Sau quiz chỉ cần cách 1 ngày; ngữ cảnh khác vẫn 3 ngày', () {
      final sauQuiz = LichHoiPhanHoi.khoangCachCho('quiz');
      expect(sauQuiz, const Duration(days: 1));
      expect(LichHoiPhanHoi.khoangCachCho('chat'), const Duration(days: 3));
      expect(LichHoiPhanHoi.khoangCachCho('ho-so'), const Duration(days: 3));
      expect(LichHoiPhanHoi.nenHoi(bayGio: bayGio, khoangCach: sauQuiz,
          lanCuoi: bayGio.subtract(const Duration(hours: 23))), isFalse);
      expect(LichHoiPhanHoi.nenHoi(bayGio: bayGio, khoangCach: sauQuiz,
          lanCuoi: bayGio.subtract(const Duration(days: 1))), isTrue);
      // không truyền khoảng cách thì vẫn là 3 ngày như cũ
      expect(LichHoiPhanHoi.nenHoi(bayGio: bayGio,
          lanCuoi: bayGio.subtract(const Duration(days: 1))), isFalse);
    });

    test('Sau quiz vẫn mỗi phiên một lần, và "Để sau" 3 lần là thôi hẳn', () {
      final sauQuiz = LichHoiPhanHoi.khoangCachCho('quiz');
      final homQua = bayGio.subtract(const Duration(days: 1));
      expect(LichHoiPhanHoi.nenHoi(bayGio: bayGio, lanCuoi: homQua, khoangCach: sauQuiz,
          daHoiPhienNay: true), isFalse);
      expect(LichHoiPhanHoi.nenHoi(bayGio: bayGio, lanCuoi: homQua, khoangCach: sauQuiz,
          boQua: 3), isFalse);
    });

    test('NPS 30 ngày mới hỏi lại', () {
      expect(LichHoiPhanHoi.nenHoiNps(bayGio: bayGio,
          lanCuoi: bayGio.subtract(const Duration(days: 29))), isFalse);
      expect(LichHoiPhanHoi.nenHoiNps(bayGio: bayGio,
          lanCuoi: bayGio.subtract(const Duration(days: 30))), isTrue);
    });
  });

  group('Bảng phản hồi', () {
    Future<Map<String, dynamic>?> moBang(WidgetTester t, {bool hoiNps = true,
        String nguCanh = 'quiz', List<Map<String, dynamic>>? daGui}) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BangPhanHoi(nguCanh: nguCanh, target: 'bach-dang-938', hoiNps: hoiNps,
              gui: (b) async => daGui?.add(b)),
        ),
      ));
      return null;
    }

    FilledButton nutGui(WidgetTester t) =>
        t.widget<FilledButton>(find.byKey(const ValueKey('gui-phan-hoi')));

    Finder chip(String slug) => find.byKey(ValueKey('muon-them-$slug'));

    Future<void> chamChip(WidgetTester t, String slug) async {
      await t.ensureVisible(chip(slug));
      await t.tap(chip(slug));
      await t.pump();
    }

    Future<void> bamGui(WidgetTester t) async {
      await t.ensureVisible(find.byKey(const ValueKey('gui-phan-hoi')));
      await t.tap(find.byKey(const ValueKey('gui-phan-hoi')));
      await t.pumpAndSettle();
    }

    testWidgets('Chưa chọn gì thì chưa gửi được', (t) async {
      await moBang(t);
      expect(nutGui(t).onPressed, isNull);
    });

    testWidgets('Chọn sao + NPS + góp ý rồi gửi: đúng dữ liệu, bỏ khoảng trắng', (t) async {
      final daGui = <Map<String, dynamic>>[];
      await moBang(t, daGui: daGui);
      await t.tap(find.byKey(const ValueKey('sao-4')));
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('nps-9')));
      await t.tap(find.byKey(const ValueKey('nps-9')));
      await t.enterText(find.byKey(const ValueKey('gop-y')), '  Thêm nhiều trận nữa nhé  ');
      await t.pump();
      expect(nutGui(t).onPressed, isNotNull);
      await t.ensureVisible(find.byKey(const ValueKey('gui-phan-hoi')));
      await t.tap(find.byKey(const ValueKey('gui-phan-hoi')));
      await t.pumpAndSettle();
      expect(daGui, hasLength(1));
      final b = daGui.single;
      expect(b['diem'], 4);
      expect(b['nps'], 9);
      expect(b['gop_y'], 'Thêm nhiều trận nữa nhé');
      expect(b['ngu_canh'], 'quiz');
      expect(b['target'], 'bach-dang-938');
    });

    testWidgets('Chỉ chấm sao thì không gửi trường NPS và góp ý rỗng', (t) async {
      final daGui = <Map<String, dynamic>>[];
      await moBang(t, hoiNps: false, daGui: daGui);
      expect(find.byKey(const ValueKey('nps-0')), findsNothing);
      await t.tap(find.byKey(const ValueKey('sao-5')));
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('gui-phan-hoi')));
      await t.tap(find.byKey(const ValueKey('gui-phan-hoi')));
      await t.pumpAndSettle();
      expect(daGui.single.containsKey('nps'), isFalse);
      expect(daGui.single.containsKey('gop_y'), isFalse);
      expect(daGui.single.containsKey('muon_them'), isFalse);
    });

    testWidgets('Câu "muốn thêm trận nào" hiện sau quiz và ở Hồ sơ, ẩn khi đang chat', (t) async {
      await moBang(t);
      expect(find.text('Bạn muốn app có thêm trận/chủ đề nào?'), findsOneWidget);
      expect(find.byType(FilterChip), findsNWidgets(tranMuonThem.length));
      expect(find.text('Điện Biên Phủ (1954)'), findsOneWidget);

      await moBang(t, nguCanh: 'ho-so');
      expect(find.byType(FilterChip), findsNWidgets(tranMuonThem.length));

      await moBang(t, nguCanh: 'chat');
      expect(find.text('Bạn muốn app có thêm trận/chủ đề nào?'), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('Chỉ chọn chip là gửi được; body có muon_them theo thứ tự bấm', (t) async {
      final daGui = <Map<String, dynamic>>[];
      await moBang(t, hoiNps: false, daGui: daGui);
      expect(nutGui(t).onPressed, isNull);
      await chamChip(t, 'dien-bien-phu-1954');
      expect(nutGui(t).onPressed, isNotNull);
      await chamChip(t, 'hai-ba-trung-40');
      await bamGui(t);
      final b = daGui.single;
      expect(b['muon_them'], ['dien-bien-phu-1954', 'hai-ba-trung-40']);
      expect(b.containsKey('diem'), isFalse);
      expect(b['ngu_canh'], 'quiz');
    });

    testWidgets('Bấm lại chip là bỏ chọn; bỏ hết thì lại chưa gửi được', (t) async {
      await moBang(t, hoiNps: false);
      await chamChip(t, 'van-lang-au-lac');
      expect(nutGui(t).onPressed, isNotNull);
      await chamChip(t, 'van-lang-au-lac');
      expect(nutGui(t).onPressed, isNull);
    });

    testWidgets('Chọn tối đa 3 chip; bỏ một chip thì chọn được chip khác', (t) async {
      final daGui = <Map<String, dynamic>>[];
      await moBang(t, hoiNps: false, daGui: daGui);
      for (final s in ['hai-ba-trung-40', 'nhu-nguyet-1077', 'chong-mong-co-1258']) {
        await chamChip(t, s);
      }
      FilterChip chipThu4() => t.widget<FilterChip>(chip('dien-bien-phu-1954'));
      expect(chipThu4().onSelected, isNull, reason: 'đủ 3 thì khoá chip còn lại');
      expect(t.widget<FilterChip>(chip('nhu-nguyet-1077')).onSelected, isNotNull,
          reason: 'chip đã chọn vẫn bỏ được');

      await chamChip(t, 'nhu-nguyet-1077');
      expect(chipThu4().onSelected, isNotNull);
      await chamChip(t, 'dien-bien-phu-1954');
      await bamGui(t);
      expect(daGui.single['muon_them'],
          ['hai-ba-trung-40', 'chong-mong-co-1258', 'dien-bien-phu-1954']);
    });
  });
}
