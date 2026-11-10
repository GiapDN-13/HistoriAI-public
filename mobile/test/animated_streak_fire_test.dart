import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/core/widgets/animated_streak_fire.dart';
import 'package:historiai/core/theme.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/features/auth/auth_service.dart';
import 'package:historiai/features/dashboard/dashboard_screen.dart';

void main() {
  group('AnimatedStreakFire Tests', () {
    testWidgets(
        'AnimatedStreakFire renders and animates with flame icon and sparks',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedStreakFire(size: 24, showSparks: true),
            ),
          ),
        ),
      );

      // Verify flame icon exists
      expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);

      // Advance animation frames
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets(
        'AnimatedStreakFire renders static fallback when animations are disabled',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedStreakFire(size: 20),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });

    testWidgets(
        'DashboardScreen renders animated streak chip with streak text and flame',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHistoriAITheme(),
          home: DashboardScreen(
            authService: AuthService(ApiClient(baseUrl: 'http://test')),
            isTabRoot: true,
          ),
        ),
      );
      await tester.pump();

      // Find the streak chip with flame
      expect(find.byType(AnimatedStreakFire), findsOneWidget);
      expect(find.textContaining('Chuỗi'), findsOneWidget);
    });
  });
}
