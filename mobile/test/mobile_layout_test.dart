import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/core/theme.dart';
import 'package:historiai/core/widgets/app_scaffold.dart';
import 'package:historiai/features/auth/auth_service.dart';
import 'package:historiai/features/auth/login_screen.dart';

void main() {
  const mobileWidths = [360.0, 375.0, 390.0, 430.0];

  group('Mobile layout', () {
    LoginScreen buildLogin() => LoginScreen(
          authService: AuthService(ApiClient(baseUrl: 'http://test')),
        );

    for (final width in mobileWidths) {
      testWidgets('Login không tràn ngang ở ${width.toInt()} px',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: buildHistoriAITheme(),
            home: buildLogin(),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Dùng thử không cần tài khoản'), findsOneWidget);

        final passwordRect = tester.getRect(
          find.byKey(const Key('login-password-field')),
        );
        expect(
          passwordRect.center.dy,
          moreOrLessEquals(422, epsilon: 8),
          reason:
              'Ô mật khẩu phải nằm trong vùng giữa quang học của viewport 844 px.',
        );
      });

      testWidgets('Bottom navigation không tràn ở ${width.toInt()} px',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: buildHistoriAITheme(),
            home: const Scaffold(
              body: SizedBox.expand(),
              bottomNavigationBar: AppBottomNav(current: 0),
            ),
          ),
        );

        // Bắt cả tràn DỌC: nhãn gãy 2 dòng từng đẩy cột cao hơn ô 1,2 px.
        expect(tester.takeException(), isNull);
        expect(find.text('Trang chủ'), findsOneWidget);
        expect(find.text('Tài khoản'), findsOneWidget);
        expect(find.byType(Image), findsNWidgets(6));
        expect(
          find.byKey(const ValueKey('bottom-nav-item-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('bottom-nav-item-4')),
          findsOneWidget,
        );
      });
    }

    testWidgets('Login cuộn được khi chiều cao màn hình ngắn', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: buildHistoriAITheme(),
          home: buildLogin(),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -320));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Đăng ký ngay'), findsOneWidget);
    });
  });
}
