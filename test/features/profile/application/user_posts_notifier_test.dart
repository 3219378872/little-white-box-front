import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/profile/application/user_posts_notifier.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

/// Fake Repository
class _FakeUserPostsRepo implements UserPostsRepository {
  List<GetPostListResp> pages = [];
  int calls = 0;
  bool shouldFail = false;
  String failReason = 'boom';

  void addPage(List<PostItem> items, {int total = 100}) {
    pages.add(
      GetPostListResp(
        list: items,
        total: total,
        page: pages.length + 1,
        pageSize: items.length,
      ),
    );
  }

  @override
  Future<GetPostListResp> fetchUserPosts({
    required Object userId,
    required int page,
    required int pageSize,
    int sortBy = 1,
  }) async {
    calls++;
    if (shouldFail) throw Exception(failReason);
    final idx = page - 1;
    if (idx >= pages.length) {
      return GetPostListResp(
        list: [],
        total: 100,
        page: page,
        pageSize: pageSize,
      );
    }
    return pages[idx];
  }

  @override
  Future<GetPostListResp> fetchUserFavorites({
    required Object userId,
    required int page,
    required int pageSize,
  }) async {
    return fetchUserPosts(userId: userId, page: page, pageSize: pageSize);
  }
}

class _QueuedUserPostsRepo implements UserPostsRepository {
  final pending = <Completer<GetPostListResp>>[];

  void completeNext(List<PostItem> items) {
    _complete(pending.removeAt(0), items);
  }

  void completeLast(List<PostItem> items) {
    _complete(pending.removeLast(), items);
  }

  void _complete(Completer<GetPostListResp> completer, List<PostItem> items) {
    completer.complete(
      GetPostListResp(
        list: items,
        total: items.length,
        page: 1,
        pageSize: 20,
      ),
    );
  }

  Future<GetPostListResp> _enqueue() {
    final completer = Completer<GetPostListResp>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<GetPostListResp> fetchUserPosts({
    required Object userId,
    required int page,
    required int pageSize,
    int sortBy = 1,
  }) {
    return _enqueue();
  }

  @override
  Future<GetPostListResp> fetchUserFavorites({
    required Object userId,
    required int page,
    required int pageSize,
  }) {
    return _enqueue();
  }
}

PostItem _post(num id) {
  return PostItem(
    id: id,
    authorId: 1,
    authorName: 'u',
    authorAvatar: '',
    title: 't$id',
    content: 'c',
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
    createdAt: 0,
  );
}

void main() {
  group('UserPostsNotifier', () {
    late _FakeUserPostsRepo repo;

    setUp(() {
      repo = _FakeUserPostsRepo();
    });

    test('loadFirstPage 成功时填充 items', () async {
      repo.addPage([_post(1), _post(2)]);
      final n = UserPostsNotifier(
        repo: repo,
        key: const UserPostsKey(userId: 1, type: UserPostsListType.posts),
      );
      await n.loadFirstPage();
      expect(n.state.items.length, 2);
      expect(n.state.page, 1);
      expect(n.state.hasMore, isFalse);
      expect(n.state.error, isNull);
    });

    test('loadNextPage 追加 items 而非覆盖', () async {
      repo.addPage(List.generate(20, (i) => _post(i + 1)));
      repo.addPage([_post(21), _post(22)]);
      final n = UserPostsNotifier(
        repo: repo,
        key: const UserPostsKey(userId: 1, type: UserPostsListType.posts),
      );
      await n.loadFirstPage();
      expect(n.state.items.length, 20);
      expect(n.state.hasMore, isTrue);

      await n.loadNextPage();
      expect(n.state.items.length, 22);
      expect(n.state.hasMore, isFalse);
      expect(n.state.page, 2);
    });

    test('loadNextPage 在 hasMore=false 时不发请求', () async {
      repo.addPage([_post(1)]);
      final n = UserPostsNotifier(
        repo: repo,
        key: const UserPostsKey(userId: 1, type: UserPostsListType.posts),
      );
      await n.loadFirstPage();
      final callsBefore = repo.calls;
      await n.loadNextPage();
      expect(repo.calls, callsBefore);
    });

    test('refresh 成功时重置 page=1 并覆盖 items', () async {
      repo.addPage([_post(1), _post(2)]);
      final n = UserPostsNotifier(
        repo: repo,
        key: const UserPostsKey(userId: 1, type: UserPostsListType.posts),
      );
      await n.loadFirstPage();
      repo.pages.clear();
      repo.addPage([_post(99)]);
      await n.refresh();
      expect(n.state.items.length, 1);
      expect(n.state.items.first.id, 99);
      expect(n.state.page, 1);
    });

    test('refresh 失败时保留旧数据', () async {
      repo.addPage([_post(1), _post(2)]);
      final n = UserPostsNotifier(
        repo: repo,
        key: const UserPostsKey(userId: 1, type: UserPostsListType.posts),
      );
      await n.loadFirstPage();
      repo.shouldFail = true;
      await n.refresh();
      expect(n.state.items.length, 2);
      expect(n.state.isRefreshing, isFalse);
    });

    test('loadFirstPage 失败时设置 error 字段', () async {
      repo.shouldFail = true;
      final n = UserPostsNotifier(
        repo: repo,
        key: const UserPostsKey(userId: 1, type: UserPostsListType.posts),
      );
      await n.loadFirstPage();
      expect(n.state.error, isNotNull);
      expect(n.state.items, isEmpty);
    });

    test('较新的 refresh 会丢弃进行中的 loadFirstPage', () async {
      final queued = _QueuedUserPostsRepo();
      final n = UserPostsNotifier(
        repo: queued,
        key: const UserPostsKey(userId: 1, type: UserPostsListType.posts),
      );
      final first = n.loadFirstPage();
      final refresh = n.refresh();
      queued.completeLast([_post(99)]);
      await refresh;
      expect(n.state.items.single.id, 99);
      queued.completeNext([_post(1), _post(2)]);
      await first;
      expect(n.state.items.single.id, 99);
      expect(n.state.isLoading, isFalse);
      expect(n.state.isRefreshing, isFalse);
    });
  });

  group('UserPostsKey', () {
    test('同参数相等、hashCode 相同', () {
      const k1 = UserPostsKey(userId: 1, type: UserPostsListType.posts);
      const k2 = UserPostsKey(userId: 1, type: UserPostsListType.posts);
      expect(k1, equals(k2));
      expect(k1.hashCode, k2.hashCode);
    });

    test('不同 type 不相等', () {
      const k1 = UserPostsKey(userId: 1, type: UserPostsListType.posts);
      const k2 = UserPostsKey(userId: 1, type: UserPostsListType.favorites);
      expect(k1, isNot(equals(k2)));
    });
  });
}
