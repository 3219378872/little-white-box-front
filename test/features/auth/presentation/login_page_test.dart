import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xiaobaihe_app/features/auth/presentation/login_page.dart';
import 'package:xiaobaihe_app/features/auth/presentation/widgets/verify_code_button.dart';

import '../../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('LoginPage uses Forui tabs and switches login modes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(builder: foruiTestBuilder, home: LoginPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(FTabs), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsWidgets);

    await tester.tap(find.text('验证码登录'));
    await tester.pumpAndSettle();

    expect(find.text('手机号'), findsOneWidget);
    expect(find.text('验证码'), findsOneWidget);
    expect(find.text('获取验证码'), findsOneWidget);
  });

  testWidgets('aligns the verify-code input with the send button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(builder: foruiTestBuilder, home: LoginPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('验证码登录'));
    await tester.pumpAndSettle();

    final field = tester.getRect(
      find.descendant(
        of: find.byType(VerifyCodeField),
        matching: find.byType(FTextField),
      ),
    );
    final button = tester.getRect(
      find.descendant(
        of: find.byType(VerifyCodeField),
        matching: find.byType(FButton),
      ),
    );

    expect(button.bottom, closeTo(field.bottom, 1));
    expect(button.top, greaterThan(field.top + 8));
  });
}
