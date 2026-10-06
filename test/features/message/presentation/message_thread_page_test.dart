import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:xiaobaihe_app/features/media/application/media_dependencies.dart';
import 'package:xiaobaihe_app/features/media/data/media_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/state/app_provider_scope.dart';
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

Map<String, dynamic> _messageJson(
  int id,
  int senderId,
  String content, {
  int msgType = 1,
}) => {
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
  Completer<http.Response>? pendingSend;
  bool failSend = false;

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
      return jsonResponse(
        okEnvelope({
          'messages': [
            lastId == null
                ? _messageJson(30, 7, '自己说的话')
                : _messageJson(20, 9, '更早的消息'),
          ],
          'hasMore': lastId == null ? hasMore : false,
        }),
      );
    }
    if (path == '/api/v2/messages/conversations/8/read') {
      return jsonResponse(okEnvelope(<String, dynamic>{}));
    }
    if (path == '/api/v2/messages') {
      if (failSend) return jsonResponse({'code': 500, 'message': '发送失败'}, 500);
      if (pendingSend != null) return pendingSend!.future;
      return jsonResponse(okEnvelope({'messageId': 31}));
    }
    fail('unexpected request: ${request.method} $path');
  }
}

Future<void> _pumpThread(
  WidgetTester tester, {
  MediaPicker? picker,
  MediaRepository? uploads,
}) async {
  await tester.pumpWidget(
    AppProviderScope(
      overrides: [
        if (picker != null) mediaPickerProvider.overrideWithValue(picker),
        if (uploads != null) mediaRepositoryProvider.overrideWithValue(uploads),
      ],
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

class _MediaPicker extends MediaPicker {
  @override
  Future<XFile?> pick(MediaKind kind) async =>
      XFile.fromData(Uint8List.fromList([1]), name: 'selected');
}

class _PendingPicker extends MediaPicker {
  final result = Completer<XFile?>();
  @override
  Future<XFile?> pick(MediaKind kind) => result.future;
}

class _Uploads extends MediaRepository {
  int calls = 0;
  @override
  Future<UploadedMedia> upload(
    XFile file,
    MediaKind kind,
    String key, {
    required bool Function() isCurrent,
  }) async {
    calls++;
    return const UploadedMedia(
      mediaId: '9007199254740993',
      url: 'https://media.test/file',
    );
  }
}

class _DeferredUploads extends MediaRepository {
  _DeferredUploads(this.result);
  final Completer<UploadedMedia> result;
  @override
  Future<UploadedMedia> upload(
    XFile file,
    MediaKind kind,
    String key, {
    required bool Function() isCurrent,
  }) => result.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  Future<void> loginAsCurrentUser() async {
    await setTokens(
      buildStoredTokens(
        accessToken: _jwtWithUser(7),
        refreshToken: 'refresh-token',
      ),
    );
    addTearDown(removeTokens);
  }

  for (final phase in ['picker', 'upload', 'send', 'retry']) {
    for (final navigation in ['go', 'push']) {
      testWidgets('$navigation to a new thread fences media during $phase', (
        tester,
      ) async {
        await loginAsCurrentUser();
        final picker = _PendingPicker();
        final upload = Completer<UploadedMedia>();
        final send = Completer<http.Response>();
        final uploads = _DeferredUploads(upload);
        final recipients = <Object?>[];
        setApiClient(
          ScriptedGatewayClient((request) async {
            if (request.url.path.endsWith('/read')) {
              return jsonResponse(okEnvelope(<String, dynamic>{}));
            }
            if (request.url.path.contains('/conversations/')) {
              return jsonResponse(
                okEnvelope({'messages': [], 'hasMore': false}),
              );
            }
            if (request.url.path == '/api/v2/messages') {
              recipients.add(
                jsonDecode((request as http.Request).body)['receiverId'],
              );
              return phase == 'send'
                  ? send.future
                  : jsonResponse({'code': 500, 'message': '发送失败'}, 500);
            }
            return jsonResponse(
              okEnvelope({'messageUnread': 0, 'notificationUnread': 0}),
            );
          }),
        );
        final router = GoRouter(
          initialLocation: '/thread/9007199254740992?target=9',
          routes: [
            GoRoute(
              path: '/thread/:id',
              builder: (_, state) => MessageThreadPage(
                conversationId: state.pathParameters['id']!,
                targetUserId: state.uri.queryParameters['target']!,
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          AppProviderScope(
            overrides: [
              mediaPickerProvider.overrideWithValue(picker),
              mediaRepositoryProvider.overrideWithValue(uploads),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              builder: foruiTestBuilder,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('发送视频'));
        await tester.pump();
        if (phase != 'picker') {
          picker.result.complete(
            XFile.fromData(Uint8List.fromList([1]), name: 'v'),
          );
          await tester.pump();
        }
        if (phase == 'send' || phase == 'retry') {
          upload.complete(
            const UploadedMedia(mediaId: 99, url: 'https://media.test/v'),
          );
          await tester.pump();
          if (phase == 'retry') await tester.pumpAndSettle();
        }
        const next = '/thread/9007199254740993?target=11';
        if (navigation == 'go') {
          router.go(next);
        } else {
          unawaited(router.push<void>(next));
        }
        await tester.pumpAndSettle();
        if (phase == 'picker') {
          picker.result.complete(
            XFile.fromData(Uint8List.fromList([1]), name: 'old'),
          );
        } else if (phase == 'upload') {
          upload.complete(
            const UploadedMedia(mediaId: 99, url: 'https://media.test/v'),
          );
        } else if (phase == 'send') {
          send.complete(jsonResponse({'code': 500, 'message': '发送失败'}, 500));
        }
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('重试媒体发送'), findsNothing);
        expect(recipients, phase == 'send' || phase == 'retry' ? [9] : isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final kind in [MediaKind.video, MediaKind.audio]) {
    testWidgets(
      '${kind.name} selection sends exact media ID and opens a usable attachment at 320px',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await loginAsCurrentUser();
        final harness = _Harness();
        final uploads = _Uploads();
        setApiClient(harness.client);
        await _pumpThread(tester, picker: _MediaPicker(), uploads: uploads);
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsLabel(kind == MediaKind.video ? '发送视频' : '发送语音文件'),
        );
        await tester.pumpAndSettle();
        expect(uploads.calls, 1);
        final sent = harness.client.requests.singleWhere(
          (r) => r.url.path == '/api/v2/messages',
        );
        final body = (sent as http.Request).body;
        expect(body, contains('9007199254740993'));
        expect(body, contains('"msgType":${kind.messageType}'));
        expect(
          find.text(kind == MediaKind.video ? '打开视频' : '播放语音文件'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('renders both sides of the conversation and marks read', (
    tester,
  ) async {
    await loginAsCurrentUser();
    final harness = _Harness();
    setApiClient(harness.client);

    await _pumpThread(tester);
    await tester.pumpAndSettle();

    expect(find.text('对方昵称'), findsOneWidget);
    expect(find.text('自己说的话'), findsOneWidget);
    // 消息拉取成功后自动标记已读。
    expect(
      harness.client.requests.where((r) => r.url.path.endsWith('/read')).length,
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
    final input = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(input.controller.text, isEmpty);
  });

  for (final retry in [false, true]) {
    testWidgets(
      '${retry ? 'retrying an old message' : 'sending a message'} preserves the next draft',
      (tester) async {
        await loginAsCurrentUser();
        final harness = _Harness()..failSend = retry;
        if (!retry) harness.pendingSend = Completer<http.Response>();
        setApiClient(harness.client);
        await _pumpThread(tester);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(EditableText).first,
          'first message',
        );
        await tester.tap(find.bySemanticsLabel('发送'));
        await tester.pump();
        if (retry) {
          await tester.pumpAndSettle();
          harness.failSend = false;
          harness.pendingSend = Completer<http.Response>();
          await tester.enterText(
            find.byType(EditableText).first,
            'unrelated draft',
          );
          await tester.tap(find.bySemanticsLabel('重试发送'));
          await tester.pump();
        } else {
          await tester.enterText(
            find.byType(EditableText).first,
            'unrelated draft',
          );
        }
        harness.pendingSend!.complete(
          jsonResponse(okEnvelope({'messageId': 31})),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).first)
              .controller
              .text,
          'unrelated draft',
        );
        final commands = harness.client.requests
            .where((r) => r.url.path == '/api/v2/messages')
            .map(jsonBodyOf)
            .toList();
        expect(commands.every((c) => c['content'] == 'first message'), isTrue);
        if (retry) {
          expect(commands[0]['idempotencyKey'], commands[1]['idempotencyKey']);
        }
      },
    );
  }

  testWidgets('falls back to an error view and recovers on retry', (
    tester,
  ) async {
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
        .where(
          (r) =>
              r.url.path == '/api/v2/messages/conversations/8' &&
              r.url.queryParameters.containsKey('lastId'),
        )
        .toList();
    expect(older, hasLength(1));
    expect(find.text('更早的消息'), findsOneWidget);
  });
}
