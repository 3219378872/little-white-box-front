import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/router/app_route_observer.dart';
import 'package:xiaobaihe_app/features/profile/application/user_posts_notifier.dart';
import 'package:xiaobaihe_app/features/profile/presentation/profile_page.dart';
import 'package:xiaobaihe_app/mock/mock_http.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

import '../../../helpers/forui_test_builder.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setApiClient(MockHttpClient());
  });

  Finder list(String type) => find.byKey(PageStorageKey('profile-2-$type'));
  Finder tab(String label) =>
      find.descendant(of: find.byType(FTabs), matching: find.text(label));

  Future<void> pumpProfile(
    WidgetTester tester, {
    UserPostsRepository? repo,
  }) async {
    final router = GoRouter(
      initialLocation: '/user/2',
      routes: [
        GoRoute(
          path: '/user/:userId',
          builder: (_, state) =>
              ProfilePage(userId: int.parse(state.pathParameters['userId']!)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPostsRepositoryProvider.overrideWithValue(
            repo ?? _TestUserPostsRepository(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    for (var i = 0; i < 30 && find.text('帖子 1').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(list('posts'), findsOneWidget);
    expect(find.text('帖子 1'), findsOneWidget);
  }

  Future<void> finishAnimation(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  ScrollPosition listPosition(WidgetTester tester, String type) {
    final scrollable = find.descendant(
      of: list(type),
      matching: find.byType(Scrollable),
    );
    return tester.state<ScrollableState>(scrollable).position;
  }

  testWidgets('collapses profile, pins tabs, then scrolls the active list', (
    tester,
  ) async {
    await pumpProfile(tester);

    final initialTabTop = tester.getTopLeft(tab('帖子')).dy;
    expect(listPosition(tester, 'posts').pixels, 0);

    await tester.drag(list('posts'), const Offset(0, -160));
    await finishAnimation(tester);

    final collapsingTabTop = tester.getTopLeft(tab('帖子')).dy;
    expect(collapsingTabTop, lessThan(initialTabTop));
    expect(listPosition(tester, 'posts').pixels, 0);

    await tester.drag(list('posts'), const Offset(0, -320));
    await finishAnimation(tester);

    final pinnedTabTop = tester.getTopLeft(tab('帖子')).dy;
    final scrolledListOffset = listPosition(tester, 'posts').pixels;
    expect(pinnedTabTop, lessThan(collapsingTabTop));
    expect(scrolledListOffset, greaterThan(0));

    await tester.drag(list('posts'), const Offset(0, 100));
    await finishAnimation(tester);

    expect(tester.getTopLeft(tab('帖子')).dy, closeTo(pinnedTabTop, 1));
    expect(listPosition(tester, 'posts').pixels, lessThan(scrolledListOffset));

    await tester.drag(list('posts'), const Offset(0, 500));
    await finishAnimation(tester);

    expect(listPosition(tester, 'posts').pixels, 0);
    expect(tester.getTopLeft(tab('帖子')).dy, greaterThan(pinnedTabTop));
  });

  testWidgets('keeps independent scroll positions for posts and favorites', (
    tester,
  ) async {
    await pumpProfile(tester);

    await tester.drag(list('posts'), const Offset(0, -520));
    await finishAnimation(tester);
    final postsOffset = listPosition(tester, 'posts').pixels;
    expect(postsOffset, greaterThan(0));

    await tester.tap(tab('收藏'));
    await finishAnimation(tester);
    expect(listPosition(tester, 'favorites').pixels, 0);

    await tester.drag(list('favorites'), const Offset(0, -180));
    await finishAnimation(tester);
    final favoritesOffset = listPosition(tester, 'favorites').pixels;
    expect(favoritesOffset, greaterThan(0));

    await tester.tap(tab('帖子'));
    await finishAnimation(tester);
    expect(listPosition(tester, 'posts').pixels, closeTo(postsOffset, 1));

    await tester.tap(tab('收藏'));
    await finishAnimation(tester);
    expect(
      listPosition(tester, 'favorites').pixels,
      closeTo(favoritesOffset, 1),
    );
  });

  testWidgets('reloads favorites each time the tab becomes active', (
    tester,
  ) async {
    final repo = _CountingUserPostsRepository();
    await pumpProfile(tester, repo: repo);

    await tester.tap(tab('收藏'));
    await finishAnimation(tester);
    await tester.pump();
    final afterFirstEnter = repo.favoriteCalls;
    expect(afterFirstEnter, greaterThan(0));
    expect(find.text('收藏 1'), findsOneWidget);

    await tester.tap(tab('帖子'));
    await finishAnimation(tester);

    await tester.tap(tab('收藏'));
    await finishAnimation(tester);
    await tester.pump();
    expect(repo.favoriteCalls, greaterThan(afterFirstEnter));
  });

  testWidgets('reloads favorites after returning from a pushed route', (
    tester,
  ) async {
    final repo = _CountingUserPostsRepository();
    final observer = RouteObserver<ModalRoute<void>>();
    final router = GoRouter(
      initialLocation: '/user/2',
      observers: [observer],
      routes: [
        GoRoute(
          path: '/user/:userId',
          builder: (_, state) =>
              ProfilePage(userId: int.parse(state.pathParameters['userId']!)),
        ),
        GoRoute(
          path: '/post/:postId',
          builder: (_, _) => const SizedBox(key: Key('post-stub')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouteObserverProvider.overrideWithValue(observer),
          userPostsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    for (var i = 0; i < 30 && find.text('帖子 1').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(tab('收藏'));
    await finishAnimation(tester);
    await tester.pump();
    final afterEnter = repo.favoriteCalls;
    expect(afterEnter, greaterThan(0));

    router.push('/post/1');
    await finishAnimation(tester);
    expect(find.byKey(const Key('post-stub')), findsOneWidget);

    router.pop();
    await finishAnimation(tester);
    await tester.pump();
    expect(repo.favoriteCalls, greaterThan(afterEnter));
  });
}

class _CountingUserPostsRepository extends _TestUserPostsRepository {
  int favoriteCalls = 0;

  @override
  Future<GetPostListResp> fetchUserFavorites({
    required num userId,
    required int page,
    required int pageSize,
  }) async {
    favoriteCalls++;
    return super.fetchUserFavorites(
      userId: userId,
      page: page,
      pageSize: pageSize,
    );
  }
}

class _TestUserPostsRepository implements UserPostsRepository {
  List<PostItem> _items(String prefix) => List.generate(
    12,
    (index) => PostItem(
      id: index + 1,
      authorId: 2,
      authorName: '测试用户',
      authorAvatar: '',
      title: '$prefix ${index + 1}',
      content: '用于验证个人资料区、吸顶标签栏和帖子列表的连续滚动行为。',
      images: const [],
      tags: const ['测试'],
      status: 1,
      viewCount: index,
      likeCount: index,
      isLiked: false,
      isFavorited: false,
      favoriteCount: 0,
      commentCount: index,
      revision: 1,
      createdAt: 0,
    ),
  );

  GetPostListResp _response(String prefix, int page, int pageSize) {
    final items = page == 1 ? _items(prefix) : <PostItem>[];
    return GetPostListResp(
      list: items,
      total: items.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<GetPostListResp> fetchUserPosts({
    required num userId,
    required int page,
    required int pageSize,
    int sortBy = 1,
  }) async => _response('帖子', page, pageSize);

  @override
  Future<GetPostListResp> fetchUserFavorites({
    required num userId,
    required int page,
    required int pageSize,
  }) async => _response('收藏', page, pageSize);
}
