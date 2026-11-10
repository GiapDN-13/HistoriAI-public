import 'package:flutter/material.dart';

import 'theme.dart';

/// Ảnh đại diện: bộ ảnh có sẵn (mã khớp backend/app/core/anh_dai_dien.py) HOẶC ảnh tự
/// tải lên (mã "tl-…", máy chủ phát ở /api/v1/anh-dai-dien/<mã>).
///
/// Ảnh tải lên hiện công khai (hồ sơ, bảng vàng, phòng thi) — quyết định của nhóm 05/10:
/// người dùng đa số THCS/THPT, đăng ảnh hay không là quyền của các bạn. Máy chủ đã
/// cắt vuông, thu nhỏ và bỏ thông tin GPS trong ảnh (backend/app/services/anh_tai_len.py).
class AnhDaiDien {
  AnhDaiDien._();

  static const _goc = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://historiai.org');

  static bool laAnhTaiLen(String? ma) => ma != null && ma.startsWith('tl-');

  /// Đường dẫn ảnh tải lên từ mã (hoặc từ `avatar_url` máy chủ trả, nếu có).
  static String? url(String? ma, {String? avatarUrl}) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return avatarUrl.startsWith('http') ? avatarUrl : '$_goc$avatarUrl';
    }
    if (!laAnhTaiLen(ma)) return null;
    return '$_goc/api/v1/anh-dai-dien/${ma!.substring(3)}'; // không đuôi .jpg — xem backend anh_tai_len.url
  }

  static const bo = <String, (IconData, Color, String)>{
    'hoc-si': (Icons.menu_book_rounded, Color(0xFF7A2218), 'Học sĩ'),
    'tuong-quan': (Icons.shield_rounded, AppColors.red, 'Tướng quân'),
    'trong-dong': (Icons.brightness_7_rounded, Color(0xFFB8860B), 'Trống đồng'),
    'hoa-sen': (Icons.local_florist_rounded, Color(0xFFC2185B), 'Hoa sen'),
    'chim-lac': (Icons.flutter_dash_rounded, Color(0xFF00796B), 'Chim Lạc'),
    'thuyen-rong': (Icons.sailing_rounded, Color(0xFF1565C0), 'Thuyền rồng'),
    'cay-but': (Icons.edit_rounded, Color(0xFF5D4037), 'Bút lông'),
    'ngoi-sao': (Icons.star_rounded, AppColors.cta, 'Ngôi sao'),
  };

  /// Vòng tròn ảnh đại diện. [ma] null / lạ → ảnh học sĩ mặc định của app.
  static Widget vong(String? ma, {double size = 64, String? avatarUrl}) {
    final u = url(ma, avatarUrl: avatarUrl);
    if (u != null) {
      return Semantics(
        label: 'Ảnh đại diện',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.goldBright, width: 2),
          ),
          child: ClipOval(
            child: Image.network(
              u,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Ảnh bị gỡ / mất mạng → về ảnh mặc định, không hiện ô vỡ
              errorBuilder: (_, __, ___) => vong(null, size: size),
            ),
          ),
        ),
      );
    }
    final a = bo[ma];
    if (a == null) {
      return Image.asset(
        'assets/icons/nav/07_profile_scholar.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      );
    }
    final (icon, mau, ten) = a;
    return Semantics(
      label: 'Ảnh đại diện: $ten',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: mau,
          border: Border.all(color: AppColors.goldBright, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.52),
      ),
    );
  }
}
