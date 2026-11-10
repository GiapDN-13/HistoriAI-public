import 'package:flutter/material.dart';

/// Bảng màu "Imperial — Light Mode" của HistoriAI.
/// Mọi màu chức năng phải đi qua token này để giữ ý nghĩa nhất quán:
/// đỏ son cho hành động chính, vàng cho thành tựu/trạng thái, giấy dó cho bề mặt.
class AppColors {
  // BỀ MẶT
  static const bg = Color(0xFFFDF9F4);
  static const bgAlt = Color(0xFFFBF3E6);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFEDE0CF);
  static const divider = Color(0xFFF0E6D8);
  static const disabledSurface = Color(0xFFD8C8B9);

  // ĐỎ SON — hành động chính, điều hướng và thông tin quan trọng.
  static const red = Color(0xFFBA2323);
  static const redDeep = red;
  static const redDark = Color(0xFF7A2218);
  static const redDeepest = Color(0xFF3A140E);
  static const primary = red;
  static const primaryPressed = redDark;
  static const primaryFocus = Color(0x337A2218);

  // VÀNG — XP, cấp độ, chuỗi ngày, huy hiệu và trạng thái thành tựu.
  static const gold = Color(0xFFD4AF37);
  static const goldBright = Color(0xFFFDD141);
  static const goldDark = Color(0xFF8A5B08);
  static const statusGold = goldDark;

  // CAM chỉ là sắc trang trí di sản; không dùng làm CTA.
  static const decorativeOrange = Color(0xFFE67E22);

  // TƯƠNG PHẢN CHỮ
  static const ink = Color(0xFF2B1410);
  static const inkSoft = Color(0xFF684538);
  static const inkMuted = Color(0xFF896F62);
  static const onRed = Color(0xFFFBF3E6);

  // TRẠNG THÁI
  static const success = Color(0xFF1E6A3B);
  static const danger = red;

  // Alias tương thích với các thành phần hiện có.
  static const cta = primary;
  static const ctaLight = primaryPressed;
  static const redPrimary = primary;
  static const goldImperial = gold;
  static const goldLight = goldBright;
  static const paperCream = bg;
  static const paperCreamDark = bgAlt;
  static const textPrimaryLight = ink;
  static const textSecondaryLight = inkSoft;
  static const textPrimaryDark = Colors.white;
  static const textSecondaryDark = onRed;
}

/// Nhịp 4 px dùng chung cho layout mobile.
class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets card = EdgeInsets.all(md);
}

class AppRadii {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
}

class AppDimensions {
  static const double minInteractive = 48;
  static const double minIconInteractive = 44;
  static const double inputHeight = 52;
}

/// Vai trò chữ: serif chỉ dành cho lớp lịch sử/trang trọng; sans-serif cho UI.
class AppTypography {
  static const headingLarge = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: AppColors.ink,
  );

  static const headingMedium = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.ink,
  );

  static const headingSmall = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.ink,
  );

  static const bodyLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.ink,
  );

  static const bodyMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.inkSoft,
  );

  static const bodySmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.inkSoft,
  );

  static const labelLarge = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.onRed,
  );

  static const labelMedium = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.ink,
  );

  static const caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.inkMuted,
  );
}

/// Gradient đỏ son hoàng gia cho CTA chính.
const ctaGradient = LinearGradient(
  colors: [AppColors.primary, AppColors.primaryPressed],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

/// Gradient đỏ son hoàng gia cho Header / Thẻ nổi bật.
const imperialRedGradient = LinearGradient(
  colors: [AppColors.red, AppColors.redDark],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Gradient hoàng gia tối cho Hero thẻ / Banner danh nhân.
const imperialDarkGradient = LinearGradient(
  colors: [AppColors.redDark, AppColors.redDeepest],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Một mức đổ bóng bề mặt dùng chung.
const appSoftShadow = [
  BoxShadow(
    color: Color(0x0F000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];

/// Hoạt hoạ chuyển màn dùng chung cho cả app.
///
/// Mặc định Flutter dùng hoạt hoạ của hệ điều hành, mỗi nơi một kiểu và không
/// mang bản sắc gì. Ở đây màn mới trồi lên rất nhẹ rồi hiện dần — giống trang
/// giấy được lật ra, hợp với giọng của sản phẩm hơn là cú trượt ngang.
///
/// Cố ý giữ ngắn (260ms) và biên độ nhỏ: hoạt hoạ dài thì lần đầu thấy hay,
/// tới lần thứ mười là thấy chậm.
class _LatTrang extends PageTransitionsBuilder {
  const _LatTrang();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final duong = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: duong,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.035), end: Offset.zero)
            .animate(duong),
        child: child,
      ),
    );
  }
}

