import 'package:flutter/material.dart';
import '../lib/core/theme.dart';
import '../lib/features/lop_hoc/bang_vang.dart';
import '../lib/features/lop_hoc/giao_vien_screen.dart';
import '../lib/features/lop_hoc/lam_bai_screen.dart';
import '../lib/features/lop_hoc/lop_hoc_api.dart';
import '../lib/features/lop_hoc/phong_screen.dart';
import '../lib/features/lop_hoc/vao_phong_screen.dart';
import '../lib/features/lop_hoc/mo_rong/nhap_nhieu_cau_screen.dart';
import '../lib/features/lop_hoc/truc_tiep/ket_noi_truc_tiep.dart';
import '../lib/features/lop_hoc/truc_tiep/man_chieu_screen.dart';
import '../lib/features/lop_hoc/truc_tiep/thi_truc_tiep_screen.dart';

/// Entry riêng để QA: bản phát hành vẫn dùng lib/main.dart và API thật.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final man = Uri.base.queryParameters['man'] ?? 'vao';
  final api = ApiXemLop(man);
  final pha = man.contains('cho')
      ? 'cho'
      : man.contains('phan-bo') || man == 'dung' || man == 'sai'
          ? 'lo_dap_an'
          : man.contains('chung-cuoc') || man == 'ket-qua'
              ? 'ket_thuc'
              : 'dang_hoi';
  final kn = KetNoiTrucTiep(ma: '123456', api: api)
    ..duong = DuongNoi.websocket
    ..hanLuc = DateTime.now().add(const Duration(seconds: 30))
    ..trangThai = {
      'pha': pha,
      'ma': '123456',
      'tieu_de': 'Thử tài Bạch Đằng',
      'cau_so': 0,
      'tong_cau': 10,
      'giay_moi_cau': 30,
      'so_hoc_sinh': 32,
      'so_da_tra_loi': 24,
      'link': 'https://historiai.org/vao/123456',
      'cau': cauXem,
      'dap_an': pha == 'lo_dap_an' ? 'A' : null,
      'giai_thich': pha == 'lo_dap_an'
          ? 'Ngô Quyền đánh tan quân Nam Hán trên sông Bạch Đằng năm 938.'
          : null,
      'phan_bo': {'A': 24, 'B': 3, 'C': 4, 'D': 1},
      'hoc_sinh': topXem,
      'top': topXem.take(5).toList(),
      'bang_xep_hang': topXem,
      'cua_toi': {
        'ten': tenXem,
        'hang': 1,
        'da_chon': man == 'sai' ? 'C' : 'A',
        'dung': man != 'sai',
        'diem_cau': 920,
        'tong_diem': 8720,
        'so_dung': 9
      },
    };
  final Widget trang = switch (man) {
    'vao' => VaoPhongScreen(api: api),
    'vao-ten' => VaoPhongScreen(ma: '123456', api: api),
    'bai' => LamBaiScreen(ma: '123456', tieuDe: 'Thử tài Bạch Đằng', api: api),
    'bai-ket-qua' =>
      LamBaiScreen(ma: '123456', tieuDe: 'Thử tài Bạch Đằng', api: api),
    'giay-45' => GiayVinhDanhScreen(du: bangXem),
    'giay-916' => GiayVinhDanhScreen(du: bangXem),
    'giao-vien' => GiaoVienScreen(api: api),
    'soan-de' => SoanDeScreen(api: api),
    'dan-ai' => NhapNhieuCauScreen(api: api),
    'phong' => PhongScreen(ma: '123456', api: api),
    _ => man.startsWith('chieu')
        ? ManChieuScreen(ma: '123456', ketNoi: kn)
        : ThiTrucTiepScreen(
            ma: '123456', tieuDe: 'Thử tài Bạch Đằng', api: api, ketNoi: kn),
  };
  runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildHistoriAITheme(),
      home: trang));
}

