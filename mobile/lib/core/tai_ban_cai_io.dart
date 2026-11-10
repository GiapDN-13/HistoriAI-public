import 'dart:io';

import 'package:http/http.dart' as http;

/// Tải bản cài về [thuMuc] (thư mục cache/ban_moi của app), báo tiến độ 0..1.
/// Trả đường dẫn tệp .apk đã tải đủ. Ném lỗi nếu hỏng giữa chừng hoặc thiếu byte.
Future<String> taiBanCai({
  required String url,
  required String thuMuc,
  required int build,
  int? tongByte,
  required void Function(double) tienDo,
  required bool Function() daHuy,
}) async {
  final d = Directory(thuMuc);
  final dich = File('$thuMuc/historiai-$build.apk');
  // Đã tải đủ bản này rồi (vd người dùng đi bật quyền cài rồi quay lại) → khỏi tải lại.
  if (await dich.exists() && (tongByte == null || await dich.length() == tongByte)) {
    tienDo(1);
    return dich.path;
  }
  // Dọn bản tải cũ: mỗi bản cài ~35 MB, không để dồn trong máy người dùng.
  if (await d.exists()) {
    await for (final f in d.list()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  } else {
    await d.create(recursive: true);
  }
  final dangGhi = File('${dich.path}.part');
  final khach = http.Client();
  try {
    final res = await khach.send(http.Request('GET', Uri.parse(url)));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
    final tong = res.contentLength ?? tongByte ?? 0;
    final ghi = dangGhi.openWrite();
    var da = 0;
    try {
      await for (final khoi in res.stream) {
        if (daHuy()) throw const HttpException('đã huỷ');
        ghi.add(khoi);
        da += khoi.length;
        if (tong > 0) tienDo(da / tong);
      }
    } finally {
      await ghi.close();
    }
    if (tongByte != null && da != tongByte) {
      throw HttpException('tải thiếu: $da/$tongByte byte');
    }
    await dangGhi.rename(dich.path);
    return dich.path;
  } catch (_) {
    try {
      await dangGhi.delete();
    } catch (_) {}
    rethrow;
  } finally {
    khach.close();
  }
}
