import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/auth/presentation/register_page.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../../helpers/forui_test_builder.dart';
import '../../../helpers/gateway_fake.dart';

Future<Widget> _page() async {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/auth/register',
        routes: [
          GoRoute(
            path: '/auth/register',
            builder: (_, _) => const RegisterPage(),
          ),
          GoRoute(
            path: '/auth/login',
            builder: (_, _) => const Scaffold(body: Text('登录页占位')),
          ),
          GoRoute(
            path: '/feed',
            builder: (_, _) => const Scaffold(body: Text('信息流占位')),
          ),
        ],
      ),
      builder: foruiTestBuilder,
    ),
  );
}

Future<void> pumpRegister(WidgetTester tester) async {
  final widget = await _page();
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  testWidgets('renders all registration fields', (tester) async {
    await pumpRegister(tester);

    expect(find.text('注册'), findsNWidgets(2));
    for (final label in ['用户名', '密码', '确认密码', '手机号', '验证码']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('获取验证码'), findsOneWidget);
    expect(find.text('已有账号？去登录'), findsOneWidget);
  });

  testWidgets('rejects incomplete forms without a network call',
      (tester) async {
    final client = ScriptedGatewayClient.always(<String, dynamic>{});
    setApiClient(client);
    await pumpRegister(tester);

    await tester.tap(find.widgetWithText(FButton, '注册'));
    await tester.pumpAndSettle();

    expect(find.text('请填写所有字段'), findsOneWidget);
    expect(client.requests, isEmpty);

    // 密码不一致同样被拦截。
    await tester.enterText(find.byType(EditableText).at(0), 'neo');
    await tester.enterText(find.byType(EditableText).at(1), 'secret1');
    await tester.enterText(find.byType(EditableText).at(2), 'secret2');
    await tester.enterText(find.byType(EditableText).at(3), '13800000000');
    await tester.enterText(find.byType(EditableText).at(4), '123456');
    await tester.tap(find.widgetWithText(FButton, '注册'));
    await tester.pumpAndSettle();

    expect(find.text('两次密码输入不一致'), findsOneWidget);
    expect(client.requests, isEmpty);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('registers with the gateway contract and lands on the feed',
      (tester) async {
    final client = ScriptedGatewayClient.always({
      'userId': 9,
      'token': 'access-9',
      'refreshToken': 'refresh-9',
    });
    setApiClient(client);
    await pumpRegister(tester);

    await tester.enterText(find.byType(EditableText).at(0), 'neo');
    await tester.enterText(find.byType(EditableText).at(1), 'secret');
    await tester.enterText(find.byType(EditableText).at(2), 'secret');
    await tester.enterText(find.byType(EditableText).at(3), '13800000000');
    await tester.enterText(find.byType(EditableText).at(4), '123456');
    await tester.tap(find.widgetWithText(FButton, '注册'));
    await tester.pumpAndSettle();

    final request = client.requests.single as http.Request;
    expect(request.url.path, '/api/v1/auth/register');
    expect(jsonBodyOf(request), {
      'username': 'neo',
      'password': 'secret',
      'phone': '13800000000',
      'verifyCode': '123456',
    });
    expect(find.text('信息流占位'), findsOneWidget);
  });

  testWidgets('sends the verify code for the entered phone number',
      (tester) async {
    final client = ScriptedGatewayClient.always(<String, dynamic>{});
    setApiClient(client);
    await pumpRegister(tester);

    await tester.enterText(find.byType(EditableText).at(3), '13800000001');
    await tester.tap(find.widgetWithText(FButton, '获取验证码'));
    await tester.pumpAndSettle();

    final request = client.requests.single as http.Request;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/auth/verify-code');
    expect(jsonBodyOf(request), {'phone': '13800000001', 'type': 1});
    expect(find.text('60s'), findsOneWidget);
  });

  testWidgets('navigates to the login page via the ghost action',
      (tester) async {
    await pumpRegister(tester);

    await tester.tap(find.text('已有账号？去登录'));
    await tester.pumpAndSettle();

    expect(find.text('登录页占位'), findsOneWidget);
  });
}