const tenXem = 'Tôn Nữ Hoàng Phương Thảo Nguyên';
const cauXem = {
  'id': 1,
  'question': 'Ai chỉ huy chiến thắng Bạch Đằng năm 938?',
  'options': {
    'A': 'Ngô Quyền',
    'B': 'Lê Hoàn',
    'C': 'Trần Hưng Đạo',
    'D': 'Lý Thường Kiệt'
  },
};
final topXem = [
  for (final (i, ten) in [
    tenXem,
    'Nguyễn Minh Anh',
    'Trần Bảo Ngọc',
    'Lê Đức Minh',
    'Phạm Hải An',
    'Vũ Khánh Linh',
    'Hoàng Gia Bảo',
    'Đỗ Thanh Hà',
    'Bùi Minh Châu',
    'Lý Quỳnh Anh'
  ].indexed)
    {
      'ten': ten,
      'hang': i + 1,
      'so_dung': 9 - i ~/ 2,
      'diem': 8720 - i * 620,
      'la_toi': i == 0,
      'avatar': i == 0
          ? 'chim-lac'
          : i == 1
              ? 'hoa-sen'
              : null,
      'avatar_url': null
    },
];
final bangXem = <String, dynamic>{
  'tieu_de': 'Thử tài Bạch Đằng',
  'giao_vien': 'Cô Nguyễn Thị Lan',
  'ngay': '2026-10-05T03:00:00Z',
  'tong_hoc_sinh': 32,
  'tong_cau': 10,
  'top': topXem,
  'cua_toi': {...topXem.first, 'lop': '7A2', 'diem_10': 9, 'vuot_pct': 97},
};

class ApiXemLop extends LopHocApi {
  ApiXemLop(this.man);
  final String man;
  @override
  bool get daDangNhap => false;
  @override
  Future<Map<String, dynamic>> bangVang(String ma) async => bangXem;
  @override
  Future<Map<String, dynamic>> xemPhong(String ma) async => {
        'ma': ma,
        'tieu_de': 'Thử tài Bạch Đằng',
        'so_cau': 10,
        'giay_moi_cau': 30,
        'giao_vien': 'Cô Lan',
        'dang_mo': true,
      };
  @override
  Future<Map<String, dynamic>> layDe(String ma) async => {
        'bai': {'da_nop': man == 'bai-ket-qua', 'giay_moi_cau': 30},
        'cau': [cauXem],
      };
  @override
  Future<bool> traLoi(String ma, int cau, String chon) async => chon == 'A';
  @override
  Future<Map<String, dynamic>> nop(String ma) async => {
        'so_dung': 9,
        'tong': 10,
        'diem_10': 9.0,
        'cau': [
          {
            ...cauXem,
            'chon': 'A',
            'correct_option': 'A',
            'dung': true,
            'explanation':
                'Ngô Quyền tận dụng thủy triều và bãi cọc trên sông Bạch Đằng.'
          }
        ],
      };
  @override
  Future<List<Map<String, dynamic>>> dsDe() async => [
        {
          'id': 1,
          'tieu_de': 'Thử tài Bạch Đằng',
          'so_cau': 10,
          'giay_moi_cau': 30
        },
        {
          'id': 2,
          'tieu_de': 'Dấu ấn nhà Trần',
          'so_cau': 15,
          'giay_moi_cau': 45
        },
      ];
  @override
  Future<List<Map<String, dynamic>>> dsPhong() async => [
        {
          'ma': '123456',
          'tieu_de': 'Thử tài Bạch Đằng · 7A2',
          'so_nop': 24,
          'so_bai': 32,
          'che_do': 'truc_tiep',
          'dang_mo': true
        },
      ];
  @override
  Future<List<Map<String, dynamic>>> khoCau() async => [
        {
          'event_slug': 'rieng',
          'event_title': 'Câu tôi tự soạn',
          'rieng': true,
          'cau': [
            {...cauXem, 'id': -1, 'correct_option': 'A'}
          ]
        },
        {
          'event_slug': 'bach-dang',
          'event_title': 'Chiến thắng Bạch Đằng năm 938',
          'cau': [
            {...cauXem, 'correct_option': 'A'}
          ]
        },
      ];
  @override
  Future<List<Map<String, dynamic>>> dsLop() async => [
        {'id': 1, 'ten': '7A2', 'si_so': 32}
      ];
  @override
  Future<Map<String, dynamic>> bang(String ma) async => {
        'phong': {
          'ma': ma,
          'tieu_de': 'Thử tài Bạch Đằng',
          'link': 'https://historiai.org/vao/$ma',
          'so_nop': 24,
          'so_bai': 32,
          'so_cau': 10,
          'dang_mo': true
        },
        'hoc_sinh': [
          for (final (i, h) in topXem.indexed)
            {
              ...h,
              'lop': '7A2',
              'da_nop': i < 3,
              'tong': 10,
              'da_lam': i < 3 ? 10 : 6
            }
        ],
        'tung_cau': [],
      };
}
