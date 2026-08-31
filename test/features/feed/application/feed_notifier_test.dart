import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/feed/application/feed_notifier.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_models.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_repository.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads, paginates by cursor, and deduplicates posts', () async {
    final repository = _FakeFeedRepository([
      page([entry(1), entry(2)], requestId: 'request-1', cursor: 'cursor-1'),
      page([entry(2), entry(3)], requestId: 'request-1', hasMore: false),
    ]);
    final notifier = FeedNotifier(
      repository: repository,
      kind: FeedKind.recommend,
      pageSize: 2,
      loadImmediately: false,
    );

    await notifier.loadInitial();
    await notifier.loadMore();

    expect(notifier.state.entries.map((item) => item.post.id), [1, 2, 3]);
    expect(notifier.state.hasMore, isFalse);
    expect(repository.calls[1].requestId, 'request-1');
    expect(repository.calls[1].recommendCursor, 'cursor-1');
    expect(repository.calls[1].positionOffset, 2);
  });

  test('refresh starts a new snapshot without reusing request id', () async {
    final repository = _FakeFeedRepository([
      page([entry(1)], requestId: 'request-1'),
      page([entry(2)], requestId: 'request-2'),
    ]);
    final notifier = FeedNotifier(
      repository: repository,
      kind: FeedKind.recommend,
      loadImmediately: false,
    );

    await notifier.loadInitial();
    await notifier.refresh();

    expect(repository.calls.map((call) => call.requestId), ['', '']);
    expect(notifier.state.requestId, 'request-2');
    expect(notifier.state.entries.single.post.id, 2);
  });

  test('ignores an older initial response after a refresh wins', () async {
    final first = Completer<FeedPageResult>();
    final second = Completer<FeedPageResult>();
    final repository = _CompleterFeedRepository([first, second]);
    final notifier = FeedNotifier(
      repository: repository,
      kind: FeedKind.recommend,
      loadImmediately: false,
    );

    final older = notifier.loadInitial();
    final newer = notifier.refresh();
    second.complete(page([entry(2)], requestId: 'request-2'));
    await newer;
    first.complete(page([entry(1)], requestId: 'request-1'));
    await older;

    expect(notifier.state.requestId, 'request-2');
    expect(notifier.state.entries.single.post.id, 2);
  });

  test('exposes a friendly initial failure', () async {
    final notifier = FeedNotifier(
      repository: _FailingFeedRepository(),
      kind: FeedKind.follow,
      loadImmediately: false,
    );

    await notifier.loadInitial();

    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.error, 'feed failed');
  });

  test('keeps loaded entries when load more fails', () async {
    final notifier = FeedNotifier(
      repository: _SequenceFeedRepository([
        page([entry(1)], requestId: 'request-1'),
        Exception('page 2 failed'),
      ]),
      kind: FeedKind.recommend,
      loadImmediately: false,
    );

    await notifier.loadInitial();
    await notifier.loadMore();

    expect(notifier.state.entries.single.post.id, 1);
    expect(notifier.state.hasMore, isTrue);
    expect(notifier.state.isLoadingMore, isFalse);
    expect(notifier.state.error, 'page 2 failed');
    expect(notifier.state.loadMoreFailed, isTrue);
  });

  test('advances empty hasMore pages until visible items arrive', () async {
    final repository = _FakeFeedRepository([
      page([], requestId: 'request-1', cursor: 'cursor-1'),
      page([entry(9)], requestId: 'request-1', hasMore: false),
    ]);
    final notifier = FeedNotifier(
      repository: repository,
      kind: FeedKind.follow,
      loadImmediately: false,
    );

    await notifier.loadInitial();

    expect(notifier.state.entries.single.post.id, 9);
    expect(repository.calls, hasLength(2));
    expect(repository.calls[1].recommendCursor, 'cursor-1');
  });

  test(
    'refresh failure with items is not treated as load-more failure',
    () async {
      final notifier = FeedNotifier(
        repository: _SequenceFeedRepository([
          page([entry(1)], requestId: 'request-1'),
          Exception('refresh failed'),
        ]),
        kind: FeedKind.recommend,
        loadImmediately: false,
      );

      await notifier.loadInitial();
      await notifier.refresh();

      expect(notifier.state.entries.single.post.id, 1);
      expect(notifier.state.error, 'refresh failed');
      expect(notifier.state.loadMoreFailed, isFalse);
    },
  );

  test(
    'account switch disposes the old feed before its response arrives',
    () async {
      final first = Completer<FeedPageResult>();
      final second = Completer<FeedPageResult>();
      final repository = _CompleterFeedRepository([first, second]);
      final container = ProviderContainer(
        overrides: [feedRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        feedNotifierProvider(FeedKind.follow),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final auth = container.read(authNotifierProvider.notifier);
      await pumpEventQueue();

      await auth.onLoginSuccess(1, 'access-a', refreshToken: 'refresh-a');
      await pumpEventQueue();
      expect(repository.calls, 1);

      await auth.onLoginSuccess(2, 'access-b', refreshToken: 'refresh-b');
      await pumpEventQueue();
      expect(repository.calls, 2);

      second.complete(page([entry(2)], requestId: 'request-b', hasMore: false));
      await pumpEventQueue();
      expect(
        container
            .read(feedNotifierProvider(FeedKind.follow))
            .entries
            .single
            .post
            .id,
        2,
      );

      first.complete(page([entry(1)], requestId: 'request-a', hasMore: false));
      await pumpEventQueue();
      expect(
        container
            .read(feedNotifierProvider(FeedKind.follow))
            .entries
            .single
            .post
            .id,
        2,
      );
    },
  );
}

FeedPageResult page(
  List<FeedEntry> items, {
  required String requestId,
  String cursor = '',
  bool hasMore = true,
}) => FeedPageResult(
  items: items,
  hasMore: hasMore,
  requestId: requestId,
  recommendCursor: cursor,
);

FeedEntry entry(int id) => FeedEntry(
  post: PostItem(
    id: id,
    authorId: 1,
    authorName: 'Author',
    authorAvatar: '',
    title: 'Post $id',
    content: '',
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

class _FeedCall {
  final String requestId;
  final String recommendCursor;
  final int positionOffset;

  const _FeedCall({
    required this.requestId,
    required this.recommendCursor,
    required this.positionOffset,
  });
}

class _FakeFeedRepository implements FeedPageRepository {
  final List<FeedPageResult> responses;
  final List<_FeedCall> calls = [];

  _FakeFeedRepository(this.responses);

  @override
  Future<FeedPageResult> fetchPage({
    required FeedKind kind,
    required int pageSize,
    String requestId = '',
    String recommendCursor = '',
    FollowFeedCursor followCursor = const FollowFeedCursor(),
    int positionOffset = 0,
  }) async {
    calls.add(
      _FeedCall(
        requestId: requestId,
        recommendCursor: recommendCursor,
        positionOffset: positionOffset,
      ),
    );
    return responses.removeAt(0);
  }
}

class _CompleterFeedRepository implements FeedPageRepository {
  final List<Completer<FeedPageResult>> responses;
  int calls = 0;

  _CompleterFeedRepository(this.responses);

  @override
  Future<FeedPageResult> fetchPage({
    required FeedKind kind,
    required int pageSize,
    String requestId = '',
    String recommendCursor = '',
    FollowFeedCursor followCursor = const FollowFeedCursor(),
    int positionOffset = 0,
  }) {
    calls++;
    return responses.removeAt(0).future;
  }
}

class _SequenceFeedRepository implements FeedPageRepository {
  final List<Object> responses;

  _SequenceFeedRepository(this.responses);

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
    throw next as Exception;
  }
}

class _FailingFeedRepository implements FeedPageRepository {
  @override
  Future<FeedPageResult> fetchPage({
    required FeedKind kind,
    required int pageSize,
    String requestId = '',
    String recommendCursor = '',
    FollowFeedCursor followCursor = const FollowFeedCursor(),
    int positionOffset = 0,
  }) {
    throw Exception('feed failed');
  }
}
