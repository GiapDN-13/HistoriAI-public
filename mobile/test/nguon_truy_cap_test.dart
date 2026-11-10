import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/core/nguon_truy_cap.dart';

NguonTruyCap _doc(String url, [String truoc = '']) =>
    NguonTruyCap.tuDiaChi(Uri.parse(url), truoc);

void main() {
  test('Đọc đủ nhãn utm trên link', () {
    final n = _doc('https://historiai.org/?utm_source=facebook&utm_medium=social'
        '&utm_campaign=ra-mat&utm_content=bai-1');
    expect(n.nguon, 'facebook');
    expect(n.kenh, 'social');
    expect(n.chienDich, 'ra-mat');
    expect(n.noiDung, 'bai-1');
  });

  test('Link ngắn cho mã QR: ?ref=fb nghĩa là facebook', () {
    expect(_doc('https://historiai.org/?ref=fb').nguon, 'facebook');
    expect(_doc('https://historiai.org/?ref=qr').nguon, 'qr');
    expect(_doc('https://historiai.org/?ref=lop-10a1').nguon, 'lop-10a1',
        reason: 'mã lạ thì giữ nguyên để nhóm tự đặt tên kênh');
  });

  test('Nhãn utm thắng trang trước', () {
    expect(_doc('https://historiai.org/?utm_source=zalo', 'https://l.facebook.com/').nguon, 'zalo');
  });

  test('Không nhãn thì lấy từ trang đã dẫn tới', () {
    expect(_doc('https://historiai.org/', 'https://l.facebook.com/l.php?u=x').nguon, 'facebook');
    expect(_doc('https://historiai.org/', 'https://zalo.me/g/abc').nguon, 'zalo');
    expect(_doc('https://historiai.org/', 'https://forms.gle/xyz').nguon, 'google-form');
    expect(_doc('https://historiai.org/', 'https://www.google.com/').nguon, 'google');
    expect(_doc('https://historiai.org/', 'https://www.baomoi.com/bai').nguon, 'baomoicom');
  });

  test('Chuyển trang nội bộ hay tên miền cũ chuyển hướng không tính là nguồn', () {
    expect(_doc('https://historiai.org/', 'https://historiai.org/tai-app/').nguon,
        NguonTruyCap.trucTiep);
    expect(_doc('https://historiai.org/', 'https://historiai.anhzap.shop/').nguon,
        NguonTruyCap.trucTiep);
  });

  test('Không nhãn, không trang trước → trực tiếp', () {
    expect(_doc('https://historiai.org/').nguon, NguonTruyCap.trucTiep);
  });

  test('Nhãn gõ bừa được làm sạch để gộp khớp', () {
    expect(NguonTruyCap.lamSach('  Facebook Page!! '), 'facebook-page');
    expect(NguonTruyCap.lamSach(''), isNull);
    expect(NguonTruyCap.lamSach('a' * 60)!.length, 40);
  });
}
