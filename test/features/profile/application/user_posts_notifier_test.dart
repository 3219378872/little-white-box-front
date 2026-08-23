import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/profile/application/user_posts_notifier.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

/// Fake Repository：以游标令牌 `c<index+1>` 链接各页。
class _FakeUserPostsRepo implements UserPostsRepository {
  List<GetPostListResp> pages = [];
  final seenCursors = <String>[];
  int calls = 0;
  bool shouldFail = false;
  String failReason = 'boom';

  void addPage(List<PostItem> items, {bool hasMore = false}) {
    pages.add(
      GetPostListResp(
        list: items,
        nextCursor: hasMore ? 'c${pages.length + 2}' : '',
      ),
    );
  }

  GetPostListResp _pageFor(String cursor) {
    if (cursor.isEmpty && pages.isNotEmpty) return pages.first;
    final idx = int.parse(cursor.substring(1)) - 1;
    if (idx < 0 || idx >= pages.length) {
      return GetPostListResp(list: const [], nextCursor: '');
    }
    return pages[idx];
  }

  @override
  Future<GetPostListResp> fetchUserPosts({
    required Object userId,
    required String cursor,
    required int pageSize,
    int sortBy = 1,
  }) async {
    calls++;
    seenCursors.add(cursor);
    if (shouldFail) throw Exception(failReason);
    return _pageFor(cursor);
  }

  @override
  Future<GetPostListResp> fetchUserFavorites({
    required Object userId,
    required String cursor,
    required int pageSize,
  }) async {
    return fetchUserPosts(userId: userId, cursor: cursor, pageSize: pageSize);
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
    completer.complete(GetPostListResp(list: items, nextCursor: ''));
  }

  Future<GetPostListResp> _enqueue() {
    final completer = Completer<GetPostListResp>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<GetPostListResp> fetchUserPosts({
    required Object userId,
    required String cursor,
    required int pageSize,
    int sortBy = 1,
  }) {
    return _enqueue();
  }

  @override
  Future<GetPostListResp> fetchUserFavorites({
    required Object userId,
    required String cursor,
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
      expect(n.state.cursor, '');
      expect(n.state.hasMore, isFalse);
      expect(n.state.error, isNull);
    });

    test('loadNextPage 追加 items 而非覆盖', () async {
      repo.addPage(List.generate(20, (i) => _post(i + 1)), hasMore: true);
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
      // 翻页请求必须携带上一页返回的游标。
      expect(repo.seenCursors, ['', 'c2']);
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

    test('refresh 成功时重置游标并覆盖 items', () async {
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
      expect(n.state.cursor, '');
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
