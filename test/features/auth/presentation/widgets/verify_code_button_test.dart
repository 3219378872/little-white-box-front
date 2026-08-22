import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/auth/presentation/widgets/verify_code_button.dart';

import '../../../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('starts a countdown after a successful send', (tester) async {
    var sendCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(
          body: Center(
            child: VerifyCodeButton(onSend: () async => sendCalls++),
          ),
        ),
      ),
    );

    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(sendCalls, 1);
    expect(find.text('60s'), findsOneWidget);

    // 倒计时期间按钮禁用，不再触发发送。
    await tester.tap(find.text('60s'));
    await tester.pump();
    expect(sendCalls, 1);

    // 走完整个倒计时，避免测试结束时残留定时器。
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('获取验证码'), findsOneWidget);
  });

  testWidgets('counts down back to the idle label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(
          body: Center(child: VerifyCodeButton(onSend: () async {})),
        ),
      ),
    );

    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    expect(find.text('60s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('1s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('获取验证码'), findsOneWidget);
  });

  testWidgets('shows an error toast when sending fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(
          body: Center(
            child: VerifyCodeButton(
              onSend: () async => throw Exception('boom'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('获取验证码'));
    await tester.pumpAndSettle();

    expect(find.textContaining('发送失败'), findsOneWidget);
    // 失败后不进入倒计时。
    expect(find.textContaining('s'), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
