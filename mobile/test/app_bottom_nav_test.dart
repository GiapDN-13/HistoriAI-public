import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/core/theme.dart';
import 'package:historiai/core/widgets/app_scaffold.dart';

void main() {
  const assets = [
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

  // Nhãn hiện dưới icon (thiết kế 6 tab). "Thời gian" là bản rút gọn để
  // không gãy dòng; tên đầy đủ "Dòng thời gian" nằm ở nhãn trợ năng.
  const labels = [
    'Trang chủ',
    'Thời gian',
    'Đấu trường',
    'Vĩ nhân',
    'Bảo tàng',
    'Tài khoản',
  ];

  testWidgets('bottom navigation: 6 tab có icon 3D, có nhãn, bấm đúng tab',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    int? selectedTab;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHistoriAITheme(),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppBottomNav(
            current: 2,
            onTap: (tabIndex) => selectedTab = tabIndex,
          ),
        ),
      ),
    );

    for (final asset in assets) {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == asset &&
              widget.excludeFromSemantics,
        ),
        findsOneWidget,
      );
    }

    for (final label in labels) {
      expect(find.text(label), findsOneWidget,
          reason: 'icon 3D không tự nói nó là gì — người mới cần chữ');
    }

    for (var index = 0; index < labels.length; index++) {
      selectedTab = null;
      await tester.tap(find.byKey(ValueKey('bottom-nav-item-$index')));
      await tester.pump();
      expect(selectedTab, index);
    }

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    // 5 icon gốc + icon hồ sơ của tab Tài khoản.
    expect(images, hasLength(6));
    expect(images.every((image) => image.fit == BoxFit.contain), isTrue);
    expect(tester.takeException(), isNull);
  });
}
