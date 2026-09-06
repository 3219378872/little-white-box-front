import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/feed/presentation/widgets/post_card.dart';
import 'package:xiaobaihe_app/features/interaction/data/interaction_repository.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';
import 'package:xiaobaihe_app/sdk/data/tokens.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

import '../../../../helpers/forui_test_builder.dart';

void main() {
  PostItem post({int likeCount = 42, bool isLiked = false}) => PostItem(
    id: 1,
    authorId: 1,
    authorName: 'TestUser',
    authorAvatar: '',
    title: 'Hello World',
    content: 'This is a test post',
    images: const [],
    mediaIds: const [],
    tags: const ['test'],
    status: 1,
    likeCount: likeCount,
    isLiked: isLiked,
    isFavorited: false,
    favoriteCount: 0,
    commentCount: 5,
    viewCount: 100,
    revision: 1,
    createdAt: 1700000000,
  );

  Future<void> pumpInteractiveCard(
    WidgetTester tester,
    _TestInteractionRepository repository, {
    bool authenticated = true,
    bool isLiked = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    if (authenticated) {
      await setTokens(
        Tokens(
          accessToken: mockAccessTokenForUser(1),
          accessExpire: 0,
          refreshToken: '',
          refreshExpire: 0,
          refreshAfter: 0,
        ),
      );
    }
    final container = ProviderContainer(
      overrides: [
        postCardInteractionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.read(authNotifierProvider);
    for (
      var i = 0;
      i < 20 && container.read(authNotifierProvider).isLoading;
      i++
    ) {
      await tester.pump();
    }
    expect(container.read(authNotifierProvider).isAuthenticated, authenticated);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: PostCard(post: post(isLiked: isLiked)),
          ),
        ),
        GoRoute(path: '/post/:postId', builder: (_, _) => const Text('详情页')),
        GoRoute(path: '/auth/login', builder: (_, _) => const Text('登录页')),
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
    await tester.pump();
  }

  testWidgets('PostCard renders title and stats', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(body: PostCard(post: post())),
      ),
    );

    expect(find.text('Hello World'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byType(FCard), findsNothing);
  });

  testWidgets('PostCard renders three individual image previews', (
    tester,
  ) async {
    final imagePost = PostItem(
      id: 1,
      authorId: 1,
      authorName: 'TestUser',
      authorAvatar: '',
      title: '',
      content: 'Post with images',
      images: ['http://a.jpg', 'http://b.jpg', 'http://c.jpg'],
      mediaIds: const [],
      tags: [],
      status: 1,
      likeCount: 0,
      isLiked: false,
      isFavorited: false,
      favoriteCount: 0,
      commentCount: 0,
      viewCount: 0,
      revision: 1,
      createdAt: 1700000000,
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(body: PostCard(post: imagePost)),
      ),
    );

    expect(find.bySemanticsLabel(RegExp('3 张图片')), findsWidgets);
    expect(find.text('+2'), findsNothing);
  });

  testWidgets('likes and unlikes without opening the post', (tester) async {
    final repository = _TestInteractionRepository();
    await pumpInteractiveCard(tester, repository);

    expect(find.bySemanticsLabel(RegExp('点赞，当前 42 赞')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('post-like-1')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(repository.likeCalls, 1);
    expect(find.text('43'), findsOneWidget);
    expect(find.text('详情页'), findsNothing);
    expect(find.text('Hello World'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('post-like-1')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(repository.unlikeCalls, 1);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('详情页'), findsNothing);
  });

  testWidgets('uses the API liked state and can unlike from the card', (
    tester,
  ) async {
    final repository = _TestInteractionRepository();
    await pumpInteractiveCard(tester, repository, isLiked: true);

    expect(find.bySemanticsLabel(RegExp('取消点赞，当前 42 赞')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('post-like-1')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(repository.unlikeCalls, 1);
    expect(find.text('41'), findsOneWidget);
    expect(find.text('详情页'), findsNothing);
  });

  testWidgets('blocks repeated likes while pending', (tester) async {
    final repository = _TestInteractionRepository(blockLike: true);
    await pumpInteractiveCard(tester, repository);

    await tester.tap(find.byKey(const ValueKey('post-like-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('post-like-1')));
    await tester.pump();

    expect(repository.likeCalls, 1);
    expect(repository.unlikeCalls, 0);

    repository.completeLike();
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('rolls back the optimistic like when the request fails', (
    tester,
  ) async {
    final repository = _TestInteractionRepository(failLike: true);
    await pumpInteractiveCard(tester, repository);

    await tester.tap(find.byKey(const ValueKey('post-like-1')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('42'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('点赞，当前 42 赞')), findsOneWidget);
    expect(find.text('操作失败: 点赞失败'), findsOneWidget);
  });

  testWidgets('redirects unauthenticated likes to login', (tester) async {
    final repository = _TestInteractionRepository();
    await pumpInteractiveCard(tester, repository, authenticated: false);

    await tester.tap(find.byKey(const ValueKey('post-like-1')));
    await tester.pumpAndSettle();

    expect(repository.likeCalls, 0);
    expect(find.text('登录页'), findsOneWidget);
  });
}

class _TestInteractionRepository extends InteractionRepository {
  final bool failLike;
  final Completer<void>? _likeCompletion;
  int likeCalls = 0;
  int unlikeCalls = 0;

  _TestInteractionRepository({this.failLike = false, bool blockLike = false})
    : _likeCompletion = blockLike ? Completer<void>() : null;

  @override
  Future<void> likeTarget(Object targetId, int targetType) async {
    likeCalls++;
    if (failLike) throw Exception('点赞失败');
    await _likeCompletion?.future;
  }

  @override
  Future<void> unlikeTarget(Object targetId, int targetType) async {
    unlikeCalls++;
  }

  void completeLike() => _likeCompletion?.complete();
}
