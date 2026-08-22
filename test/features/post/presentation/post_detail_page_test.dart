import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/widgets/error_view.dart';
import 'package:xiaobaihe_app/features/post/presentation/post_detail_page.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../../helpers/forui_test_builder.dart';
import '../../../helpers/gateway_fake.dart';

Map<String, dynamic> _postJson() => {
      'id': 9,
      'authorId': 2,
      'authorName': '作者甲',
      'authorAvatar': '',
      'title': '联调标题',
      'content': '联调正文',
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

Map<String, dynamic> _commentJson(int id, String content) => {
      'id': id,
      'userId': 3,
      'userName': '评论乙',
      'userAvatar': '',
      'parentId': 0,
      'replyUserId': 0,
      'content': content,
      'likeCount': 0,
      'createdAt': 1700000000,
    };

class _Harness {
  late final ScriptedGatewayClient client;
  bool postDetailOk = true;

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
      final hottest = request.url.queryParameters['sortBy'] == '2';
      return jsonResponse(okEnvelope({
        'list': [_commentJson(hottest ? 66 : 55, hottest ? '最热内容' : '沙发')],
        'total': 1,
        'page': 1,
        'pageSize': 20,
      }));
    }
    if (path == '/api/v1/like' || path == '/api/v1/favorite') {
      return jsonResponse(okEnvelope(<String, dynamic>{}));
    }
    fail('unexpected request: ${request.method} $path');
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
          : MaterialApp.router(
              routerConfig: router,
              builder: foruiTestBuilder,
            ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  testWidgets('renders the post header, actions and first comment page',
      (tester) async {
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

  testWidgets('falls back to an error view and recovers on retry',
      (tester) async {
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

  testWidgets('switching to hottest refetches comments sorted by likes',
      (tester) async {
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

  testWidgets('anonymous comment submission redirects to login',
      (tester) async {
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

    await _pumpPage(
      tester,
      const PostDetailPage(postId: '9'),
      router: router,
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).first, '路过留名');
    await tester.tap(find.bySemanticsLabel('发送评论'));
    await tester.pumpAndSettle();

    expect(find.text('登录页占位'), findsOneWidget);
  });
}
