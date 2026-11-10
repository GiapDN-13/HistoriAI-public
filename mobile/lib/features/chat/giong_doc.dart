import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Tách chữ đang stream thành từng câu hoàn chỉnh để đọc sớm.
///
/// Đợi LLM viết xong cả đoạn rồi mới đọc là để người dùng ngồi chờ lâu gấp
/// đôi. Nhả từng câu ngay khi câu đó có dấu kết thúc thì câu đầu được đọc
/// trong lúc các câu sau vẫn đang viết.
class TachCau {
  final _dem = StringBuffer();

  /// Câu dưới ngần này từ thì gộp vào câu sau — đọc từng mẩu "Ồ." rời rạc nghe
  /// như máy vấp, và mỗi mẩu lại tốn một lượt tạo giọng.
  static const tuToiThieu = 4;

  /// Dấu kết câu theo sau là khoảng trắng, hoặc xuống dòng. Dấu chấm giữa hai
  /// chữ số ("1.000") không có khoảng trắng phía sau nên không bị cắt.
  static final _ranhGioi = RegExp(r'[.!?…]+["”’)»]*\s+|\n+');

  List<String> them(String manh) {
    _dem.write(manh);
    final chu = _dem.toString();
    final ra = <String>[];
    var dau = 0;
    var gom = '';
    for (final m in _ranhGioi.allMatches(chu)) {
      final cau = (gom + chu.substring(dau, m.end)).trim();
      dau = m.end;
      if (cau.isEmpty) continue;
      if (_soTu(cau) < tuToiThieu) {
        gom = '$cau ';
        continue;
      }
      ra.add(cau);
      gom = '';
    }
    _dem
      ..clear()
      ..write(gom + chu.substring(dau));
    return ra;
  }

  /// Phần còn lại khi luồng chữ kết thúc (câu cuối thường không có dấu chấm).
  String? ket() {
    final con = _dem.toString().trim();
    _dem.clear();
    return con.isEmpty ? null : con;
  }

  static List<String> tachHet(String chu) {
    final t = TachCau();
    return [...t.them(chu), if (t.ket() case final c?) c];
  }

  static int _soTu(String s) =>
      s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}

/// Trình phát một đường dẫn âm thanh; `phat` xong khi phát hết. Tách ra để test.
abstract class TrinhPhat {
  Future<void> phat(String url);
  Future<void> dung();
  Future<void> huy();
}

/// LỖI "ĐỔI GIỌNG SAU DẤU CHẤM" (sửa 28/09)
///   Đầu mỗi câu, `_phat` đóng Completer của câu trước. Câu trước phát xong thì
///   Completer đó ĐÃ đóng rồi → gọi `complete()` lần nữa ném "Future already
///   completed" → hàng đợi tưởng câu mới hỏng → đọc bằng giọng trình duyệt, và cứ
///   thế tới hết câu trả lời. Chỉ câu đầu đúng giọng vì lúc đó chưa có Completer
///   nào. Bắt được bằng cách nghe lén thẻ <audio> trên historiai.org: máy chủ tạo đủ
///   10 câu bằng VieNeu mà trình duyệt chỉ tải câu 1. Test hàng đợi dùng trình phát giả
///   nên không bắt được — kiểm bằng trình duyệt thật khi sửa lớp này.
class TrinhPhatAudioplayers implements TrinhPhat {
  AudioPlayer _p = _moi();
  Completer<void>? _dang;
  StreamSubscription<void>? _xong;

  static AudioPlayer _moi() => AudioPlayer();

  @override
  Future<void> phat(String url) async {
    try {
      await _phat(url);
    } catch (_) {
      // Lớp an toàn thứ hai: trình phát kẹt trạng thái lỗi thì dựng cái mới và
      // thử lại MỘT lần trước khi để màn chat chuyển sang giọng trình duyệt.
      await _xong?.cancel();
      final cu = _p;
      _p = _moi();
      unawaited(cu.dispose().catchError((_) {}));
      await _phat(url);
    }
  }

  Future<void> _phat(String url) async {
    final truoc = _dang;
    if (truoc != null && !truoc.isCompleted) truoc.complete();
    final c = _dang = Completer<void>();
    await _xong?.cancel();
    _xong = _p.onPlayerComplete.listen((_) {
      if (!c.isCompleted) c.complete();
    });
    try {
      await _p.play(UrlSource(url));
    } catch (e) {
      if (!c.isCompleted) c.completeError(e);
    }
    return c.future;
  }

  @override
  Future<void> dung() async {
    await _p.stop().catchError((_) {});
    if (_dang != null && !_dang!.isCompleted) _dang!.complete();
  }

  @override
  Future<void> huy() async {
    await dung();
    await _xong?.cancel();
    await _p.dispose();
  }
}

/// Hàng đợi đọc từng câu.
///
/// `them(cau)` gọi `xin` NGAY để máy chủ bắt đầu tạo giọng câu đó, rồi xếp vào
/// hàng. Câu sau được tạo trong lúc câu trước đang phát, nên giữa các câu gần
/// như không có quãng chờ. Máy chủ còn trả được từng mảnh trong lúc tạo, nên
/// câu đầu tiên nghe thấy sau khoảng nửa giây.
class HangDoiGiong {
  HangDoiGiong({required this.xin, required this.trinhPhat, this.khiLoi});

  /// Xin đường dẫn âm thanh cho một câu. null = máy chủ không tạo được.
  final Future<String?> Function(String cau) xin;
  final TrinhPhat trinhPhat;

  /// Câu không có tiếng (máy chủ hỏng) — màn chat đọc bằng giọng trình duyệt.
  final Future<void> Function(String cau)? khiLoi;

  final dangNoi = ValueNotifier<bool>(false);
  final dangTai = ValueNotifier<bool>(false);

  final _hang = <(String, Future<String?>)>[];
  int _luot = 0;        // tăng mỗi lần dừng: vòng phát cũ tự thoát khi thấy lượt đổi
  bool _dangChay = false;

  bool get ban => _dangChay || _hang.isNotEmpty;

  void them(String cau) {
    if (cau.trim().isEmpty) return;
    _hang.add((cau, xin(cau).catchError((_) => null)));
    if (!_dangChay) unawaited(_chay());
  }

  /// Xin trước (máy chủ tạo sẵn và lưu đệm) mà không phát.
  void lamNong(String cau) {
    if (cau.trim().isNotEmpty) unawaited(xin(cau).catchError((_) => null));
  }

  Future<void> _chay() async {
    _dangChay = true;
    final luot = _luot;
    while (_hang.isNotEmpty && luot == _luot) {
      final (cau, url) = _hang.removeAt(0);
      dangTai.value = true;
      final u = await url;
      if (luot != _luot) break;
      dangTai.value = false;
      if (u == null) {
        await khiLoi?.call(cau);
        continue;
      }
      dangNoi.value = true;
      try {
        await trinhPhat.phat(u);
      } catch (_) {
        if (luot == _luot) await khiLoi?.call(cau);
      }
    }
    if (luot == _luot) {
      dangNoi.value = false;
      dangTai.value = false;
      _dangChay = false;
    }
  }

  Future<void> dung() async {
    _luot++;
    _hang.clear();
    _dangChay = false;
    await trinhPhat.dung();
    dangNoi.value = false;
    dangTai.value = false;
  }

  Future<void> huy() async {
    _luot++;
    _hang.clear();
    await trinhPhat.huy();
    dangNoi.dispose();
    dangTai.dispose();
  }
}
