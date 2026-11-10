import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/features/auth/auth_service.dart';
import 'package:historiai/features/dashboard/dashboard_screen.dart';

class _PendingAuthService extends AuthService {
  _PendingAuthService() : super(ApiClient(baseUrl: 'http://localhost'));

  final _profile = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> fetchMe() => _profile.future;
}

void main() {
  const assets = [
    'assets/figures3d/item/'
        'isolate_only_the_scroll_timeline_icon_from_top_left_an_ancient_vietnamese.png',
    'assets/figures3d/item/'
        'isolate_only_the_ancient_bronze_drum_icon_from_top_right_an_ancient_dong_son.png',
    'assets/figures3d/item/'
        'isolate_the_warrior_helmet_and_speech_bubble_icon_on_a_completely_clean_solid.png',
    'assets/figures3d/item/'
        'isolate_only_the_golden_arena_quiz_trophy_icon_from_bottom_right_golden.png',
  ];

  testWidgets('discovery cards show item art and preserve tab destinations',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    int? selectedTab;
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          authService: _PendingAuthService(),
          onNavigateTab: (tabIndex) => selectedTab = tabIndex,
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Khám Phá Sử Việt'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Dòng thời gian'), findsOneWidget);
    expect(find.text('Các trận đánh lớn theo năm'), findsOneWidget);
    expect(find.text('Bảo tàng 3D'), findsOneWidget);
    expect(find.text('Xoay cổ vật, xem từng góc'), findsOneWidget);
    expect(find.text('Hỏi vĩ nhân'), findsOneWidget);
    expect(find.text('Hỏi chuyện nhân vật lịch sử'), findsOneWidget);
    expect(find.text('Đấu trường'), findsOneWidget);
    expect(find.text('Làm quiz, tích điểm'), findsOneWidget);

    for (final asset in assets) {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == asset,
        ),
        findsOneWidget,
      );
    }

    const destinations = {
      'explore-card-timeline': 1,
      'explore-card-museum': 4,
      'explore-card-chat': 3,
      'explore-card-quiz': 2,
    };

    for (final entry in destinations.entries) {
      final card = find.byKey(Key(entry.key));
      await tester.ensureVisible(card);
      await tester.pump();
      selectedTab = null;
      await tester.tap(card);
      await tester.pump();
      expect(selectedTab, entry.value);
    }

    expect(tester.takeException(), isNull);
  });
}
