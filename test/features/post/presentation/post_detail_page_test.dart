import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/widgets/error_view.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/post/presentation/post_detail_page.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../../helpers/forui_test_builder.dart';
import '../../../helpers/gateway_fake.dart';
import '../../assistant/helpers/fake_assistant_source.dart';

Map<String, dynamic> _postJson({
  String title = '联调标题',
  String content = '联调正文',
}) => {
  'id': 9,
  'authorId': 2,
  'authorName': '作者甲',
  'authorAvatar': '',
  'title': title,
  'content': content,
  'images': <String>[],
  'tags': <String>['go'],
  'status': 1,
  'viewCount': 11,
  'likeCount': 2,
  'commentCount': 7,
  'favoriteCount': 5,
  'isLiked': false,
  'isFavorited': false,
  'createdAt': 1700000000,
};

Map<String, dynamic> _commentJson(
  int id,
  String content, {
  int replyCount = 0,
  List<Map<String, dynamic>> replies = const [],
}) => {
  'id': id,
  'userId': 3,
  'userName': '评论乙',
  'userAvatar': '',
  'parentId': 0,
  'replyUserId': 0,
  'content': content,
  'likeCount': 0,
  'createdAt': 1700000000,
  'replyCount': replyCount,
  'replies': replies,
};

Map<String, dynamic> _replyJson(int id, String content) => {
  'id': id,
  'userId': 4,
  'userName': '回复丙',
  'userAvatar': '',
  'parentId': 55,
  'replyUserId': 3,
  'content': content,
  'likeCount': 0,
  'createdAt': 1700000100,
  'replyCount': 0,
  'replies': <dynamic>[],
};

class _Harness {
  late final ScriptedGatewayClient client;
  bool postDetailOk = true;
  bool commentsOk = true;
  int replyCount = 0;
  List<Map<String, dynamic>> embeddedReplies = const [];

  _Harness() {
    client = ScriptedGatewayClient(route);
  }

  Future<http.Response> route(http.BaseRequest request) async {
    final path = request.url.path;
    if (path == '/api/v1/post/9') {
      return postDetailOk
          ? jsonResponse(okEnvelope(_postJson()))
          : jsonResponse({'code': 500, 'message': '服务器开小差'}, 500);
    }
    if (path == '/api/v1/comments/9') {
      if (!commentsOk) {
        return jsonResponse({'code': 500, 'message': '评论服务不可用'}, 500);
      }
      final hottest = request.url.queryParameters['sortBy'] == '2';
      return jsonResponse(
        okEnvelope({
          'list': [
            _commentJson(
              hottest ? 66 : 55,
              hottest ? '最热内容' : '沙发',
              replyCount: replyCount,
              replies: embeddedReplies,
            ),
          ],
          'total': 1,
          'page': 1,
          'pageSize': 20,
        }),
      );
    }
    if (path == '/api/v1/comments/55/replies' ||
        path == '/api/v1/comments/66/replies') {
      return jsonResponse(
        okEnvelope({
          'list': [
            _replyJson(101, '回复一'),
            _replyJson(102, '回复二'),
            _replyJson(103, '回复三'),
            _replyJson(104, '回复四'),
            _replyJson(105, '回复五'),
          ],
          'total': 5,
          'page': 1,
          'pageSize': 10,
        }),
      );
    }
    if (path == '/api/v1/like' || path == '/api/v1/favorite') {
      return jsonResponse(okEnvelope(<String, dynamic>{}));
    }
    fail('unexpected request: ${request.method} $path');
  }
}

class _AccountSwitchHarness {
  late final ScriptedGatewayClient client;
  final oldResponse = Completer<http.Response>();
  final oldStarted = Completer<void>();
  int postCalls = 0;

  _AccountSwitchHarness() {
    client = ScriptedGatewayClient(route);
  }

