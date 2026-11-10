import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/core/api_client.dart';
import 'package:historiai/features/auth/auth_service.dart';
import 'package:historiai/features/auth/dang_nhap_google.dart';

void main() {
  testWidgets('Chưa dựng kèm GOOGLE_CLIENT_ID thì không hiện nút Google', (t) async {
    expect(googleDangBat, isFalse);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NutGoogle(authService: AuthService(ApiClient()), khiXong: (_) {}),
      ),
    ));
    expect(find.text('hoặc'), findsNothing);
    expect(find.text('Tiếp tục với Google'), findsNothing);
  });
}
