import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:historiai/core/analytics.dart';
import 'package:historiai/core/app_preferences.dart';
import 'package:historiai/core/widgets/chon_lop.dart';
import 'package:historiai/data/models.dart';
import 'package:historiai/features/timeline/event_detail_screen.dart';

/// Dữ liệu từ đường ống làm giàu: tóm tắt theo cấp, lớp, chủ đề chương trình, nguồn.
Map<String, dynamic> _json({bool lamGiau = true}) => {
      'slug': 'bach-dang-938',
      'title': 'Trận Bạch Đằng 938',
      'year': 938,
      'summary': 'Bản nhóm viết tay.',
      'features': 'timeline,quiz',
      if (lamGiau) ...{
        'summary_thcs': 'Bản cho THCS.',
        'summary_thpt': 'Bản cho THPT.',
        'grades': '6,11',
        'curriculum': [
          {'ma': 'THCS-6-04', 'cap': 'THCS', 'lop': 6, 'chu_de': 'VIỆT NAM TỪ KHOẢNG THẾ KỈ VII TCN'},
          {'ma': 'THPT-11-04', 'cap': 'THPT', 'lop': 11, 'chu_de': 'Chiến tranh bảo vệ Tổ quốc'},
        ],
        'sources': [
          {'ten': 'Wikipedia tiếng Việt — Trận Bạch Đằng (938)', 'url': 'https://vi.wikipedia.org/wiki/X',
           'giay_phep': 'CC BY-SA 4.0'},
        ],
      },
    };

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Analytics.instance.datLaiChoTest();
    await AppPreferences.setLopHoc(null);
  });

  test('Đọc đủ trường làm giàu từ API', () {
    final e = HistoricalEvent.fromJson(_json());
    expect(e.grades, [6, 11]);
    expect(e.curriculum.map((c) => c.lop), [6, 11]);
    expect(e.sources.single.giayPhep, 'CC BY-SA 4.0');
  });

  test('Sự kiện chưa qua đường ống vẫn đọc được, không vỡ', () {
    final e = HistoricalEvent.fromJson(_json(lamGiau: false));
    expect(e.grades, isEmpty);
    expect(e.sources, isEmpty);
    expect(e.tomTatCho(11), 'Bản nhóm viết tay.');
  });

  test('Tóm tắt chọn theo lớp; chưa biết lớp thì giữ bản nhóm viết', () {
    final e = HistoricalEvent.fromJson(_json());
    expect(e.tomTatCho(null), 'Bản nhóm viết tay.');
    expect(e.tomTatCho(7), 'Bản cho THCS.');
    expect(e.tomTatCho(10), 'Bản cho THPT.');
  });

  testWidgets('Màn chi tiết hiện lớp, nguồn, và đổi tóm tắt ngay khi đổi lớp', (t) async {
    await t.pumpWidget(MaterialApp(home: EventDetailScreen(event: HistoricalEvent.fromJson(_json()))));
    await t.pump();
    expect(find.text('Bản nhóm viết tay.'), findsOneWidget);

    await t.scrollUntilVisible(find.text('NGUỒN TƯ LIỆU'), 200);
    expect(find.text('HỌC TRÊN LỚP'), findsOneWidget);
    expect(find.text('Lớp 6'), findsOneWidget);
    expect(find.text('Lớp 11'), findsOneWidget);
    // Chủ đề viết HOA trong văn bản chương trình được hạ về dạng dễ đọc
    expect(find.textContaining('VIỆT NAM TỪ KHOẢNG'), findsNothing);

    await AppPreferences.setLopHoc(11);
    await t.pump();
    expect(find.text('Bản cho THPT.'), findsOneWidget,
        reason: 'đổi lớp ở Hồ sơ thì tóm tắt phải đổi theo ngay');
  });

  testWidgets('Sự kiện chưa làm giàu không hiện khung lớp và nguồn rỗng', (t) async {
    await t.pumpWidget(MaterialApp(
        home: EventDetailScreen(event: HistoricalEvent.fromJson(_json(lamGiau: false)))));
    await t.pump();
    expect(find.text('HỌC TRÊN LỚP'), findsNothing);
    expect(find.text('NGUỒN TƯ LIỆU'), findsNothing);
  });

  testWidgets('Chọn lớp: bấm để chọn, bấm lại để bỏ — lớp không bắt buộc', (t) async {
    int? lop;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (_, setState) => ChonLop(lop: lop, onChanged: (l) => setState(() => lop = l)),
        ),
      ),
    ));
    await t.tap(find.byKey(const ValueKey('chon-lop-8')));
    await t.pump();
    expect(lop, 8);
    await t.tap(find.byKey(const ValueKey('chon-lop-8')));
    await t.pump();
    expect(lop, isNull);
  });
}
