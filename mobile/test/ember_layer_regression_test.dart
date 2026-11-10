import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/core/analytics.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/core/theme.dart';
import 'package:historiai/core/widgets/app_scaffold.dart';
import 'package:historiai/core/widgets/ember_layer.dart';
import 'package:historiai/core/widgets/vietnamese_decorations.dart';
import 'package:historiai/features/auth/auth_service.dart';
import 'package:historiai/features/auth/login_screen.dart';
import 'package:historiai/features/dashboard/dashboard_screen.dart';
import 'package:historiai/features/quiz/quiz_map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    Analytics.instance.datLaiChoTest();
    SharedPreferences.setMockInitialValues({});
  });

  group('EmberLayer regression tests - Layer ordering & Childless watermarks', () {
    // 21/10: hạt lửa rời khỏi DongSonBackground (mỗi màn một iframe làm app giật —
    // xem vietnamese_decorations.dart). Chỉ trang chủ còn giữ một lớp.
    testWidgets('DongSonBackground with child paints drum -> child, without EmberLayer',
        (tester) async {
      const contentKey = Key('content-widget');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DongSonBackground(
              size: 360,
              child: Container(
                key: contentKey,
                width: 200,
                height: 200,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(EmberLayer), findsNothing);
      final stack = tester.widget<Stack>(find.descendant(
          of: find.byType(DongSonBackground), matching: find.byType(Stack)).first);
      expect(stack.children.length, 2);
      expect(stack.children[0], isA<Positioned>());
      expect((stack.children[0] as Positioned).child, isA<IgnorePointer>());
      expect((stack.children[1] as Container).key, contentKey);
    });

    testWidgets('Childless DongSonBackground does NOT create EmberLayer',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DongSonBackground(size: 240),
                DongSonBackground(size: 160),
                DongSonBackground(size: 180),
              ],
            ),
          ),
        ),
      );

      // Should not contain any EmberLayer
      expect(find.byType(EmberLayer), findsNothing);
      // Hoạ tiết trống đồng nay dựng từ ảnh PNG, không còn vẽ bằng
      // CustomPainter — mỗi DongSonBackground vẫn phải có đúng một hoạ tiết.
      expect(
        find.descendant(
          of: find.byType(DongSonBackground),
          matching: find.byType(Image),
        ),
        findsNWidgets(3),
      );
    });

    testWidgets('QuizMapScreen layer order: background -> flag -> body (no EmberLayer)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHistoriAITheme(),
          home: const QuizMapScreen(isTabRoot: false),
        ),
      );
      await tester.pump();

      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);
      final scaffold = tester.widget<Scaffold>(scaffoldFinder);

      expect(scaffold.body, isA<Stack>());
      final stack = scaffold.body! as Stack;
      expect(stack.children.length, 3);
      expect(find.byType(EmberLayer), findsNothing);

      // Child 0: DongSonBackground watermark
      expect(stack.children[0], isA<Positioned>());
      expect((stack.children[0] as Positioned).child, isA<DongSonBackground>());

      // Child 1: CommandFlagBackgroundMotif
      expect(stack.children[1], isA<Positioned>());
      expect((stack.children[1] as Positioned).child,
          isA<CommandFlagBackgroundMotif>());

      // Child 2: screen body
    });

    testWidgets('DashboardScreen layer order: background Stack with EmberLayer behind Column',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHistoriAITheme(),
          home: DashboardScreen(
            authService: AuthService(ApiClient(baseUrl: 'http://test')),
            isTabRoot: false,
          ),
        ),
      );
      await tester.pump();

      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);
      final scaffold = tester.widget<Scaffold>(scaffoldFinder);

      expect(scaffold.body, isA<Stack>());
      final stack = scaffold.body! as Stack;
      expect(stack.children.length, 2);

      // Child 0: EmberLayer positioned fill behind content
      expect(stack.children[0], isA<Positioned>());
      final emberPos = stack.children[0] as Positioned;
      expect(emberPos.left, 0);
      expect(emberPos.top, 0);
      expect(emberPos.right, 0);
      expect(emberPos.bottom, 0);
      expect(emberPos.child, isA<EmberLayer>());

      // Child 1: Column containing header and scrollable body
      expect(stack.children[1], isA<Column>());

      // bottomNavigationBar is kept outside body stack
      expect(scaffold.bottomNavigationBar, isA<AppBottomNav>());
    });
  });

  group('EmberLayer regression tests - Content bounds, taps and semantics', () {
    testWidgets('Content bounds are unchanged when wrapped with DongSonBackground',
        (tester) async {
      const normalKey = Key('normal-box');
      const wrappedKey = Key('wrapped-box');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                key: normalKey,
                width: 250,
                height: 120,
              ),
            ),
          ),
        ),
      );
      final normalRect = tester.getRect(find.byKey(normalKey));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DongSonBackground(
                size: 360,
                child: SizedBox(
                  key: wrappedKey,
                  width: 250,
                  height: 120,
                ),
              ),
            ),
          ),
        ),
      );
      final wrappedRect = tester.getRect(find.byKey(wrappedKey));

      expect(wrappedRect.size, equals(normalRect.size));
      expect(wrappedRect.left, equals(normalRect.left));
      expect(wrappedRect.top, equals(normalRect.top));
    });

    testWidgets('Taps pass through DongSonBackground and EmberLayer without interference',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DongSonBackground(
              size: 360,
              child: Center(
                child: ElevatedButton(
                  key: const Key('test-button'),
                  onPressed: () => tapped = true,
                  child: const Text('Test Tap'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('test-button')));
      await tester.pump();
      expect(tapped, isTrue);

      expect(find.byType(EmberLayer), findsNothing);
    });
  });

  group('EmberLayer regression tests - Viewport widths and scrolling (360/375/390/430 + Desktop)', () {
    const viewports = <String, Size>{
      'Mobile 360': Size(360, 780),
      'Mobile 375': Size(375, 812),
      'Mobile 390': Size(390, 844),
      'Mobile 430': Size(430, 932),
      'Desktop 1024': Size(1024, 768),
      'Desktop 1280': Size(1280, 800),
    };

    for (final entry in viewports.entries) {
      testWidgets('Dashboard layout & scrolling at ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));

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

        expect(tester.takeException(), isNull);
        expect(find.byType(EmberLayer), findsOneWidget);

        // Scroll the ListView
        final listViewFinder = find.byType(ListView);
        expect(listViewFinder, findsOneWidget);
        await tester.drag(listViewFinder, const Offset(0, -300));
        await tester.pump();

        expect(tester.takeException(), isNull);
      });

      testWidgets('Login layout & scrolling at ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: buildHistoriAITheme(),
            home: LoginScreen(
              authService: AuthService(ApiClient(baseUrl: 'http://test')),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        // Từ 21/10 DongSonBackground không còn kèm lớp hạt lửa.
        expect(find.byType(EmberLayer), findsNothing);

        final scrollableFinder = find.byType(SingleChildScrollView);
        if (scrollableFinder.evaluate().isNotEmpty) {
          await tester.drag(scrollableFinder, const Offset(0, -150));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      });
    }
  });
}
