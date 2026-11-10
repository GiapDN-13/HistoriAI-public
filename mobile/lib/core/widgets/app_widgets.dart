import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'vietnamese_decorations.dart';

enum AppButtonVariant { primary, secondary, ghost }

/// Nút chuẩn hoá: đỏ son là hành động chính, viền đỏ là hành động phụ.
/// Chiều cao được chặn tối thiểu 48 px để thao tác chạm và bàn phím rõ ràng.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.disabled = false,
    this.fullWidth = false,
    this.height = AppDimensions.inputHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool disabled;
  final bool fullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final effectiveDisabled = disabled || loading || onPressed == null;
    final buttonHeight = height < AppDimensions.minInteractive
        ? AppDimensions.minInteractive
        : height;

    Color textColor;
    Gradient? gradient;
    Color? background;
    Border? border;

    switch (variant) {
      case AppButtonVariant.primary:
        textColor = AppColors.onRed;
        gradient = effectiveDisabled ? null : ctaGradient;
        background = effectiveDisabled ? AppColors.disabledSurface : null;
        break;
      case AppButtonVariant.secondary:
        textColor = effectiveDisabled ? AppColors.inkMuted : AppColors.primary;
        background = Colors.transparent;
        border = Border.all(
          color: effectiveDisabled ? AppColors.border : AppColors.primary,
          width: 1.5,
        );
        break;
      case AppButtonVariant.ghost:
        textColor = effectiveDisabled ? AppColors.inkMuted : AppColors.ink;
        background = Colors.transparent;
        break;
    }

    final labelStyle = AppTypography.labelLarge.copyWith(color: textColor);
    return Semantics(
      button: true,
      enabled: !effectiveDisabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          height: buttonHeight,
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: gradient,
            color: background,
            border: border,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            boxShadow: variant == AppButtonVariant.primary && !effectiveDisabled
                ? appSoftShadow
                : null,
          ),
          child: InkWell(
            onTap: effectiveDisabled ? null : onPressed,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            focusColor: AppColors.primaryFocus,
            hoverColor: AppColors.primary.withValues(alpha: 0.08),
            highlightColor: AppColors.primary.withValues(alpha: 0.14),
            child: Center(
              child: Row(
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading) ...[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ] else if (icon != null) ...[
                    Icon(icon, color: textColor, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hiển thị rõ tiến độ học tập, kể cả khi chưa có dữ liệu từ backend.
class LearningProgressIndicator extends StatelessWidget {
  const LearningProgressIndicator({
    super.key,
    this.progress,
    this.compact = false,
  });

  /// Giá trị trong khoảng 0–1. Null tương đương trạng thái chưa bắt đầu.
  final double? progress;
  final bool compact;

  double get normalizedProgress => (progress ?? 0).clamp(0, 1).toDouble();

  String get statusLabel {
    if (normalizedProgress <= 0) return 'Chưa bắt đầu';
    if (normalizedProgress >= 1) return 'Hoàn thành';
    return 'Đang học';
  }

  @override
  Widget build(BuildContext context) {
    final value = normalizedProgress;
    final percent = (value * 100).round();
    final isComplete = value >= 1;
    final color = isComplete ? AppColors.success : AppColors.statusGold;

    return Semantics(
      label: 'Tiến độ học: $statusLabel, $percent phần trăm',
      value: '$percent%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_outlined,
                  size: 15, color: AppColors.inkSoft),
              const SizedBox(width: AppSpacing.xs),
              Text(
                compact ? statusLabel : 'Tiến độ học',
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                isComplete ? 'Hoàn thành' : '$percent%',
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.small),
            child: LinearProgressIndicator(
              value: value,
              minHeight: compact ? 6 : 8,
              backgroundColor: AppColors.bgAlt,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(statusLabel, style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}

/// Thẻ chuẩn hoá mặt thẻ trắng/kem, bo góc 14, viền border, đổ bóng mềm.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color = AppColors.card,
    this.borderRadius = 14,
    this.border,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final double borderRadius;
  final BoxBorder? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: radius,
        focusColor: AppColors.primaryFocus,
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: border ?? Border.all(color: AppColors.border, width: 1),
        boxShadow: appSoftShadow,
      ),
      child: Material(
        color: color,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}

/// Tiêu đề đề mục kèm tuỳ chọn nút "Xem tất cả" hoặc hành động phụ.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          Semantics(
            button: true,
            label: actionLabel,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.small),
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(AppRadii.small),
                focusColor: AppColors.primaryFocus,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      minHeight: AppDimensions.minIconInteractive),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel!,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      const Icon(Icons.arrow_forward_ios,
                          size: 11, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ô thống kê chỉ số (Cấp, Điểm, Chuỗi ngày) phong cách thẻ ngọc hoàng cung.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor = AppColors.red,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  /// Chạm để xem giải thích con số (vd Điểm/Cấp ở trang chủ).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: appSoftShadow,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trạng thái rỗng chuẩn hoá: biểu tượng văn hoá + câu giải thích cụ thể + nút hành động.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.title = 'Chưa có dữ liệu',
    this.icon = Icons.auto_stories_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgAlt,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Icon(icon, size: 40, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.inkSoft,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Khung xương lúc tải (Loading Skeleton).
/// Có đếm giờ 8s: Nếu Render server ngủ quá 8s sẽ báo "Máy chủ đang khởi động, chờ một chút…".
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    this.cardCount = 3,
    this.cardHeight = 90,
  });

  final int cardCount;
  final double cardHeight;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  Timer? _serverTimer;
  bool _serverSlow = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _serverTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _serverSlow = true);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _serverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final opacity = 0.4 + (_anim.value * 0.4);
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_serverSlow) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Máy chủ đang khởi động, vui lòng chờ một chút…',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              ...List.generate(widget.cardCount, (i) {
                return Container(
                  height: widget.cardHeight,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgAlt.withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// Trạng thái lỗi chuẩn hoá: thông báo phi kỹ thuật + nút thử lại.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: AppColors.red, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Thử lại',
              onPressed: onRetry,
              variant: AppButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget hiển thị ảnh bìa từ thumbnailUrl (khắc phục hoàn toàn lỗi L13).
/// Có placeholder, cache fallback và vector hoa văn Đông Sơn khi không có ảnh.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
    this.heroTag,
    this.semanticLabel,
  });

  final String? url;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final String? heroTag;

  /// Nhãn cho trình đọc màn hình. Cần khi ảnh là banner đã in sẵn tên trận và
  /// thẻ đã ẩn tiêu đề trùng: chữ trong ảnh thì trình đọc không đọc được.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    final path = url?.trim();
    if (path != null && path.isNotEmpty) {
      // Chỉ "assets/..." mới là ảnh đóng gói trong app. Máy chủ có thể trả đường
      // dẫn tương đối như "/thumbnails/x.jpg" (ASSET_BASE_URL rỗng) — coi đó là
      // asset thì ảnh hỏng, còn Image.network trên web tự ghép với tên miền trang.
      if (path.startsWith('assets/')) {
        imageWidget = Image.asset(
          path,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _fallbackWidget(),
        );
      } else {
        imageWidget = Image.network(
          path,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: width,
              height: height,
              color: AppColors.bgAlt,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _fallbackWidget(),
        );
      }
    } else {
      imageWidget = _fallbackWidget();
    }

    if (heroTag != null) {
      imageWidget = Hero(tag: heroTag!, child: imageWidget);
    }

    final cat = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageWidget,
    );
    if (semanticLabel == null) return cat;
    // Không tách nút riêng (container) và không gắn cờ ảnh: nhãn nhập vào nút
    // semantics của thẻ bao ngoài, nên trình đọc màn hình vẫn đọc tên trận ngay
    // đầu thẻ như khi còn tiêu đề.
    return Semantics(label: semanticLabel, child: cat);
  }

  Widget _fallbackWidget() {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: imperialDarkGradient,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Opacity(
            opacity: 0.15,
            child: DongSonBackground(size: 160),
          ),
          Icon(
            Icons.menu_book_rounded,
            color: AppColors.goldBright.withValues(alpha: 0.8),
            size: 32,
          ),
        ],
      ),
    );
  }
}
