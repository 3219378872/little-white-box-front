import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/profile/presentation/edit_profile_page.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';

import '../../../helpers/forui_test_builder.dart';
import '../../../helpers/gateway_fake.dart';

String _jwtWithUser(int userId) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'userId': userId, 'exp': 1893456000})}.sig';
}

/// 先在宿主页 watch 一次 authNotifier，确保进入编辑页时已完成异步初始化。
class _EditorEntry extends ConsumerWidget {
  const _EditorEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authNotifierProvider);
    return Scaffold(
      body: Center(
        child: FButton(
          onPress: () => context.push('/me/edit'),
          child: const Text('打开编辑资料'),
        ),
      ),
    );
  }
}

Future<void> _pumpEditor(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (_, _) => const _EditorEntry()),
            GoRoute(
              path: '/me/edit',
              builder: (_, _) => const EditProfilePage(),
            ),
          ],
        ),
        builder: foruiTestBuilder,
      ),
    ),
  );
  // 等待 authNotifier 完成异步初始化，否则页面拿到 null userId 会跳过加载。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text('打开编辑资料'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    setApiClient(http.Client());
    removeTokens();
  });

  testWidgets('prefills the form from the current user profile',
      (tester) async {
    await setTokens(buildStoredTokens(
      accessToken: _jwtWithUser(7),
      refreshToken: 'r',
    ));
    final client = ScriptedGatewayClient.always({
      'id': 7,
      'username': 'admin',
      'nickname': '管理员昵称',
      'avatarUrl': '',
      'bio': '一句话简介',
      'level': 1,
      'followerCount': 0,
      'followingCount': 0,
      'postCount': 0,
      'favoritesVisible': false,
    });
    setApiClient(client);

    await _pumpEditor(tester);

    expect(find.text('编辑资料'), findsOneWidget);
    expect(find.text('管'), findsOneWidget); // 头像兜底取昵称首字符
    final fields = tester.widgetList<EditableText>(
      find.byType(EditableText),
    );
    expect(fields.first.controller.text, '管理员昵称');
    expect(fields.elementAt(1).controller.text, '一句话简介');
    expect(
      client.requests.single.url.path,
      '/api/v1/user/7',
    );
  });

  testWidgets('saves trimmed values and returns to the previous page',
      (tester) async {
    await setTokens(buildStoredTokens(
      accessToken: _jwtWithUser(7),
      refreshToken: 'r',
    ));
    final client = ScriptedGatewayClient((request) async {
      if (request.url.path == '/api/v1/user/7') {
        return jsonResponse(okEnvelope({
          'id': 7,
          'username': 'admin',
          'nickname': '旧昵称',
          'avatarUrl': '',
          'bio': '',
        }));
      }
      if (request.url.path == '/api/v1/user/profile') {
        return jsonResponse(okEnvelope(<String, dynamic>{}));
      }
      fail('unexpected request: ${request.method} ${request.url.path}');
    });
    setApiClient(client);

    await _pumpEditor(tester);

    await tester.enterText(find.byType(EditableText).first, '  新昵称  ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final put = client.requests.last as http.Request;
    expect(put.method, 'PUT');
    expect(jsonBodyOf(put), {
      'nickname': '新昵称',
      'avatarUrl': '',
      'bio': '',
    });
    // 保存成功后返回上一页。
    expect(find.text('打开编辑资料'), findsOneWidget);
  });

  testWidgets('keeps the page open and toasts on save failure',
      (tester) async {
    await setTokens(buildStoredTokens(
      accessToken: _jwtWithUser(7),
      refreshToken: 'r',
    ));
    final client = ScriptedGatewayClient((request) async {
      if (request.url.path == '/api/v1/user/7') {
        return jsonResponse(okEnvelope({
          'id': 7,
          'username': 'admin',
          'nickname': '旧昵称',
          'avatarUrl': '',
          'bio': '',
        }));
      }
      if (request.url.path == '/api/v1/user/profile') {
        return jsonResponse({'code': 500, 'message': '服务器错误'}, 500);
      }
      fail('unexpected request');
    });
    setApiClient(client);

    await _pumpEditor(tester);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(find.text('编辑资料'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('cold-start deep link waits for auth and still prefills',
      (tester) async {
    // 回归：不经过宿主页预热 auth，直接以编辑页为初始路由进入。
    await setTokens(buildStoredTokens(
      accessToken: _jwtWithUser(7),
      refreshToken: 'r',
    ));
    final client = ScriptedGatewayClient.always({
      'id': 7,
      'username': 'admin',
      'nickname': '管理员昵称',
      'avatarUrl': '',
      'bio': '一句话简介',
    });
    setApiClient(client);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/me/edit',
            routes: [
              GoRoute(
                path: '/me/edit',
                builder: (_, _) => const EditProfilePage(),
              ),
            ],
          ),
          builder: foruiTestBuilder,
        ),
      ),
    );
    // 等待身份恢复 → 自动触发资料加载 → 预填表单。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final fields = tester.widgetList<EditableText>(
      find.byType(EditableText),
    );
    expect(fields, isNotEmpty);
    expect(fields.first.controller.text, '管理员昵称');
    expect(client.requests.single.url.path, '/api/v1/user/7');
  });

  testWidgets('shows a retryable error view when the profile fetch fails',
      (tester) async {
    await setTokens(buildStoredTokens(
      accessToken: _jwtWithUser(7),
      refreshToken: 'r',
    ));
    var profileOk = false;
    final client = ScriptedGatewayClient((request) async {
      if (request.url.path == '/api/v1/user/7') {
        return profileOk
            ? jsonResponse(okEnvelope({
                'id': 7,
                'username': 'admin',
                'nickname': '恢复昵称',
                'avatarUrl': '',
                'bio': '',
              }))
            : jsonResponse({'code': 500, 'message': '服务器错误'}, 500);
      }
      fail('unexpected request: ${request.method} ${request.url.path}');
    });
    setApiClient(client);

    await _pumpEditor(tester);
    // 加载失败：呈现错误态而不是永久进度圈。
    await tester.pumpAndSettle();
    expect(find.text('加载失败: 服务器错误'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    profileOk = true;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    final fields = tester.widgetList<EditableText>(
      find.byType(EditableText),
    );
    expect(fields.first.controller.text, '恢复昵称');
  });
}