  Future<http.Response> route(http.BaseRequest request) async {
    if (request.url.path == '/api/v1/post/9') {
      postCalls++;
      if (postCalls == 1) {
        return jsonResponse(
          okEnvelope(_postJson(title: '匿名帖子', content: '匿名正文')),
        );
      }
      if (postCalls == 2) {
        oldStarted.complete();
        return oldResponse.future;
      }
      if (postCalls == 3) {
        return jsonResponse(
          okEnvelope(_postJson(title: '账号 B 帖子', content: '账号 B 正文')),
        );
      }
    }
    if (request.url.path == '/api/v1/comments/9') {
      return jsonResponse(
        okEnvelope({
          'list': <Map<String, dynamic>>[],
          'total': 0,
          'page': 1,
          'pageSize': 20,
        }),
      );
    }
    fail('unexpected request: ${request.method} ${request.url.path}');
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  GoRouter? router,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: router == null
          ? MaterialApp(builder: foruiTestBuilder, home: page)
          : MaterialApp.router(routerConfig: router, builder: foruiTestBuilder),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  testWidgets('renders the post header, actions and first comment page', (
    tester,
  ) async {
    final harness = _Harness();
    setApiClient(harness.client);

    await _pumpPage(tester, const PostDetailPage(postId: '9'));
    await tester.pumpAndSettle();

    expect(find.text('作者甲'), findsWidgets);
    expect(find.text('联调标题'), findsOneWidget);
    expect(find.text('联调正文'), findsOneWidget);
    expect(find.text('沙发'), findsOneWidget);
    // 点赞、收藏、评论数与浏览数。
    expect(find.text('2'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
  });

  testWidgets('likes optimistically and can toggle back', (tester) async {
    SharedPreferences.setMockInitialValues({
      'tokens': jsonEncode({
        'access_token': _testJwt(userId: 1),
        'access_expire': 0,
        'refresh_token': '',
        'refresh_expire': 0,
        'refresh_after': 0,
      }),
    });
    final harness = _Harness();
    setApiClient(harness.client);

    await _pumpPage(tester, const PostDetailPage(postId: '9'));
    await tester.pumpAndSettle();

    // 操作栏的点赞图标是 size 20；评论项里的点赞图标是 size 14。
    final likeButton = find.byWidgetPredicate(
      (widget) =>
          widget is Icon &&
          widget.icon == FLucideIcons.thumbsUp &&
          widget.size == 20,
    );

    await tester.tap(likeButton);
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    final likeCall = harness.client.requests.firstWhere(
      (r) => r.url.path == '/api/v1/like',
    );
    expect(likeCall.method, 'POST');

    await tester.tap(likeButton);
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    final unlikeCall = harness.client.requests.lastWhere(
      (r) => r.url.path == '/api/v1/like',
    );
    expect(unlikeCall.method, 'DELETE');
  });

  testWidgets('falls back to an error view and recovers on retry', (
    tester,
  ) async {
    final harness = _Harness()..postDetailOk = false;
    setApiClient(harness.client);

    await _pumpPage(tester, const PostDetailPage(postId: '9'));
    await tester.pump();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('服务器开小差'), findsOneWidget);

    harness.postDetailOk = true;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('联调正文'), findsOneWidget);
  });

  testWidgets('switching to hottest refetches comments sorted by likes', (
    tester,
  ) async {
    final harness = _Harness();
    setApiClient(harness.client);

    await _pumpPage(tester, const PostDetailPage(postId: '9'));
    await tester.pumpAndSettle();
    expect(find.text('沙发'), findsOneWidget);

    await tester.tap(find.text('最热'));
    await tester.pumpAndSettle();

    final commentCalls = harness.client.requests
        .where((r) => r.url.path == '/api/v1/comments/9')
        .toList();
    expect(commentCalls, hasLength(2));
    expect(commentCalls[0].url.queryParameters['sortBy'], '1');
    expect(commentCalls[1].url.queryParameters['sortBy'], '2');
    expect(find.text('沙发'), findsNothing);
    expect(find.text('最热内容'), findsOneWidget);
  });

  testWidgets('expands replies on demand and loads the full thread', (
    tester,
  ) async {
    final harness = _Harness()
      ..replyCount = 5
      ..embeddedReplies = [
        _replyJson(101, '回复一'),
        _replyJson(102, '回复二'),
        _replyJson(103, '回复三'),
      ];
    setApiClient(harness.client);

    await _pumpPage(tester, const PostDetailPage(postId: '9'));
    await tester.pumpAndSettle();

    // 未展开：只显示入口，不显示回复内容
    expect(find.text('共 5 条回复'), findsOneWidget);
    expect(find.text('回复一'), findsNothing);

    await tester.tap(find.text('共 5 条回复'));
    await tester.pumpAndSettle();

    // 展开触发楼中楼接口，全量替换内嵌预览
    final replyCall = harness.client.requests.firstWhere(
      (r) => r.url.path == '/api/v1/comments/55/replies',
    );
    expect(replyCall.url.queryParameters['page'], '1');
    expect(find.text('回复一'), findsOneWidget);
    expect(find.text('回复五'), findsOneWidget);
    // 5 条全部可见且 total=5 ≤ pageSize → 无"加载更多"
    expect(find.text('加载更多回复'), findsNothing);

    await tester.tap(find.text('收起回复'));
    await tester.pumpAndSettle();
    expect(find.text('回复一'), findsNothing);
  });

  testWidgets('anonymous comment submission redirects to login', (
    tester,
  ) async {
    final harness = _Harness();
    setApiClient(harness.client);
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (_, _) => const PostDetailPage(postId: '9'),
        ),
        GoRoute(
          path: '/auth/login',
          builder: (_, _) => const Scaffold(body: Text('登录页占位')),
        ),
      ],
    );

