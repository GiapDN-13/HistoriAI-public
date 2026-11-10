import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/features/lop_hoc/giao_vien_screen.dart';
import 'package:historiai/features/lop_hoc/giao_dien/mo_phong.dart';
import 'package:historiai/features/lop_hoc/lop_hoc_api.dart';
import 'package:historiai/features/lop_hoc/mo_rong/nhap_nhieu_cau_screen.dart';

class _Api extends LopHocApi {
  List<int>? daChon;
  final luotNhap = <bool>[];
  @override
  Future<List<Map<String, dynamic>>> dsDe() async => [];
  @override
  Future<List<Map<String, dynamic>>> dsPhong() async => [];
  @override
  Future<List<Map<String, dynamic>>> khoCau() async => [
        {
          'event_slug': 'bach-dang',
          'event_title': 'Chiến thắng Bạch Đằng',
          'cau': [
            for (var i = 0; i < 61; i++)
              {
                'id': i == 0 ? -1 : i,
                'question': 'Câu hỏi $i?',
                'options': {'A': 'Ngô Quyền'},
                'correct_option': 'A'
              },
          ]
        },
      ];
  @override
  Future<Map<String, dynamic>> taoDe(
      String tieuDe, List<int> cauIds, int giayMoiCau) async {
    daChon = cauIds;
    return {};
  }

  @override
  Future<Map<String, dynamic>> nhapNhieuCau(String vanBan,
      {required bool luu}) async {
    luotNhap.add(luu);
    return {
      'hop_le': 1,
      'loi': 0,
      'da_luu': 1,
      'cau': [
        {
          'so': 1,
          'question': 'Ai chỉ huy Bạch Đằng?',
          'option_a': 'Ngô Quyền',
          'correct_option': 'A'
        },
      ]
    };
  }
}

void main() {
  testWidgets('trang giáo viên có dán AI và chỉ dẫn khi chưa có đề', (t) async {
    await t.pumpWidget(MaterialApp(home: GiaoVienScreen(api: _Api())));
    await t.pumpAndSettle();
    expect(find.text('Dán nhiều câu từ AI'), findsOneWidget);
    await t.scrollUntilVisible(find.textContaining('Chưa có đề —'), 200);
    expect(find.textContaining('Chưa có đề —'), findsOneWidget);
  });
  testWidgets('chọn hết tối đa 60 câu, giữ id âm khi gửi', (t) async {
    final api = _Api();
    await t.pumpWidget(MaterialApp(home: SoanDeScreen(api: api)));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Thử tài Bạch Đằng');
    await t.scrollUntilVisible(find.text('Chọn hết'), 200,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Chọn hết'));
    await t.pump();
    expect(find.text('Lưu đề (60 câu)'), findsOneWidget);
    await t.tap(find.text('Lưu đề (60 câu)'));
    await t.pumpAndSettle();
    expect(api.daChon!.length, 60);
    expect(api.daChon!.first, -1);
  });
  testWidgets('dán AI chỉ lưu sau khi xem trước, sửa chữ phải xem lại',
      (t) async {
    final api = _Api();
    await t.pumpWidget(MaterialApp(home: NhapNhieuCauScreen(api: api)));
    await t.scrollUntilVisible(find.byType(TextField), 200,
        scrollable: find.byType(Scrollable).first);
    await t.enterText(find.byType(TextField), 'Câu 1: Ai chỉ huy Bạch Đằng?');
    await t.tap(find.text('Bước 3: Xem trước'));
    await t.pumpAndSettle();
    expect(api.luotNhap, [false]);
    expect(find.text('Lưu 1 câu vào "Câu tôi tự soạn"'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Câu 1: Đề đã sửa');
    await t.pump();
    expect(find.text('Lưu 1 câu vào "Câu tôi tự soạn"'), findsNothing);
    await t.tap(find.text('Bước 3: Xem trước'));
    await t.pumpAndSettle();
    await t.tap(find.text('Lưu 1 câu vào "Câu tôi tự soạn"'));
    await t.pumpAndSettle();
    expect(api.luotNhap, [false, false, true]);
  });
  testWidgets('mở trận trực tiếp là mặc định, không cần đổi hạn', (t) async {
    (String, int?, int?)? chon;
    await t.pumpWidget(MaterialApp(
        home: Builder(
            builder: (ctx) => TextButton(
                onPressed: () async => chon =
                    await showDialog<(String, int?, int?)>(
                        context: ctx,
                        builder: (_) =>
                            const MoPhong(tieuDe: 'Thử tài', lop: [])),
                child: const Text('chọn')))));
    await t.tap(find.text('chọn'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Mở phòng'));
    await t.pumpAndSettle();
    expect(chon, ('truc_tiep', null, null));
  });
}
