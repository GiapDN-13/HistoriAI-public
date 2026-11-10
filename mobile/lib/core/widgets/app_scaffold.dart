import 'package:flutter/material.dart';

import '../theme.dart';

/// Bottom navigation 6 tab theo SPEC_UI_UX.md Mục 5.1.
/// Các biểu tượng 3D lần lượt đại diện cho Trang chủ, Dòng thời gian,
/// Đấu trường, Vĩ nhân và Bảo tàng.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    this.onTap,
  });

  final int current;
  final ValueChanged<int>? onTap;

  static const _labels = [
    'Trang chủ',
    'Thời gian',
    'Đấu trường',
    'Vĩ nhân',
    'Bảo tàng',
    'Tài khoản',
  ];

  static const _semanticsLabels = [
    'Trang chủ',
    'Dòng thời gian',
    'Đấu trường',
    'Vĩ nhân',
    'Bảo tàng',
    'Tài khoản',
  ];

  static const _iconAssets = [
    'assets/figures3d/item_transparent/'
        'isolate_only_the_3d_ancient_vietnamese_imperial_pagoda_shrine_building_temple.png',
    'assets/figures3d/item_transparent/'
        'isolate_only_the_scroll_timeline_icon_from_top_left_an_ancient_vietnamese.png',
    'assets/figures3d/item_transparent/'
        'isolate_only_the_golden_arena_quiz_trophy_icon_from_bottom_right_golden.png',
    'assets/figures3d/item_transparent/'
        'isolate_the_warrior_helmet_and_speech_bubble_icon_on_a_completely_clean_solid.png',
    'assets/figures3d/item_transparent/'
        'isolate_only_the_ancient_bronze_drum_icon_from_top_right_an_ancient_dong_son.png',
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 78 + bottomPadding,
      decoration: const BoxDecoration(
        color: AppColors.red,
        border: Border(
          top: BorderSide(
            color: Color(0x66D4AF37),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 3,
        bottom: bottomPadding > 0 ? bottomPadding : 5,
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_labels.length, (i) {
            final active = i == current;

            return Expanded(
              child: Semantics(
                button: true,
                selected: active,
                label: _semanticsLabels[i],
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('bottom-nav-item-$i'),
                    onTap: () => onTap?.call(i),
                    focusColor: AppColors.goldBright.withValues(alpha: 0.22),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: double.infinity,
                      height: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.redDark.withValues(alpha: 0.45)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 3,
                          horizontal: 2,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: active ? 20 : 0,
                              height: 2,
                              decoration: BoxDecoration(
                                color: AppColors.goldBright,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (i < _iconAssets.length)
                              Image.asset(
                                _iconAssets[i],
                                width: 32,
                                height: 32,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                excludeFromSemantics: true,
                              )
                            else
                              Image.asset(
                                'assets/icons/nav/07_profile_scholar.png',
                                width: 32,
                                height: 32,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                excludeFromSemantics: true,
                              ),
                            const SizedBox(height: 3),
                            // Một dòng, tự thu nhỏ khi hẹp. Cho xuống 2 dòng
                            // thì "Đấu trường" gãy đôi ở khổ 360 px và cả cột
                            // cao hơn ô chứa — dấu tiếng Việt đẩy thêm vài px.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _labels[i],
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: active
                                      ? AppColors.goldBright
                                      : AppColors.onRed,
                                  fontSize: 12,
                                  height: 1.0,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Pill filter (chip lọc) chuẩn hoá theo bảng màu ấm của HistoriAI (xoá hẳn navy).
/// Không active: nền bgAlt, viền border, chữ inkSoft.
/// Active: nền goldBright, chữ ink.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.large),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          focusColor: AppColors.primaryFocus,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints:
                const BoxConstraints(minHeight: AppDimensions.minInteractive),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: active ? AppColors.goldBright : AppColors.bgAlt,
              borderRadius: BorderRadius.circular(AppRadii.large),
              border: Border.all(
                color: active ? AppColors.goldDark : AppColors.border,
                width: active ? 1.3 : 1,
              ),
              boxShadow: active ? appSoftShadow : null,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: active ? AppColors.ink : AppColors.inkSoft,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
