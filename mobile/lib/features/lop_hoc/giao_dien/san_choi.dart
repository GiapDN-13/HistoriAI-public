import 'package:flutter/material.dart';

import '../../../core/anh_dai_dien.dart';
import '../../../core/app_preferences.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/vietnamese_decorations.dart';

/// Giới hạn theme trong lớp học vì CTA ở các phần khác vẫn dùng đỏ son.
class KhungLopHoc extends StatelessWidget {
  const KhungLopHoc(
      {super.key,
      this.appBar,
      required this.body,
      this.bottomNavigationBar,
      this.floatingActionButton,
      this.backgroundColor,
      this.manChieu = false});
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar, floatingActionButton;
  final Color? backgroundColor;
  final bool manChieu;

  @override
  Widget build(BuildContext context) {
    final nen = Theme.of(context);
    final chu = nen.textTheme.copyWith(
      displayLarge: AppTypography.headingLarge,
      headlineMedium: AppTypography.headingMedium,
      headlineSmall: AppTypography.headingSmall,
      titleLarge: AppTypography.headingSmall,
      titleMedium: AppTypography.labelMedium,
      titleSmall: AppTypography.labelMedium,
      bodyLarge: AppTypography.bodyLarge,
      bodyMedium: AppTypography.bodyMedium,
      bodySmall: AppTypography.bodySmall,
      labelLarge: AppTypography.labelMedium,
      labelMedium: AppTypography.labelMedium,
      labelSmall: AppTypography.bodySmall,
    );
    return Theme(
      data: nen.copyWith(
        textTheme: chu,
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
          backgroundColor: AppColors.decorativeOrange,
          foregroundColor: AppColors.ink,
          minimumSize: const Size(56, 56),
          textStyle: AppTypography.labelMedium,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        )),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppColors.decorativeOrange,
            foregroundColor: AppColors.ink),
      ),
      child: Scaffold(
        backgroundColor: backgroundColor ?? AppColors.bg,
        appBar: appBar,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        body:
            manChieu ? body : Center(child: SizedBox(width: 1040, child: body)),
      ),
    );
  }
}

class LoiChaoSanChoi extends StatelessWidget {
  const LoiChaoSanChoi({super.key, required this.tieuDe, required this.moTa});
  final String tieuDe, moTa;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            gradient: imperialDarkGradient,
            borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const ChimLacMotif(size: 72),
          const SizedBox(height: 14),
          Text(tieuDe,
              style:
                  AppTypography.headingLarge.copyWith(color: AppColors.onRed)),
          const SizedBox(height: 8),
          Text(moTa,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.onRed)),
          const SizedBox(height: 14),
          const DongSonWaveDivider(height: 10),
        ]),
      );
}

class AnhBan extends StatelessWidget {
  const AnhBan({super.key, required this.ten, this.url, this.ma, this.co = 40});
  final String ten;
  final String? url, ma;
  final double co;
  @override
  Widget build(BuildContext context) {
    final mau = [
      AppColors.redDark,
      AppColors.success,
      AppColors.goldDark,
      const Color(0xFF315C79)
    ][ten.runes.fold<int>(0, (a, b) => a + b) % 4];
    final chu = ten.trim().isEmpty
        ? '?'
        : String.fromCharCode(ten.trim().runes.first).toUpperCase();
    final duPhong = ColoredBox(
        color: mau,
        child: Center(
            child: Text(chu,
                style: AppTypography.labelMedium
                    .copyWith(color: Colors.white, fontSize: co * .4))));
    return Semantics(
      label: 'Ảnh đại diện của $ten',
      image: true,
      child: SizedBox(
          width: co,
          height: co,
          child: ClipOval(
              child: url != null && url!.isNotEmpty
                  // Máy chủ trả đường dẫn TƯƠNG ĐỐI — ghép địa chỉ máy chủ, không thì bản
                  // Android (không chung tên miền như web) luôn rơi về chữ cái đầu.
                  ? Image.network(AnhDaiDien.url(ma, avatarUrl: url)!,
                      fit: BoxFit.cover,
                      errorBuilder: (nguCanh, loi, vet) => duPhong)
                  : AnhDaiDien.bo.containsKey(ma)
                      ? AnhDaiDien.vong(ma, size: co)
                      : duPhong)),
    );
  }
}

/// Không dựng tween khi hiệu ứng tắt: đồng hồ nghiệp vụ vẫn tiếp tục đếm.
class NhipSanChoi extends StatelessWidget {
  const NhipSanChoi({super.key, required this.child, this.diemBay = false});
  final Widget child;
  final bool diemBay;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: AppPreferences.emberEffectsEnabled,
        builder: (context, bat, _) {
          if (!bat || MediaQuery.disableAnimationsOf(context)) return child;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, giaTri, con) => Transform.translate(
                offset: Offset(0, (1 - giaTri) * (diemBay ? 24 : 10)),
                child: Opacity(opacity: giaTri, child: con)),
            child: child,
          );
        },
      );
}

/// Câu dài cuộn trong vùng riêng để bốn nút luôn ở dưới ngón tay.
class KhungCauHoi extends StatelessWidget {
  const KhungCauHoi(
      {super.key,
      required this.dau,
      required this.cauHoi,
      required this.dapAn,
      this.phanHoi});
  final Widget dau;
  final Widget Function(double caoO) dapAn;
  final String cauHoi;
  final Widget? phanHoi;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, rang) {
        final noiDung = Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              dau,
              const SizedBox(height: 12),
              Expanded(
                  child: Center(
                      child: SingleChildScrollView(
                          child: Text(cauHoi,
                              textAlign: TextAlign.center,
                              style: AppTypography.headingMedium)))),
              const SizedBox(height: 12),
              dapAn((rang.maxHeight / 8).clamp(64.0, 100.0)),
              SizedBox(
                  height: 52,
                  child: Center(
                      child: phanHoi ??
                          const Text('Chọn một ô đáp án',
                              style: AppTypography.bodySmall))),
            ]));
        return SafeArea(child: noiDung);
      });
}

bool nenKhoeHang(Map toi, num? tong) {
  final hang = toi['hang'] as num?;
  final vuot = toi['vuot_pct'] as num?;
  return hang != null &&
      (hang <= 3 ||
          (vuot != null && vuot >= 50) ||
          (tong != null && hang <= tong / 2));
}

String chuDuLieu(Object? giaTri) => giaTri == null ? '—' : '$giaTri';
