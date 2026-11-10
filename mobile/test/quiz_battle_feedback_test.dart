import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/core/theme.dart';
import 'package:historiai/core/widgets/battlefield_tactics_header.dart';
import 'package:historiai/core/widgets/vietnamese_decorations.dart';

void main() {
  group('Quiz Battle Feedback & Seal Tests', () {
    testWidgets(
        'RoyalSealStamp renders with custom rectangular size and phrase',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RoyalSealStamp(
                text: 'Kế sách chuẩn xác!',
                subtext: '+10 ĐIỂM',
                width: 145,
                height: 78,
              ),
            ),
          ),
        ),
      );

      // Verify text presence
      expect(find.text('Kế sách chuẩn xác!'), findsOneWidget);
      expect(find.text('+10 ĐIỂM'), findsOneWidget);

      // Advance animation
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
    });

    testWidgets(
        'RoyalSealStamp renders with long battle phrases without overflow',
        (tester) async {
      final phrases = [
        'Kế sách chuẩn xác!',
        'Thế trận được củng cố!',
        'Đòn đánh trúng trọng điểm!',
        'Thế trận bị lung lay!',
        'Kế sách chưa chính xác!',
        'Cần xem lại chiến lược!',
      ];

      for (final phrase in phrases) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RoyalSealStamp(
                  text: phrase,
                  subtext: '+10 ĐIỂM',
                  width: 145,
                  height: 78,
                ),
              ),
            ),
          ),
        );
        expect(find.text(phrase), findsOneWidget);
        await tester.pumpAndSettle();
      }
    });

    testWidgets(
        'BattlefieldTacticsHeader renders animated morale bar correctly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.bg,
            body: BattlefieldTacticsHeader(
              campaignName: 'Chiến dịch Điện Biên Phủ',
              currentQuestion: 3,
              totalQuestions: 10,
              correctCount: 2,
              streakCount: 2,
              timeRemaining: 20,
              isDrumBeating: false,
            ),
          ),
        ),
      );

      expect(find.text('Chiến dịch Điện Biên Phủ'), findsOneWidget);
      expect(find.textContaining('Phong độ:'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
