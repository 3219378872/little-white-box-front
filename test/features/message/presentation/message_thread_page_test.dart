import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/widgets/error_view.dart';
import 'package:xiaobaihe_app/features/message/presentation/message_thread_page.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';

import '../../../helpers/gateway_fake.dart';
import '../../../helpers/forui_test_builder.dart';

String _jwtWithUser(int userId) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'userId': userId, 'exp': 1893456000})}.sig';
}

Map<String, dynamic> _messageJson(int id, int senderId, String content,
        {int msgType = 1}) =>
    {
      'id': id,
      'conversationId': 8,
      'senderId': senderId,
      'receiverId': 9,
      'content': content,
      'msgType': msgType,
      'status': 0,
      'createdAt': 1700000000,
    };

class _Harness {
  late final ScriptedGatewayClient client;
  bool threadOk = true;
  bool hasMore = false;

  _Harness() {
    client = ScriptedGatewayClient(route);
  }

  Future<http.Response> route(http.BaseRequest request) async {
    final path = request.url.path;
    if (path == '/api/v2/messages/conversations/8') {
      if (!threadOk) {
        return jsonResponse({'code': 500, 'message': '消息服务不可用'}, 500);
      }
      final lastId = request.url.queryParameters['lastId'];
      return jsonResponse(okEnvelope({
        'messages': [
          lastId == null
              ? _messageJson(30, 7, '自己说的话')
              : _messageJson(20, 9, '更早的消息'),
        ],
        'hasMore': lastId == null ? hasMore : false,
      }));
    }
    if (path == '/api/v2/messages/conversations/8/read') {
      return jsonResponse(okEnvelope(<String, dynamic>{}));
    }
    if (path == '/api/v2/messages') {
      return jsonResponse(okEnvelope({'messageId': 31}));
    }
    fail('unexpected request: ${request.method} $path');
  }
}

Future<void> _pumpThread(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/thread',
          routes: [
            GoRoute(
              path: '/thread',
              builder: (_, _) => const MessageThreadPage(
                conversationId: 8,
                targetUserId: 9,
                targetUserName: '对方昵称',
              ),
            ),
          ],
        ),
        builder: foruiTestBuilder,
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  Future<void> loginAsCurrentUser() async {
    await setTokens(buildStoredTokens(
      accessToken: _jwtWithUser(7),
      refreshToken: 'refresh-token',
    ));
    addTearDown(removeTokens);
  }

  testWidgets('renders both sides of the conversation and marks read',
      (tester) async {
    await loginAsCurrentUser();
    final harness = _Harness();
    setApiClient(harness.client);

    await _pumpThread(tester);
    await tester.pumpAndSettle();

    expect(find.text('对方昵称'), findsOneWidget);
    expect(find.text('自己说的话'), findsOneWidget);
    // 消息拉取成功后自动标记已读。
    expect(
      harness.client.requests
          .where((r) => r.url.path.endsWith('/read'))
          .length,
      greaterThanOrEqualTo(1),
    );
  });

  testWidgets('sends a typed message through the v2 contract', (tester) async {
    await loginAsCurrentUser();
    final harness = _Harness();
    setApiClient(harness.client);

    await _pumpThread(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).first, '你好呀');
    await tester.tap(find.bySemanticsLabel('发送'));
    await tester.pumpAndSettle();

    final send = harness.client.requests.lastWhere(
      (r) => r.url.path == '/api/v2/messages',
    ) as http.Request;
    final body = jsonBodyOf(send);
    expect(body['content'], '你好呀');
    expect(body['msgType'], 1);
    expect((body['idempotencyKey'] as String), isNotEmpty);
    // 发送成功后消息上屏、输入框被清空。
    expect(find.text('你好呀'), findsOneWidget);
    final input = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    expect(input.controller.text, isEmpty);
  });

  testWidgets('falls back to an error view and recovers on retry',
      (tester) async {
    await loginAsCurrentUser();
    final harness = _Harness()..threadOk = false;
    setApiClient(harness.client);

    await _pumpThread(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('消息服务不可用'), findsOneWidget);

    harness.threadOk = true;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('自己说的话'), findsOneWidget);
  });

  testWidgets('loads older messages on demand', (tester) async {
    await loginAsCurrentUser();
    final harness = _Harness()..hasMore = true;
    setApiClient(harness.client);

    await _pumpThread(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('加载更早消息'));
    await tester.pumpAndSettle();

    final older = harness.client.requests
        .where((r) =>
            r.url.path == '/api/v2/messages/conversations/8' &&
            r.url.queryParameters.containsKey('lastId'))
        .toList();
    expect(older, hasLength(1));
    expect(find.text('更早的消息'), findsOneWidget);
  });
}
