import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Thẻ cho người mở web trên iPhone/iPad: chưa có app iOS, nhưng "Thêm vào MH chính"
/// trong Safari cho biểu tượng ngoài màn hình và mở toàn màn hình như app.
///
/// VÌ SAO (góp ý 04/10): "hiện tại iPhone chưa tải app được. Mong app sớm có bản cho
/// iPhone". Trước đây iPhone cũng thấy thẻ "Có bản cài cho Android" — vô dụng.
class TheCaiIphone extends StatelessWidget {
  const TheCaiIphone({super.key, required this.onAn});

  final VoidCallback onAn;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('the-cai-iphone'),
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: .6)),
        ),
        child: Row(children: [
          const Icon(Icons.phone_iphone_rounded, color: AppColors.ink, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
                'Dùng trên iPhone như một app: thêm HistoriAI ra màn hình chính.',
                style: TextStyle(color: AppColors.ink, fontSize: 13.5)),
          ),
          TextButton(
            onPressed: () => showCachThemIphone(context),
            child: const Text('Xem cách'),
          ),
          IconButton(
            tooltip: 'Ẩn',
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkMuted),
            onPressed: onAn,
          ),
        ]),
      );
}

Future<void> showCachThemIphone(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thêm HistoriAI vào màn hình chính',
                  style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              SizedBox(height: 4),
              Text('Bản cài riêng cho iPhone chưa có. Làm 3 bước này là có biểu tượng '
                  'HistoriAI ngoài màn hình, mở lên toàn màn hình như app.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.45)),
              SizedBox(height: 14),
              _Buoc(1, Icons.public_rounded, 'Mở historiai.org bằng Safari',
                  'Nếu đang xem trong Zalo hay Facebook, chạm dấu ⋯ rồi chọn "Mở bằng trình duyệt".'),
              _Buoc(2, Icons.ios_share_rounded, 'Chạm nút Chia sẻ',
                  'Hình vuông có mũi tên chỉ lên, ở thanh dưới (hoặc trên) của Safari.'),
              _Buoc(3, Icons.add_box_outlined, 'Chọn "Thêm vào MH chính"',
                  'Kéo xuống trong bảng chia sẻ nếu chưa thấy, rồi chạm "Thêm".'),
            ],
          ),
        ),
      ),
    );

class _Buoc extends StatelessWidget {
  const _Buoc(this.so, this.icon, this.tieuDe, this.moTa);

  final int so;
  final IconData icon;
  final String tieuDe;
  final String moTa;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.red,
            child: Text('$so',
                style: const TextStyle(
                    color: AppColors.goldBright, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 18, color: AppColors.ink),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(tieuDe,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 14)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(moTa,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.inkSoft, height: 1.4)),
            ]),
          ),
        ]),
      );
}
