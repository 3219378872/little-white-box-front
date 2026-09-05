import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/app.dart';
import 'package:xiaobaihe_app/core/router/app_router.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/auth/presentation/login_page.dart';
import 'package:xiaobaihe_app/features/auth/presentation/widgets/verify_code_button.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../../helpers/forui_test_builder.dart';
import '../../../helpers/gateway_fake.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

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

  testWidgets('app localizes password visibility semantics in Chinese', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/auth/login',
      routes: [
        GoRoute(path: '/auth/login', builder: (_, _) => const LoginPage()),
      ],
    );
    addTearDown(router.dispose);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [routerProvider.overrideWithValue(router)],
          child: const XiaobaiheApp(),
        ),
      );
      await tester.pump();

      final showPassword = find.semantics.byLabel('显示密码');
      expect(showPassword, findsOne);

      tester.semantics.tap(showPassword);
      await tester.pump();

      expect(find.semantics.byLabel('显示密码'), findsNothing);
      expect(find.semantics.byLabel('隐藏密码'), findsOne);
    } finally {
      semantics.dispose();
    }
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

  testWidgets('ignores a failed login response after page disposal', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final client = ScriptedGatewayClient((_) => response.future);
    setApiClient(client);
    final router = GoRouter(
      initialLocation: '/auth/login',
      routes: [
        GoRoute(path: '/auth/login', builder: (_, _) => const LoginPage()),
        GoRoute(
          path: '/away',
          builder: (_, _) => const Scaffold(body: Text('其他页面')),
        ),
        GoRoute(
          path: '/feed',
          builder: (_, _) => const Scaffold(body: Text('信息流占位')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(0), 'neo');
    await tester.enterText(find.byType(EditableText).at(1), 'secret');
    await tester.tap(find.widgetWithText(FButton, '登录').first);
    await tester.pump();
    expect(client.requests, hasLength(1));

    router.go('/away');
    await tester.pumpAndSettle();
    response.complete(
      jsonResponse({'code': 6, 'message': 'late failure'}, 503),
    );
    await tester.pumpAndSettle();

    expect(find.text('其他页面'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'does not authenticate from a successful response after leaving',
    (tester) async {
      final response = Completer<http.Response>();
      final client = ScriptedGatewayClient((_) => response.future);
      setApiClient(client);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/auth/login',
        routes: [
          GoRoute(path: '/auth/login', builder: (_, _) => const LoginPage()),
          GoRoute(
            path: '/away',
            builder: (_, _) => const Scaffold(body: Text('其他页面')),
          ),
          GoRoute(
            path: '/feed',
            builder: (_, _) => const Scaffold(body: Text('信息流占位')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: foruiTestBuilder,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(0), 'neo');
      await tester.enterText(find.byType(EditableText).at(1), 'secret');
      await tester.tap(find.widgetWithText(FButton, '登录').first);
      await tester.pump();
      expect(client.requests, hasLength(1));

      router.go('/away');
      await tester.pumpAndSettle();
      response.complete(
        jsonResponse({
          'userId': 9,
          'token': 'late-access-token',
          'refreshToken': 'late-refresh-token',
        }),
      );
      await tester.pumpAndSettle();

      expect(find.text('其他页面'), findsOneWidget);
      expect(container.read(authNotifierProvider).isAuthenticated, isFalse);
      expect(container.read(authNotifierProvider).token, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
