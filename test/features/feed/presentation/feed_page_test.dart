import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/feed/application/feed_notifier.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_models.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_repository.dart';
import 'package:xiaobaihe_app/features/feed/presentation/feed_page.dart';
import 'package:xiaobaihe_app/mock/mock_http.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';
import 'package:xiaobaihe_app/sdk/data/tokens.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

import '../../../helpers/forui_test_builder.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetMockState();
    setApiClient(MockHttpClient());
  });

  Future<void> pumpFeed(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(builder: foruiTestBuilder, home: FeedPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('FeedPage shows 推荐 and 关注 tabs', (tester) async {
    await pumpFeed(tester);

    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('关注'), findsOneWidget);
  });

  testWidgets('anonymous follow tab shows a login-required state', (
    tester,
  ) async {
    await pumpFeed(tester);

    await tester.tap(find.text('关注'));
    await pumpFrames(tester, 4);

    expect(find.text('登录后查看关注动态'), findsOneWidget);
    expect(find.text('关注流功能开发中'), findsNothing);
  });

  testWidgets('authenticated follow tab loads the v2 feed', (tester) async {
    await setTokens(
      Tokens(
        accessToken: mockAccessTokenForUser(1),
        accessExpire: 0,
        refreshToken: '',
        refreshExpire: 0,
        refreshAfter: 0,
      ),
    );
    await pumpFeed(tester);

    await tester.tap(find.text('关注'));
    await pumpFrames(tester, 7);

    expect(find.text('探店｜藏在巷子里的宝藏面馆'), findsOneWidget);
    expect(find.text('关注流功能开发中'), findsNothing);
  });

  testWidgets('loads the next cursor page and shows an end footer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedRepositoryProvider.overrideWithValue(
            _QueueFeedRepository([
              feedPage([1, 2], requestId: 'request-1', cursor: 'cursor-1'),
              feedPage([3], requestId: 'request-1', hasMore: false),
            ]),
          ),
        ],
        child: const MaterialApp(builder: foruiTestBuilder, home: FeedPage()),
      ),
    );
    await pumpUntilFound(tester, find.text('Post 1'));
    await pumpUntilFound(tester, find.text('Post 3'));

    expect(find.text('Post 2'), findsOneWidget);
    expect(find.text('— 没有更多了 —'), findsOneWidget);
  });

  testWidgets('scrolls an overflowing feed to load the next page', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 420);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final nextPage = Completer<FeedPageResult>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedRepositoryProvider.overrideWithValue(
            _QueueFeedRepository([
              feedPage([
                1,
                2,
                3,
                4,
                5,
                6,
              ], requestId: 'request-1', cursor: 'cursor-1'),
              nextPage.future,
            ]),
          ),
        ],
        child: const MaterialApp(builder: foruiTestBuilder, home: FeedPage()),
      ),
    );
    await pumpUntilFound(tester, find.text('Post 1'));
    await tester.pump();
    expect(find.text('Post 7'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -2400));
    await tester.pump();
    expect(nextPage.isCompleted, isFalse);
    nextPage.complete(
      feedPage([7], requestId: 'request-1', hasMore: false),
    );
    await pumpUntilFound(tester, find.text('Post 7'));
    await scrollFeedToEnd(tester);
    expect(find.text('— 没有更多了 —'), findsOneWidget);
  });

  testWidgets('keeps loaded posts and retries a failed load more', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedRepositoryProvider.overrideWithValue(
            _QueueFeedRepository([
              feedPage([1], requestId: 'request-1', cursor: 'cursor-1'),
              Exception('page 2 failed'),
              feedPage([2], requestId: 'request-1', hasMore: false),
            ]),
          ),
        ],
        child: const MaterialApp(builder: foruiTestBuilder, home: FeedPage()),
      ),
    );
    await pumpUntilFound(tester, find.text('Post 1'));
    await pumpUntilFound(tester, find.text('page 2 failed'));

    expect(find.text('重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await pumpUntilFound(tester, find.text('Post 2'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('— 没有更多了 —'), findsOneWidget);
  });
}

Future<void> pumpFrames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> scrollFeedToEnd(WidgetTester tester) async {
  final scrollable = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pump();
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('never found $finder');
}

FeedPageResult feedPage(
  List<int> ids, {
  required String requestId,
  String cursor = '',
  bool hasMore = true,
}) => FeedPageResult(
  items: [for (final id in ids) feedEntry(id)],
  hasMore: hasMore,
  requestId: requestId,
  recommendCursor: cursor,
);

FeedEntry feedEntry(int id) => FeedEntry(
  post: PostItem(
    id: id,
    authorId: 1,
    authorName: 'Author',
    authorAvatar: '',
    title: 'Post $id',
    content: 'Body of post $id',
    images: const [],
    tags: const [],
    status: 1,
    viewCount: 0,
    likeCount: 0,
    isLiked: false,
    isFavorited: false,
    favoriteCount: 0,
    commentCount: 0,
    revision: 1,
    createdAt: 1700000000,
  ),
  context: FeedRecommendationContext(
    requestId: 'request',
    scene: 'home',
    position: id,
    recallSource: 'popular',
    modelVersion: 'rule-v1',
    experimentId: '',
  ),
);

class _QueueFeedRepository implements FeedPageRepository {
  final List<Object> responses;

  _QueueFeedRepository(this.responses);

  @override
  Future<FeedPageResult> fetchPage({
    required FeedKind kind,
    required int pageSize,
    String requestId = '',
    String recommendCursor = '',
    FollowFeedCursor followCursor = const FollowFeedCursor(),
    int positionOffset = 0,
  }) async {
    final next = responses.removeAt(0);
    if (next is FeedPageResult) return next;
    if (next is Future<FeedPageResult>) return next;
    throw next as Exception;
  }
}
