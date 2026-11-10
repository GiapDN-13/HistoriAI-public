import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/data/models.dart';
import 'package:historiai/features/ar_museum/dat_vao_phong.dart';

/// Luật ẩn/hiện nút "Đặt vào phòng" và hình dạng đường dẫn Scene Viewer.
///
/// Đây là phần đáng chặn hồi quy nhất của tính năng AR: nút hiện ra nhầm chỗ
/// thì app **hứa sai kích thước cổ vật** — hại hơn là không có nút. Mà cả ba
/// luật ẩn đều chỉ lộ ra trên máy Android thật, nơi không ai chạy thử thường
/// xuyên.
Artifact _coVat({
  String slug = 'trong-dong-dong-son',
  String name = 'Trống đồng Đông Sơn',
  String? glb = 'https://historiai.anhzap.shop/models/trong-dong-dong-son.glb',
  String? met = '0.793',
}) =>
    Artifact.fromJson({
      'slug': slug,
      'name': name,
      'model_glb_url': glb,
      'real_scale_meters': met,
    });

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    DatVaoPhong.gan(kiemTra: (_) async => true, mo: (_) async => true);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    DatVaoPhong.datLaiChoTest();
  });

  group('Artifact.realScaleMeters', () {
    test('đọc được số mét từ chuỗi backend trả về', () {
      expect(_coVat().realScaleMeters, 0.793);
      expect(_coVat().coKichThuocThat, isTrue);
    });

    test('ô trống nghĩa là chưa tra được nguồn, không phải 0', () {
      expect(_coVat(met: '').realScaleMeters, isNull);
      expect(_coVat(met: null).realScaleMeters, isNull);
      expect(_coVat(met: '').coKichThuocThat, isFalse);
    });

    test('chuỗi rác trong seed không làm sập màn Bảo tàng', () {
      expect(_coVat(met: 'khoảng 0,6m').realScaleMeters, isNull);
      expect(_coVat(met: '-1').realScaleMeters, isNull);
      expect(_coVat(met: '0').realScaleMeters, isNull);
    });
  });

  group('Đường dẫn Scene Viewer', () {
    test('có đủ resizable=false — thứ khoá kích thước thật', () {
      final u = DatVaoPhong.diaChi(_coVat())!;
      expect(u.origin, 'https://arvr.google.com');
      expect(u.path, '/scene-viewer/1.0');
      expect(u.queryParameters['resizable'], 'false');
      expect(u.queryParameters['mode'], 'ar_preferred');
      expect(u.queryParameters['title'], 'Trống đồng Đông Sơn');
      expect(
        u.queryParameters['file'],
        'https://historiai.anhzap.shop/models/trong-dong-dong-son.glb',
      );
    });

    test('tên cổ vật có dấu tiếng Việt được mã hoá đúng trong URL', () {
      final u = DatVaoPhong.diaChi(_coVat())!;
      // Đọc lại từ chuỗi đã dựng, không đọc từ đối tượng Uri trong bộ nhớ —
      // để bắt được lỗi mã hoá thật sự gửi đi.
      expect(Uri.parse(u.toString()).queryParameters['title'],
          'Trống đồng Đông Sơn');
    });
  });

  group('Bốn luật ẩn nút', () {
    test('chưa tra được kích thước thật thì ẩn — không hứa cỡ mình không biết',
        () async {
      final a = _coVat(met: '');
      expect(DatVaoPhong.diaChi(a), isNull);
      expect(await DatVaoPhong.dungDuoc(a), isFalse);
    });

    test('không có tệp .glb thì ẩn', () async {
      expect(DatVaoPhong.diaChi(_coVat(glb: '')), isNull);
      expect(await DatVaoPhong.dungDuoc(_coVat(glb: null)), isFalse);
    });

    test('tệp không nằm trên HTTPS tuyệt đối thì ẩn — Scene Viewer tự tải tệp '
        'bằng tiến trình của nó, localhost của máy dev là vô nghĩa', () async {
      expect(DatVaoPhong.diaChi(_coVat(glb: 'models/x.glb')), isNull);
      expect(DatVaoPhong.diaChi(_coVat(glb: 'http://10.0.2.2:8000/x.glb')),
          isNull);
    });

    test('hiện vật lớn hơn một căn phòng thì ẩn — thuyền chiến dài 9,5 m đặt '
        'giữa nhà chỉ là mảng gỗ xuyên tường, không dạy được gì', () async {
      final thuyen = _coVat(met: '9.5');
      expect(DatVaoPhong.diaChi(thuyen), isNull);
      expect(await DatVaoPhong.dungDuoc(thuyen), isFalse);
    });

    test('cọc Bạch Đằng 2,7 m vẫn hiện — cao hơn đầu người chính là điều '
        'đáng thấy', () {
      expect(DatVaoPhong.diaChi(_coVat(met: '2.7')), isNotNull);
    });

    test('đúng bằng giới hạn thì vẫn hiện, chỉ quá mới ẩn', () {
      const gh = DatVaoPhong.gioiHanTrongPhongMet;
      expect(DatVaoPhong.diaChi(_coVat(met: '$gh')), isNotNull);
      expect(DatVaoPhong.diaChi(_coVat(met: '${gh + 0.01}')), isNull);
    });

    test('máy không mở được Scene Viewer thì ẩn, không hiện nút chết', () async {
      DatVaoPhong.gan(kiemTra: (_) async => false);
      expect(await DatVaoPhong.dungDuoc(_coVat()), isFalse);
    });

    test('plugin ném lỗi lúc dò thì coi như không có, không làm sập phiếu',
        () async {
      DatVaoPhong.gan(kiemTra: (_) async => throw Exception('kênh hỏng'));
      expect(await DatVaoPhong.dungDuoc(_coVat()), isFalse);
    });

    test('đủ điều kiện thì mới hiện', () async {
      expect(await DatVaoPhong.dungDuoc(_coVat()), isTrue);
    });
  });

  group('Nền tảng', () {
    test('iPhone ẩn — Quick Look cần tệp .usdz mà nhóm chưa dựng', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(DatVaoPhong.hoTroNenTang, isFalse);
      expect(await DatVaoPhong.dungDuoc(_coVat()), isFalse);
    });

    test('chỉ Android mới có Scene Viewer', () {
      expect(DatVaoPhong.hoTroNenTang, isTrue);
    });
  });

  group('Câu mô tả kích thước', () {
    test('dưới 1 mét thì nói bằng xăng-ti-mét cho dễ hình dung', () {
      expect(DatVaoPhong.moTaKichThuoc(_coVat(met: '0.793')),
          '79 cm ngoài đời');
      expect(DatVaoPhong.moTaKichThuoc(_coVat(met: '0.465')),
          '47 cm ngoài đời');
    });

    test('từ 1 mét trở lên dùng mét, dấu phẩy thập phân kiểu Việt', () {
      expect(DatVaoPhong.moTaKichThuoc(_coVat(met: '2.7')), '2,7 m ngoài đời');
      expect(DatVaoPhong.moTaKichThuoc(_coVat(met: '9.5')), '9,5 m ngoài đời');
      expect(DatVaoPhong.moTaKichThuoc(_coVat(met: '3')), '3 m ngoài đời');
    });

    test('chưa biết kích thước thì không có câu nào', () {
      expect(DatVaoPhong.moTaKichThuoc(_coVat(met: '')), isNull);
    });
  });
}
