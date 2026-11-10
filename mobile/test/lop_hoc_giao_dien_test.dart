import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/core/app_preferences.dart';
import 'package:historiai/features/lop_hoc/giao_dien/san_choi.dart';
import 'package:historiai/features/lop_hoc/lop_hoc_api.dart';
import 'package:historiai/features/lop_hoc/vao_phong_screen.dart';
import 'package:historiai/features/lop_hoc/lam_bai_screen.dart';
import 'package:historiai/features/lop_hoc/truc_tiep/ket_noi_truc_tiep.dart';
import 'package:historiai/features/lop_hoc/truc_tiep/man_chieu_screen.dart';
import 'package:historiai/features/lop_hoc/truc_tiep/thi_truc_tiep_screen.dart';
import 'package:historiai/features/lop_hoc/truc_tiep/widget_truc_tiep.dart';

class _Api extends LopHocApi {
  @override
  Future<Map<String, dynamic>> bangVang(String ma) async => {
        'top': [],
        'cua_toi': {'ten': 'Tôn Nữ Hoàng Phương Thảo Nguyên', 'hang': null},
      };
  @override
  Future<Map<String, dynamic>> layDe(String ma) async => {
        'bai': {'giay_moi_cau': 30},
        'cau': [
          {
            'id': 1,
            'question': 'Ngô Quyền đánh quân Nam Hán năm nào?',
            'options': {
              'A': 'Năm 938',
              'B': 'Năm 981',
              'C': 'Năm 1288',
              'D': 'Năm 1428'
            }
          },
        ],
      };
}

void main() {
  testWidgets('điện thoại 320x568 bấm đủ bốn đáp án mà không cuộn', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: LamBaiScreen(ma: '123456', tieuDe: 'Thử tài', api: _Api())));
    await t.pump();
    expect(find.text('Năm 1428').hitTestable(), findsOneWidget);
    expect(t.getBottomLeft(find.text('Năm 1428')).dy, lessThan(568));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  const ten = 'Tôn Nữ Hoàng Phương Thảo Nguyên';
  for (final rong in [320.0, 412.0, 1280.0]) {
    testWidgets('vào phòng và bài tập không tràn $rong', (t) async {
      t.view.physicalSize = Size(rong, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const MaterialApp(home: VaoPhongScreen()));
      expect(t.takeException(), isNull);
      await t.pumpWidget(MaterialApp(
          home: LamBaiScreen(ma: '123456', tieuDe: ten, api: _Api())));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.text('Năm 1428').hitTestable(), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
    for (final pha in ['cho', 'dang_hoi', 'lo_dap_an', 'ket_thuc']) {
      testWidgets('học sinh/màn chiếu $pha không tràn $rong', (t) async {
        t.view.physicalSize = Size(rong, rong == 1280 ? 720 : 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final kn = KetNoiTrucTiep(ma: '123456')
          ..duong = DuongNoi.websocket
          ..trangThai = {
            'pha': pha,
            'ma': '123456',
            'tieu_de': 'Đấu trường Bạch Đằng',
            'tong_cau': 10,
            'cau_so': 0,
            'giay_moi_cau': 30,
            'so_hoc_sinh': 32,
            'link': 'https://historiai.org/vao/123456',
            'hoc_sinh': [
              {'ten': ten}
            ],
            'cua_toi': {'ten': ten, 'hang': 28},
            'cau': {
              'question': 'Ngô Quyền đánh quân Nam Hán năm nào?',
              'options': {
                'A': ten,
                'B': 'Năm 938',
                'C': 'Năm 981',
                'D': 'Năm 1288'
              }
            },
            'top': [
              for (var i = 1; i <= 5; i++) {'ten': ten, 'hang': i, 'diem': null}
            ],
            'dap_an': pha == 'lo_dap_an' ? 'A' : null,
          };
        await t.pumpWidget(MaterialApp(
            home: ThiTrucTiepScreen(
                ma: '123456', tieuDe: ten, ketNoi: kn, api: _Api())));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        if (pha == 'ket_thuc') expect(find.text('Hạng 28/32'), findsNothing);
        await t.pumpWidget(
            MaterialApp(home: ManChieuScreen(ma: '123456', ketNoi: kn)));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        if (rong == 1280 && (pha == 'dang_hoi' || pha == 'lo_dap_an')) {
          final cau =
              t.widget<Text>(find.text('Ngô Quyền đánh quân Nam Hán năm nào?'));
          expect(cau.style!.fontSize, greaterThanOrEqualTo(40));
        }
        await t.pumpWidget(const SizedBox());
        kn.dispose();
      });
    }
    testWidgets('widget sân chơi không tràn $rong với tên dài và null',
        (t) async {
      t.view.physicalSize = Size(rong, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: Column(children: [
          const LuoiDapAn(options: {'A': ten, 'B': ten, 'C': ten, 'D': ten}),
          const BieuDoPhanBo(phanBo: {}, dapAn: null),
          BangTop(top: const [
            {'ten': ten, 'hang': null, 'diem': null}
          ]),
          BucVinhDanh(bang: const [
            {'ten': ten, 'hang': 1, 'diem': null},
            {'ten': ten, 'hang': 2, 'diem': null},
            {'ten': ten, 'hang': 2, 'diem': null},
          ]),
        ]),
      ))));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      expect(find.text('null'), findsNothing);
      expect(mauDapAn.values.toSet().length, 4);
      expect(hinhDapAn.values.toSet().length, 4);
    });
  }
  for (final heThong in [false, true]) {
    testWidgets(
        'tắt hiệu ứng ${heThong ? 'hệ thống' : 'trong app'} không tạo tween',
        (t) async {
      AppPreferences.emberEffectsEnabled.value = heThong;
      addTearDown(() => AppPreferences.emberEffectsEnabled.value = true);
      await t.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(disableAnimations: heThong),
        child: const NhipSanChoi(child: Text('+960 điểm')),
      )));
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(t.binding.transientCallbackCount, 0);
    });
  }
}
