import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Ngoài web: chưa có nơi lưu tệp chung cho mọi máy Android — chép vào bộ nhớ tạm
/// để giáo viên dán vào Excel / Google Sheets. Trả về false = "đã chép, chưa tải".
Future<bool> taiTep(String ten, String noiDung) async {
  await Clipboard.setData(ClipboardData(text: noiDung));
  return false;
}

/// Bản cài: chưa có chỗ lưu ảnh chung (cần thêm quyền / gói chia sẻ) — màn gọi sẽ
/// nhắc học sinh chụp màn hình. Trả về false.
Future<bool> taiAnh(String ten, Uint8List png) async => false;

/// Bản cài: chưa lưu tệp được — màn gọi sẽ chép bảng điểm dạng chữ thay thế. Trả về false.
Future<bool> taiExcel(String ten, List<int> bytes) async => false;
