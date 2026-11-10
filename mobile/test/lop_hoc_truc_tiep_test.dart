import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/features/lop_hoc/lop_hoc_api.dart';
import 'package:historiai/features/lop_hoc/truc_tiep/dieu_khien_screen.dart';
import 'package:historiai/features/lop_hoc/truc_tiep/ket_noi_truc_tiep.dart';
import 'package:historiai/features/lop_hoc/truc_tiep/thi_truc_tiep_screen.dart';

/// Kênh WebSocket giả: test đẩy gói "từ máy chủ" xuống và đọc gói app gửi lên.
class KenhGia implements KenhTrucTiep {
  final _ctl = StreamController<dynamic>();
  final daGui = <Map<String, dynamic>>[];
  int? _maDong;

  @override
  Future<void> get sanSang async {}
  @override
  Stream<dynamic> get nhan => _ctl.stream;
  @override
  void gui(String tin) => daGui.add((jsonDecode(tin) as Map).cast<String, dynamic>());
  @override
  int? get maDong => _maDong;
  @override
  Future<void> dong() => _ctl.close();

  void day(Map<String, dynamic> t) => _ctl.add(jsonEncode(t));
  Future<void> mayChuDong([int? ma]) {
    _maDong = ma;
    return _ctl.close();
  }
}

Map<String, dynamic> trangThai(String pha, {int phien = 1, int? cauSo, Map<String, dynamic>? them, Map<String, dynamic>? toi}) => {
      'loai': 'trang_thai',
      'ma': '123456',
      'tieu_de': 'Đấu trường Bạch Đằng',
      'pha': pha,
      'cau_so': cauSo,
      'tong_cau': 2,
      'giay_moi_cau': 20,
      'so_hoc_sinh': 2,
      'phien': phien,
      if (pha == 'dang_hoi' || pha == 'lo_dap_an')
        'cau': {
          'id': 7,
          'question': 'Ngô Quyền đánh quân Nam Hán năm nào?',
          'options': {'A': 'Năm 938', 'B': 'Năm 981', 'C': 'Năm 1288', 'D': 'Năm 1428'},
        },
      if (pha == 'dang_hoi') 'con_lai_ms': 15000,
      'vai': 'hs',
      'cua_toi': {'ten': 'Nguyễn An', 'da_chon': null, ...?toi},
      ...?them,
    };

