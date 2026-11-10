import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/features/chat/giong_doc.dart';

class _PhatGia implements TrinhPhat {
  final daPhat = <String>[];
  final _cho = <Completer<void>>[];
  bool daDung = false;

  @override
  Future<void> phat(String url) {
    daPhat.add(url);
    final c = Completer<void>();
    _cho.add(c);
    return c.future;
  }

  void xongCau() => _cho.removeAt(0).complete();

  @override
  Future<void> dung() async {
    daDung = true;
    for (final c in _cho) {
      if (!c.isCompleted) c.complete();
    }
    _cho.clear();
  }

  @override
  Future<void> huy() => dung();
}

Future<void> _nhip() => Future<void>.delayed(Duration.zero);

void main() {
  group('Tách câu khi chữ đang stream', () {
    test('Nhả câu ngay khi có dấu kết câu, giữ phần dở dang', () {
      final t = TachCau();
      expect(t.them('Năm 1288, quân ta đóng cọc gỗ dưới sông. Khi nước'), [
        'Năm 1288, quân ta đóng cọc gỗ dưới sông.',
      ]);
      expect(t.them(' triều rút, thuyền giặc mắc cạn! Rồi'), ['Khi nước triều rút, thuyền giặc mắc cạn!']);
      expect(t.ket(), 'Rồi');
    });

    test('Không cắt số có dấu chấm ngăn cách hàng nghìn', () {
      expect(TachCau.tachHet('Quân Nguyên có hơn 300.000 người tràn xuống phía nam.'),
          ['Quân Nguyên có hơn 300.000 người tràn xuống phía nam.']);
    });

    test('Câu quá ngắn được gộp vào câu sau cho khỏi đọc rời rạc', () {
      expect(TachCau.tachHet('Ồ. Hay lắm. Con hỏi đúng chỗ ta tâm đắc nhất đấy.'),
          ['Ồ. Hay lắm. Con hỏi đúng chỗ ta tâm đắc nhất đấy.']);
    });

    test('Xuống dòng cũng là ranh giới câu', () {
      expect(TachCau.tachHet('Thứ nhất là lòng dân đồng sức\nThứ hai là địa thế hiểm yếu'),
          ['Thứ nhất là lòng dân đồng sức', 'Thứ hai là địa thế hiểm yếu']);
    });
  });

  group('Hàng đợi đọc', () {
    test('Xin giọng cho mọi câu NGAY lúc thêm, nhưng phát lần lượt đúng thứ tự', () async {
      final daXin = <String>[];
      final phat = _PhatGia();
      final h = HangDoiGiong(
          xin: (c) async {
            daXin.add(c);
            return 'url:$c';
          },
          trinhPhat: phat);
      h
        ..them('câu một')
        ..them('câu hai')
        ..them('câu ba');
      expect(daXin, ['câu một', 'câu hai', 'câu ba'],
          reason: 'câu sau phải được tạo trong lúc câu trước đang phát');
      await _nhip();
      expect(phat.daPhat, ['url:câu một']);
      phat.xongCau();
      await _nhip();
      await _nhip();
      expect(phat.daPhat, ['url:câu một', 'url:câu hai']);
      phat.xongCau();
      await _nhip();
      await _nhip();
      phat.xongCau();
      await _nhip();
      await _nhip();
      expect(phat.daPhat.length, 3);
      expect(h.dangNoi.value, isFalse);
      expect(h.ban, isFalse);
    });

    test('Dừng thì bỏ hết các câu còn lại', () async {
      final phat = _PhatGia();
      final h = HangDoiGiong(xin: (c) async => 'url:$c', trinhPhat: phat);
      h
        ..them('một')
        ..them('hai');
      await _nhip();
      await h.dung();
      await _nhip();
      expect(phat.daPhat, ['url:một']);
      expect(h.dangNoi.value, isFalse);
      expect(h.ban, isFalse);
    });

    test('Máy chủ không tạo được câu nào thì đọc câu đó bằng giọng dự phòng', () async {
      final duPhong = <String>[];
      final phat = _PhatGia();
      final h = HangDoiGiong(
        xin: (c) async => c == 'hỏng' ? null : 'url:$c',
        trinhPhat: phat,
        khiLoi: (c) async => duPhong.add(c),
      );
      h
        ..them('hỏng')
        ..them('lành');
      await _nhip();
      await _nhip();
      expect(duPhong, ['hỏng']);
      expect(phat.daPhat, ['url:lành'], reason: 'câu lỗi không được chặn các câu sau');
    });

    test('Lỗi mạng khi xin giọng không làm vỡ hàng đợi', () async {
      final duPhong = <String>[];
      final h = HangDoiGiong(
        xin: (c) => Future<String?>.error(Exception('mất mạng')),
        trinhPhat: _PhatGia(),
        khiLoi: (c) async => duPhong.add(c),
      );
      h.them('một');
      await _nhip();
      await _nhip();
      expect(duPhong, ['một']);
    });
  });
}