    await _pumpPage(tester, const PostDetailPage(postId: '9'), router: router);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).first, '路过留名');
    await tester.tap(find.bySemanticsLabel('发送评论'));
    await tester.pumpAndSettle();

    expect(find.text('登录页占位'), findsOneWidget);
  });

  testWidgets(
    'failed comment loads show a retryable error, not an empty list',
    (tester) async {
      // 回归 FX-001：评论读取失败不得伪装成"还没有评论"。
      final harness = _Harness()..commentsOk = false;
      setApiClient(harness.client);
      // 放大视口让评论区完全可见：排除滚动触发分页对重试按钮的干扰。
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpPage(tester, const PostDetailPage(postId: '9'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('联调正文'), findsOneWidget); // 帖子本体正常
      expect(find.text('还没有评论'), findsNothing);
      expect(find.text('评论加载失败'), findsOneWidget);

      harness.commentsOk = true;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();

      expect(find.text('沙发'), findsOneWidget);
      expect(find.text('评论加载失败'), findsNothing);
    },
  );

  testWidgets('authenticated users can create author and revision watches', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'tokens': jsonEncode({
        'access_token': _testJwt(userId: 1),
        'access_expire': 0,
        'refresh_token': '',
        'refresh_expire': 0,
        'refresh_after': 0,
      }),
    });
    final harness = _Harness();
    setApiClient(harness.client);
    final source = FakeAssistantSource()
      ..granted = true
      ..consentVersion = 2
      ..currentVersion = 2;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [assistantRepositoryProvider.overrideWithValue(source)],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: const PostDetailPage(postId: '9'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('post-watch-author')), findsOneWidget);
    expect(find.byKey(const Key('post-watch-revision')), findsOneWidget);

    await tester.tap(find.byKey(const Key('post-watch-author')));
    await tester.pumpAndSettle();
    expect(source.lastCreateCondition, 'author_new_post');

    await tester.tap(find.byKey(const Key('post-watch-revision')));
    await tester.pumpAndSettle();
    expect(source.lastCreateCondition, 'post_revised');
  });

  testWidgets(
    'account switch replaces post detail and drops the old response',
    (tester) async {
      final harness = _AccountSwitchHarness();
      setApiClient(harness.client);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: foruiTestBuilder,
            home: const PostDetailPage(postId: '9'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('匿名帖子'), findsOneWidget);

      final auth = container.read(authNotifierProvider.notifier);
      await auth.onLoginSuccess(1, 'access-a', refreshToken: 'refresh-a');
      for (var i = 0; i < 20 && !harness.oldStarted.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(harness.oldStarted.isCompleted, isTrue);

      await auth.onLoginSuccess(2, 'access-b', refreshToken: 'refresh-b');
      await tester.pumpAndSettle();
      expect(find.text('账号 B 帖子'), findsOneWidget);

      harness.oldResponse.complete(
        jsonResponse(
          okEnvelope(_postJson(title: '账号 A 帖子', content: '账号 A 正文')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('账号 B 帖子'), findsOneWidget);
      expect(find.text('账号 A 帖子'), findsNothing);
    },
  );
}

String _testJwt({required int userId}) {
  String segment(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${segment({'alg': 'none'})}.${segment({'userId': userId})}.sig';
}