void main() {
  http.Response j(Object o) =>
      http.Response.bytes(utf8.encode(jsonEncode(o)), 200, headers: {'content-type': 'application/json'});

  LopHocApi apiGia({Object? trangThaiRest}) => LopHocApi(ApiClient(
        baseUrl: 'https://historiai.org',
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('/truc-tiep') && trangThaiRest != null) return j(trangThaiRest);
          return http.Response('{"detail":"không có"}', 404);
        }),
      )..setToken('ma-dang-nhap'));

  test('địa chỉ WebSocket lấy từ API_BASE_URL, https → wss', () {
    expect(apiGia().wsUri('123456').toString(), 'wss://historiai.org/api/v1/ws/phong/123456');
  });

  testWidgets('nối: gửi mã đăng nhập ở gói đầu, nhận trạng thái, bỏ gói cũ tới muộn', (t) async {
    final kenh = KenhGia();
    final kn = KetNoiTrucTiep(ma: '123456', api: apiGia(), moKenh: (_) => kenh)..batDau();
    await t.pump();
    expect(kenh.daGui.first, {'loai': 'xac_thuc', 'token': 'ma-dang-nhap'});

    kenh.day(trangThai('dang_hoi', phien: 5, cauSo: 0));
    await t.pump();
    expect(kn.duong, DuongNoi.websocket);
    expect(kn.pha, 'dang_hoi');
    expect(kn.hanLuc, isNotNull);

    kenh.day(trangThai('cho', phien: 3)); // gói cũ tới muộn
    await t.pump();
    expect(kn.pha, 'dang_hoi', reason: 'không được nháy về sảnh');

    await kn.traLoi(0, 'A');
    expect(kenh.daGui.last, {'loai': 'tra_loi', 'cau_so': 0, 'chon': 'A'});
    expect(kn.daChon(0), 'A');
    await kn.traLoi(0, 'B');
    expect(kenh.daGui.where((g) => g['loai'] == 'tra_loi').length, 1, reason: 'mỗi câu một lần');

    kenh.day({'loai': 'loi', 'thong_bao': 'Hết giờ mất rồi.'});
    await t.pump();
    expect(kn.daChon(0), isNull, reason: 'máy chủ không nhận → bỏ lựa chọn tạm');
    expect(kn.thongBao, 'Hết giờ mất rồi.');
    kn.dispose();
  });

  testWidgets('WebSocket rớt → hỏi định kỳ qua REST, rồi tự nối lại', (t) async {
    final cacKenh = <KenhGia>[];
    final kn = KetNoiTrucTiep(
      ma: '123456',
      api: apiGia(trangThaiRest: trangThai('lo_dap_an', phien: 9, cauSo: 0)),
      moKenh: (_) => (cacKenh..add(KenhGia())).last,
    )..batDau();
    await t.pump();
    cacKenh.first.day(trangThai('dang_hoi', phien: 5, cauSo: 0));
    await t.pump();

    await cacKenh.first.mayChuDong(1006);
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(kn.duong, DuongNoi.hoiDinhKy);
    expect(kn.pha, 'lo_dap_an', reason: 'trạng thái lấy qua đường dự phòng');

    await t.pump(const Duration(seconds: 1)); // hẹn nối lại sau 1 giây
    expect(cacKenh.length, 2);
    cacKenh.last.day(trangThai('dang_hoi', phien: 12, cauSo: 1));
    await t.pump();
    expect(kn.duong, DuongNoi.websocket);
    expect(kn.cauSo, 1);
    kn.dispose();
  });

  testWidgets('máy chủ đóng với mã 4403 → báo lỗi, không nối lại', (t) async {
    var soLan = 0;
    final kenh = KenhGia();
    final kn = KetNoiTrucTiep(ma: '123456', api: apiGia(), moKenh: (_) {
      soLan++;
      return kenh;
    })..batDau();
    await t.pump();
    kenh.day({'loai': 'loi', 'thong_bao': 'Em chưa vào phòng này.'});
    await kenh.mayChuDong(4403);
    await t.pump();
    await t.pump(const Duration(seconds: 20));
    expect(kn.loiChet, 'Em chưa vào phòng này.');
    expect(soLan, 1);
    kn.dispose();
  });

  testWidgets('học sinh: sảnh → chọn đáp án → đúng + TOP 5 → hạng chung cuộc', (t) async {
    final kenh = KenhGia();
    final api = apiGia();
    final kn = KetNoiTrucTiep(ma: '123456', api: api, moKenh: (_) => kenh)..batDau();
    await t.pump();
    await t.pumpWidget(MaterialApp(home: ThiTrucTiepScreen(ma: '123456', tieuDe: 'Đấu trường', ketNoi: kn, api: api)));

    kenh.day(trangThai('cho'));
    await t.pump();
    expect(find.text('Chào Nguyễn An!'), findsOneWidget);

    kenh.day(trangThai('dang_hoi', phien: 2, cauSo: 0));
    await t.pump();
    expect(find.text('Ngô Quyền đánh quân Nam Hán năm nào?'), findsOneWidget);
    expect(find.text('Câu 1/2'), findsOneWidget);
    await t.tap(find.text('Năm 938'));
    await t.pump();
    expect(kenh.daGui.last, {'loai': 'tra_loi', 'cau_so': 0, 'chon': 'A'});
    expect(find.textContaining('Em đã chọn A'), findsOneWidget);

    kenh.day(trangThai('lo_dap_an', phien: 3, cauSo: 0, them: {
      'dap_an': 'A',
      'phan_bo': {'A': 1, 'B': 1, 'C': 0, 'D': 0},
      'top': [
        {'ten': 'Nguyễn An', 'diem': 960, 'hang': 1, 'so_dung': 1},
        {'ten': 'Trần Bình', 'diem': 0, 'hang': 2, 'so_dung': 0},
      ],
    }, toi: {'da_chon': 'A', 'dung': true, 'diem_cau': 960, 'tong_diem': 960, 'hang': 1}));
    await t.pump();
    expect(find.text('Chính xác!'), findsOneWidget);
    expect(find.text('+960 điểm'), findsOneWidget);
    expect(find.text('Tổng 960 điểm · hạng 1/2'), findsOneWidget);
    expect(find.text('Trần Bình'), findsOneWidget);

    kenh.day(trangThai('ket_thuc', phien: 4, cauSo: 1, them: {
      'top': [
        {'ten': 'Nguyễn An', 'diem': 960, 'hang': 1, 'so_dung': 1},
        {'ten': 'Trần Bình', 'diem': 0, 'hang': 2, 'so_dung': 0},
      ],
    }, toi: {'tong_diem': 960, 'hang': 1, 'so_dung': 1}));
    await t.pump();
    expect(find.text('Hạng 1/2'), findsOneWidget);
    expect(find.text('960 điểm · đúng 1/2 câu'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    kn.dispose();
  });

  testWidgets('giáo viên: sảnh có tên em, bấm Bắt đầu gửi lệnh kèm câu đang thấy', (t) async {
    final kenh = KenhGia();
    final kn = KetNoiTrucTiep(ma: '123456', api: apiGia(), moKenh: (_) => kenh)..batDau();
    await t.pump();
    await t.pumpWidget(MaterialApp(home: DieuKhienTrucTiepScreen(ma: '123456', ketNoi: kn)));
    kenh.day({
      ...trangThai('cho'),
      'vai': 'gv',
      'link': 'https://historiai.org/vao/123456',
      'hoc_sinh': [
        {'user_id': 1, 'ten': 'Nguyễn An'},
        {'user_id': 2, 'ten': 'Trần Bình'},
      ],
      'dang_noi': [1],
    });
    await t.pump();
    expect(find.text('2 em đã vào sảnh'), findsOneWidget);
    expect(find.text('Trần Bình'), findsOneWidget);

    await t.tap(find.text('Bắt đầu'));
    await t.pump();
    expect(kenh.daGui.last, {'loai': 'dieu_khien', 'lenh': 'bat_dau', 'tu_cau': null});

    await t.pumpWidget(const SizedBox());
    kn.dispose();
  });
}
