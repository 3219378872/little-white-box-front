import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/post/presentation/post_editor_page.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../../helpers/forui_test_builder.dart';
import '../../../helpers/gateway_fake.dart';

Map<String, dynamic> _existingPostJson() => {
  'id': 9,
  'authorId': 2,
  'authorName': '作者甲',
  'authorAvatar': '',
  'title': '原标题',
  'content': '原正文',
  'images': <String>['https://media/old.png'],
  'tags': <String>['go'],
  'status': 1,
  'viewCount': 1,
  'likeCount': 0,
  'commentCount': 0,
  'favoriteCount': 0,
  'isLiked': false,
  'isFavorited': false,
  'revision': 3,
  'createdAt': 1700000000,
};

GoRouter _routerWith(Widget home, {String initial = '/'}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/feed',
        builder: (_, _) => const Scaffold(body: Text('信息流占位')),
      ),
      GoRoute(path: '/create', builder: (_, _) => const PostEditorPage()),
      GoRoute(
        path: '/edit/9',
        builder: (_, _) => const PostEditorPage(postId: '9'),
      ),
    ],
  );
}

class _EditorHome extends StatelessWidget {
  final Widget child;
  const _EditorHome(this.child);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FButton(onPress: () => context.push('/edit/9'), child: child),
      ),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  testWidgets('create mode shows draft and publish actions', (tester) async {
    setApiClient(ScriptedGatewayClient.always(<String, dynamic>{}));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: _routerWith(
            const Scaffold(body: Text('首页占位')),
            initial: '/create',
          ),
          builder: foruiTestBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发布帖子'), findsOneWidget);
    expect(find.text('存草稿'), findsOneWidget);
    expect(find.text('发布'), findsOneWidget);
    expect(find.text('标题'), findsOneWidget);
    expect(find.text('内容'), findsOneWidget);
    expect(find.text('添加标签'), findsOneWidget);
  });

  testWidgets('blocks publishing with an empty title', (tester) async {
    setApiClient(ScriptedGatewayClient.always(<String, dynamic>{}));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: _routerWith(
            const Scaffold(body: Text('首页占位')),
            initial: '/create',
          ),
          builder: foruiTestBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('发布'));
    await tester.pumpAndSettle();

    expect(find.text('标题需为 1～120 个字符'), findsOneWidget);

    // 等 toast 消失，避免残留定时器。
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('publishes a new post and lands on the feed', (tester) async {
    final client = ScriptedGatewayClient((request) async {
      if (request.url.path == '/api/v2/post') {
        return jsonResponse(
          okEnvelope({'postId': 7, 'status': 1, 'revision': 1}),
        );
      }
      fail('unexpected request: ${request.method} ${request.url.path}');
    });
    setApiClient(client);
    final router = _routerWith(
      const Scaffold(body: Text('首页占位')),
      initial: '/create',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(0), '新帖标题');
    await tester.enterText(find.byType(EditableText).at(1), '新帖正文');
    await tester.tap(find.text('发布'));
    await tester.pumpAndSettle();

    final call = client.requests.single as http.Request;
    final body = jsonBodyOf(call);
    expect(call.method, 'POST');
    expect(body['title'], '新帖标题');
    expect(body['status'], 1);
    expect((body['idempotencyKey'] as String), hasLength(16));
    expect(find.text('信息流占位'), findsOneWidget);
  });

  testWidgets('saving a draft submits status=0 through the same contract', (
    tester,
  ) async {
    final client = ScriptedGatewayClient.always({
      'postId': 8,
      'status': 0,
      'revision': 1,
    });
    setApiClient(client);
    final router = _routerWith(
      const Scaffold(body: Text('首页占位')),
      initial: '/create',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(0), '草稿标题');
    await tester.enterText(find.byType(EditableText).at(1), '草稿正文');
    await tester.tap(find.text('存草稿'));
    await tester.pumpAndSettle();

    expect(jsonBodyOf(client.requests.single as http.Request)['status'], 0);
    expect(find.text('信息流占位'), findsOneWidget);
  });

  testWidgets('create retries reuse keys only for the same complete command', (
    tester,
  ) async {
    var attempts = 0;
    final client = ScriptedGatewayClient((request) async {
      attempts++;
      if (attempts < 3) {
        return jsonResponse({'code': 6, 'message': 'temporary'}, 503);
      }
      return jsonResponse(
        okEnvelope({'postId': 7, 'status': 1, 'revision': 1}),
      );
    });
    setApiClient(client);
    final router = _routerWith(
      const Scaffold(body: Text('首页占位')),
      initial: '/create',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(0), '命令 A');
    await tester.enterText(find.byType(EditableText).at(1), '正文');
    await tester.tap(find.text('发布'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发布'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(0), '命令 B');
    await tester.tap(find.text('发布'));
    await tester.pumpAndSettle();

    final bodies = client.requests.map(jsonBodyOf).toList();
    expect(bodies, hasLength(3));
    expect(bodies[0]['idempotencyKey'], bodies[1]['idempotencyKey']);
    expect(bodies[2]['idempotencyKey'], isNot(bodies[1]['idempotencyKey']));
    expect(find.text('信息流占位'), findsOneWidget);
  });

  testWidgets('edit mode prefills the post and updates with expectedRevision', (
    tester,
  ) async {
    final client = ScriptedGatewayClient((request) async {
      final path = request.url.path;
      if (path == '/api/v1/post/9') {
        return jsonResponse(okEnvelope(_existingPostJson()));
      }
      if (path == '/api/v2/post/9') {
        return jsonResponse(okEnvelope({'status': 1, 'revision': 4}));
      }
      fail('unexpected request: ${request.method} $path');
    });
    setApiClient(client);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: _routerWith(const _EditorHome(Text('打开编辑器'))),
          builder: foruiTestBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开编辑器'));
    await tester.pumpAndSettle();

    expect(find.text('编辑帖子'), findsOneWidget);
    expect(find.text('存草稿'), findsNothing);
    // 预填内容来自既有帖子。
    final controllers = tester.widgetList<EditableText>(
      find.byType(EditableText),
    );
    expect(controllers.first.controller.text, '原标题');

    await tester.tap(find.text('发布'));
    await tester.pumpAndSettle();

    final put = client.requests.last as http.Request;
    expect(put.method, 'PUT');
    final body = jsonBodyOf(put);
    expect(put.url.path, '/api/v2/post/9');
    expect(body['expectedRevision'], 3);
    expect(body['images'], ['https://media/old.png']);
    expect(body['tags'], ['go']);
    // 更新成功后返回上一页。
    expect(find.text('打开编辑器'), findsOneWidget);
  });

  testWidgets('adding and removing tags feeds the submit payload', (
    tester,
  ) async {
    final client = ScriptedGatewayClient.always({
      'postId': 7,
      'status': 1,
      'revision': 1,
    });
    setApiClient(client);
    final router = _routerWith(
      const Scaffold(body: Text('首页占位')),
      initial: '/create',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(2), 'flutter');
    await tester.tap(find.bySemanticsLabel('添加标签'));
    await tester.pumpAndSettle();

    expect(find.text('flutter'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).at(0), '带标签的帖子');
    await tester.enterText(find.byType(EditableText).at(1), '正文');
    await tester.tap(find.text('发布'));
    await tester.pumpAndSettle();

    expect(jsonBodyOf(client.requests.single as http.Request)['tags'], [
      'flutter',
    ]);
  });
}
