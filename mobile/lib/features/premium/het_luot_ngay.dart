import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'premium_chung.dart';
import 'premium_screen.dart';

/// Máy chủ trả 402 `het_luot_ngay` khi hết lượt hỏi AI trong ngày.
///
/// Trả về số câu miễn phí của ngày (`gioi_han`) để hiện "hỏi hết N câu"; null
/// nếu lỗi này KHÔNG phải hết lượt (để bên gọi báo lỗi chung như cũ).
int? soCauKhiHetLuot(Object loi) {
  if (loi is! ApiException || loi.statusCode != 402) return null;
  if (loi.ma != 'het_luot_ngay') return null;
  return (loi.chiTiet?['gioi_han'] as num?)?.toInt() ?? 0;
}

/// Hiện thẻ "hết câu miễn phí" dưới dạng bottom sheet.
///
/// Dùng sheet thay cho dòng lỗi trong khung chat: hết lượt không phải sự cố mà
/// là chỗ duy nhất app được phép nói về Premium, nên phải thấy rõ và có lối ra
/// (xem Premium / để mai) — không để người học tưởng app hỏng.
Future<void> hienHetLuotNgay(BuildContext context, {required int soCau}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: TheHetLuotNgay(
          soCau: soCau,
          daDangNhap: ApiClient().isSignedIn,
          onXemPremium: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PremiumScreen()),
            );
          },
          onDeMai: () => Navigator.of(ctx).pop(),
        ),
      ),
    ),
  );
}

/// Nội dung thẻ hết lượt. Tách riêng khỏi sheet để test không cần dựng cả
/// `ChatScreen` (nó kéo theo TTS, WebView…).
class TheHetLuotNgay extends StatelessWidget {
  const TheHetLuotNgay({
    super.key,
    required this.soCau,
    required this.onXemPremium,
    required this.onDeMai,
    this.daDangNhap = true,
  });

  final int soCau;
  final VoidCallback onXemPremium;
  final VoidCallback onDeMai;

  /// Khách chưa đăng nhập: gợi ý thêm một đường nữa là có tài khoản.
  final bool daDangNhap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.hourglass_bottom_rounded,
              color: AppColors.gold, size: 36),
          const SizedBox(height: 10),
          Text(
            soCau > 0
                ? 'Hôm nay bạn đã hỏi hết $soCau câu miễn phí'
                : 'Hôm nay bạn đã hỏi hết số câu miễn phí',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: AppColors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            daDangNhap
                ? 'Ngày mai lượt hỏi sẽ được làm mới. Muốn hỏi tiếp ngay, bạn có '
                    'thể dùng Premium.'
                : 'Ngày mai lượt hỏi sẽ được làm mới. Đăng nhập tài khoản để có '
                    'thêm lượt mỗi ngày, hoặc dùng Premium.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: AppColors.inkSoft,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const _TieuDeNho('PREMIUM CÓ GÌ'),
          const SizedBox(height: 8),
          const DanhSachQuyenLoi(gon: true),
          const SizedBox(height: 18),
          NutPremium(nhan: 'Xem Premium', onTap: onXemPremium),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onDeMai,
            child: const Text(
              'Để mai',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TieuDeNho extends StatelessWidget {
  const _TieuDeNho(this.chu);
  final String chu;

  @override
  Widget build(BuildContext context) => Text(
        chu,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          color: AppColors.primary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      );
}
