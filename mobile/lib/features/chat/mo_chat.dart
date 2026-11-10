import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../data/models.dart';
import 'chat_list_screen.dart';
import 'chat_screen.dart';

/// Vĩ nhân gắn với sự kiện: slug sự kiện → (slug vĩ nhân, tên gọi trên nút).
/// Trước đây nút "Đàm đạo" mở danh sách chung, bắt người học tự đi tìm lại.
const viNhanCuaSuKien = {
  'bach-dang-1288': ('tran-hung-dao', 'Trần Hưng Đạo'),
  'quang-trung-1789': ('quang-trung', 'Quang Trung'),
};

/// Mở thẳng cuộc trò chuyện với vĩ nhân của sự kiện — nếu người học đã mở khoá.
/// Chưa mở khoá / không tải được thì về danh sách (nơi ghi rõ cần cấp mấy).
Future<void> moChatTheoSuKien(BuildContext context, String eventSlug,
    {String? cauMoDau}) {
  final gan = viNhanCuaSuKien[eventSlug];
  return moChatVoiViNhan(context, gan?.$1, cauMoDau: cauMoDau);
}

/// Mở trò chuyện với vĩ nhân [figureSlug]. [cauMoDau] điền sẵn vào ô nhập (chưa
/// gửi — người học tự bấm gửi, để không tốn lượt AI ngoài ý muốn).
Future<void> moChatVoiViNhan(BuildContext context, String? figureSlug,
    {String? cauMoDau}) async {
  final dieuHuong = Navigator.of(context);
  if (figureSlug != null) {
    try {
      final api = ApiClient();
      final ds = (await api.get('/figures') as List)
          .map((j) => Figure.fromJson((j as Map).cast<String, dynamic>()))
          .toList();
      final f = ds.where((x) => x.slug == figureSlug).firstOrNull;
      var cap = 1;
      if (api.isSignedIn) {
        try {
          cap = ((await api.get('/auth/me') as Map)['level'] as num?)?.toInt() ?? 1;
        } catch (_) {}
      }
      if (f != null && f.unlockLevel <= cap) {
        dieuHuong.push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            figureSlug: f.slug,
            figureName: f.name,
            figureTitle: f.title,
            period: f.period,
            cauMoDau: cauMoDau,
          ),
        ));
        return;
      }
    } catch (_) {}
  }
  dieuHuong.push(MaterialPageRoute(builder: (_) => const ChatListScreen()));
}