const _chuyenMan = PageTransitionsTheme(builders: {
  TargetPlatform.android: _LatTrang(),
  TargetPlatform.iOS: _LatTrang(),
  TargetPlatform.windows: _LatTrang(),
  TargetPlatform.macOS: _LatTrang(),
  TargetPlatform.linux: _LatTrang(),
  TargetPlatform.fuchsia: _LatTrang(),
});

ThemeData buildHistoriAITheme() {
  final base = ThemeData.light(useMaterial3: true);
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.medium),
    borderSide: const BorderSide(color: AppColors.border),
  );

  final textTheme = TextTheme(
    displayLarge: AppTypography.headingLarge.copyWith(fontSize: 32),
    headlineMedium: AppTypography.headingMedium,
    titleLarge: AppTypography.headingSmall.copyWith(fontSize: 20),
    titleMedium: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: AppColors.ink,
    ),
    bodyLarge: AppTypography.bodyLarge,
    bodyMedium: AppTypography.bodyMedium,
    labelLarge: AppTypography.labelLarge,
    labelSmall: AppTypography.caption,
  );

  return base.copyWith(
    pageTransitionsTheme: _chuyenMan,

    // textTheme ở trên không đặt headlineSmall — thứ AlertDialog lấy làm chữ tiêu
    // đề — nên mọi hộp thoại trong app mất chữ tiêu đề (thấy trên máy thật 28/09:
    // hộp "Đã có bản mới" chỉ còn phần nội dung). Đặt thẳng ở đây cho mọi hộp thoại.
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.card,
      titleTextStyle: AppTypography.headingSmall.copyWith(fontSize: 20),
      contentTextStyle: AppTypography.bodyMedium.copyWith(color: AppColors.ink),
    ),

    // Thông báo nổi, nhấc hẳn lên trên thanh điều hướng và ô nhập.
    //
    // Mặc định SnackBar dính đáy màn hình, mà mọi màn chính của app đều có
    // thanh điều hướng cao ~72 px hoặc ô nhập chat đè lên đó — nên tám chỗ
    // dùng SnackBar trong app đều hiện ra rồi biến mất SAU LƯNG thanh đó.
    // Người dùng bấm nút, không thấy gì, tưởng nút chết. Đã kiểm: chuỗi thông
    // báo có mặt trong cây widget suốt 2,5 giây mà ảnh chụp không thấy đâu.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      backgroundColor: AppColors.redDeepest,
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        color: Color(0xFFFBF3E6),
        fontSize: 13.5,
        height: 1.45,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      elevation: 8,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.goldDark,
      surface: AppColors.card,
      error: AppColors.danger,
      onPrimary: AppColors.onRed,
      onSurface: AppColors.ink,
    ),
    focusColor: AppColors.primaryFocus,
    splashColor: AppColors.primary.withValues(alpha: 0.12),
    highlightColor: AppColors.primary.withValues(alpha: 0.08),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.red,
      foregroundColor: AppColors.goldBright,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'PlayfairDisplay',
        color: AppColors.goldBright,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      constraints: const BoxConstraints(minHeight: AppDimensions.inputHeight),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      labelStyle: AppTypography.bodyMedium,
      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.inkMuted),
      errorStyle: AppTypography.caption.copyWith(color: AppColors.danger),
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: outline.copyWith(
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: outline.copyWith(
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
    ),
    textTheme: textTheme,
  );
}

/// CTA compatibility widget for existing callers. New UI should prefer AppButton.
class CtaButton extends StatelessWidget {
  const CtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = !loading && onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          height: AppDimensions.inputHeight,
          decoration: BoxDecoration(
            gradient: enabled ? ctaGradient : null,
            color: enabled ? null : AppColors.disabledSurface,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            boxShadow: enabled ? appSoftShadow : null,
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            focusColor: AppColors.primaryFocus,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.onRed,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelLarge,
                          ),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Icon(icon, color: AppColors.onRed, size: 20),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
