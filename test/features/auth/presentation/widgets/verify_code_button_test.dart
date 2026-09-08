import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/auth/data/auth_repository.dart';
import 'package:xiaobaihe_app/features/auth/presentation/widgets/verify_code_button.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../../../helpers/forui_test_builder.dart';
import '../../../../helpers/gateway_fake.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  testWidgets('starts a countdown after a typed empty gateway success', (
    tester,
  ) async {
    final client = ScriptedGatewayClient((_) async => jsonResponse({}));
    setApiClient(client);
    final repository = AuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(
          body: Center(
            child: VerifyCodeButton(
              onSend: () => repository.sendCode('13800000002', 2),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('获取验证码'));
    await tester.pumpAndSettle();

    expect(client.requests.single.url.path, '/api/v1/auth/verify-code');
    expect(find.text('60s'), findsOneWidget);

    // 倒计时期间按钮禁用，不再触发发送。
    await tester.tap(find.text('60s'));
    await tester.pump();
    expect(client.requests, hasLength(1));

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

  testWidgets('a null gateway response shows an error without a countdown', (
    tester,
  ) async {
    final client = ScriptedGatewayClient(
      (_) async => http.Response('null', 200),
    );
    setApiClient(client);
    final repository = AuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(
          body: Center(
            child: VerifyCodeButton(
              onSend: () => repository.sendCode('13800000002', 2),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('获取验证码'));
    await tester.pumpAndSettle();

    expect(client.requests.single.url.path, '/api/v1/auth/verify-code');
    expect(find.textContaining('发送失败'), findsOneWidget);
    // 失败后不进入倒计时。
    expect(find.text('60s'), findsNothing);
    expect(find.text('获取验证码'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('ignores a successful send after the button is disposed', (
    tester,
  ) async {
    final send = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(
          body: Center(child: VerifyCodeButton(onSend: () => send.future)),
        ),
      ),
    );

    await tester.tap(find.text('获取验证码'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    send.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
