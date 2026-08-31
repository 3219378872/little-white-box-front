import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/comment/application/comment_notifier.dart';
import 'package:xiaobaihe_app/features/comment/data/comment_repository.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

Map<String, dynamic> _commentJson(int id, {int replyCount = 0}) => {
  'id': id,
  'userId': 3,
  'userName': '评论乙',
  'userAvatar': '',
  'parentId': 0,
  'replyUserId': 0,
  'content': '评论$id',
  'likeCount': 0,
  'createdAt': 1700000000,
  'replyCount': replyCount,
  'replies': <Map<String, dynamic>>[],
};

class _FakeCommentRepository implements CommentRepository {
  final List<List<Map<String, dynamic>>> pages;
  final List<List<Map<String, dynamic>>> replyPages;
  final List<String> calls = [];
  final List<String> idempotencyKeys = [];
  final List<CreateCommentReq> createCommands = [];
  Object? failRepliesFor;
  Object? failCreate;
  int _replyPageIndex = 0;

  _FakeCommentRepository({
    required this.pages,
    this.replyPages = const [],
    this.failRepliesFor,
  });

  @override
  Future<GetCommentListResp> fetchComments({
    required Object postId,
    required int page,
    required int pageSize,
    required int sortBy,
  }) async {
    calls.add('list:$page:$sortBy');
    if (page > pages.length) {
      return GetCommentListResp.fromJson({
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': page,
        'pageSize': pageSize,
      });
    }
    final list = pages[page - 1];
    return GetCommentListResp.fromJson({
      'list': list,
      'total': list.length,
      'page': page,
      'pageSize': pageSize,
    });
  }

  @override
  Future<GetCommentRepliesResp> fetchReplies({
    required Object commentId,
    required int page,
    required int pageSize,
  }) async {
    calls.add('replies:$page');
    if (failRepliesFor == commentId) {
      throw Exception('replies failed');
    }
    final list = replyPages[_replyPageIndex.clamp(0, replyPages.length - 1)];
    _replyPageIndex++;
    return GetCommentRepliesResp.fromJson({
      'list': list,
      'total': list.length,
      'page': page,
      'pageSize': pageSize,
    });
  }

  @override
  Future<CreateCommentResp> createNewComment(CreateCommentReq req) async {
    calls.add('create:${req.content}');
    idempotencyKeys.add(req.idempotencyKey);
    createCommands.add(req);
    if (failCreate != null) {
      final error = failCreate!;
      failCreate = null;
      throw error;
    }
    return CreateCommentResp.fromJson({'commentId': 777});
  }

  @override
  Future<void> deleteExistingComment(Object commentId) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('首屏加载、触底翻页与去重', () async {
    final repo = _FakeCommentRepository(
      pages: [
        [_commentJson(1), ...List.generate(19, (i) => _commentJson(100 + i))],
        [_commentJson(3)],
      ],
    );
    final notifier = CommentNotifier(
      repository: repo,
      postId: '9',
      loadImmediately: false,
    );

    await notifier.loadInitial();
    expect(notifier.state.comments.first.id, 1);
    // 满页 20 条 → 还有更多
    expect(notifier.state.hasMore, isTrue);

    await notifier.loadMore();
    expect(notifier.state.comments.length, 21);
    // 第二页不满页 → 没有更多
    expect(notifier.state.hasMore, isFalse);
    expect(notifier.state.isLoading, isFalse);
  });

  test('加载失败保留可重试错误态且不伪装空区', () async {
    final failing = _FailingListRepository();
    final notifier = CommentNotifier(
      repository: failing,
      postId: '9',
      loadImmediately: false,
    );
    await notifier.loadInitial();
    expect(notifier.state.hasError, isTrue);
    expect(notifier.state.comments, isEmpty);
    expect(notifier.state.isLoading, isFalse);
  });

  test('切排序从第 1 页重建', () async {
    final repo = _FakeCommentRepository(
      pages: [
        [_commentJson(1)],
        [_commentJson(2)],
      ],
    );
    final notifier = CommentNotifier(
      repository: repo,
      postId: '9',
      loadImmediately: false,
    );
    await notifier.loadInitial();
    await notifier.loadMore();

    await notifier.selectSort(2);
    expect(notifier.state.sortBy, 2);
    expect(notifier.state.comments.map((c) => c.id), [1]);
    expect(repo.calls.last, 'list:1:2');
  });

  test('楼中楼展开拉取、去重与失败回滚 loading', () async {
    final repo = _FakeCommentRepository(
      pages: [
        [_commentJson(55, replyCount: 2)],
      ],
      replyPages: [
        [_commentJson(101), _commentJson(101)], // 重复 id 触发去重
      ],
    );
    final notifier = CommentNotifier(
      repository: repo,
      postId: '9',
      loadImmediately: false,
    );
    await notifier.loadInitial();
    final comment = notifier.state.comments.first;

    await notifier.toggleReplies(comment);
    expect(notifier.state.expandedReplies, contains('55'));
    expect(notifier.state.threadReplies['55']!.map((r) => r.id), [101]);
    expect(notifier.state.loadingReplies, isEmpty);

    // 收起
    await notifier.toggleReplies(comment);
    expect(notifier.state.expandedReplies, isNot(contains('55')));
  });

  test('楼中楼首次展开失败时保持展开态并抛出', () async {
    final repo = _FakeCommentRepository(
      pages: [
        [_commentJson(55, replyCount: 2)],
      ],
      failRepliesFor: 55,
    );
    final notifier = CommentNotifier(
      repository: repo,
      postId: '9',
      loadImmediately: false,
    );
    await notifier.loadInitial();
    final comment = notifier.state.comments.first;

    await expectLater(notifier.toggleReplies(comment), throwsException);
    expect(notifier.state.loadingReplies, isEmpty);
  });

  test('submit 成功后清空回复目标并刷新第一页', () async {
    final repo = _FakeCommentRepository(
      pages: [
        [_commentJson(1)],
      ],
    );
    final notifier = CommentNotifier(
      repository: repo,
      postId: '9',
      loadImmediately: false,
    );
    await notifier.loadInitial();

    notifier.setReplyTarget(userName: '评论乙', parentId: 1, userId: 3);
    await notifier.submit('新回复');

    expect(notifier.state.replyToUser, isNull);
    expect(notifier.state.replyParentId, 0);
    expect(notifier.state.replyUserId, 0);
    expect(repo.calls.contains('create:新回复'), isTrue);
    // 初始加载 + 提交成功后的刷新，各拉一次第 1 页
    expect(repo.calls.where((c) => c.startsWith('list:')), [
      'list:1:1',
      'list:1:1',
    ]);
  });

  test('分页失败进入可重试错误态，重试续拉下一页', () async {
    final repo = _PagingThenFailRepository();
    final notifier = CommentNotifier(
      repository: repo,
      postId: '9',
      loadImmediately: false,
    );
    await notifier.loadInitial();
    expect(notifier.state.comments, hasLength(20));
    expect(notifier.state.hasMore, isTrue);

    await notifier.loadMore();
    expect(notifier.state.hasError, isTrue);
    expect(notifier.state.comments, hasLength(20));

    await notifier.retry();
    expect(notifier.state.hasError, isFalse);
    expect(notifier.state.comments, hasLength(21));
    expect(repo.calls.where((c) => c.startsWith('list:')), [
      'list:1:1',
      'list:2:1',
      'list:2:1',
    ]);
  });

  test('同一失败评论重试复用幂等键', () async {
    final repo = _FakeCommentRepository(
      pages: [
        [_commentJson(1)],
      ],
    )..failCreate = Exception('create failed');
    final notifier = CommentNotifier(
      repository: repo,
      postId: '9',
      loadImmediately: false,
    );
    await notifier.loadInitial();

    await expectLater(notifier.submit('同一条'), throwsException);
    await notifier.submit('同一条');

    expect(repo.idempotencyKeys, hasLength(2));
    expect(repo.idempotencyKeys[0], repo.idempotencyKeys[1]);
    expect(repo.idempotencyKeys[0], isNotEmpty);
  });

  test('改变回复目标后不复用失败命令的幂等键', () async {
    final repo = _FakeCommentRepository(
      pages: [
        [_commentJson(1)],
      ],
    )..failCreate = Exception('create failed');
    final notifier = CommentNotifier(
      repository: repo,
      postId: '9',
      loadImmediately: false,
    );
    await notifier.loadInitial();

    notifier.setReplyTarget(userName: '甲', parentId: 1, userId: 3);
    await expectLater(notifier.submit('相同正文'), throwsException);
    notifier.setReplyTarget(userName: '乙', parentId: 2, userId: 4);
    await notifier.submit('相同正文');

    expect(repo.idempotencyKeys, hasLength(2));
    expect(repo.idempotencyKeys[0], isNot(repo.idempotencyKeys[1]));
    expect(repo.createCommands.map((command) => command.parentId), [1, 2]);
  });

  test(
    'account switch disposes the old comment state and late response',
    () async {
      final first = Completer<GetCommentListResp>();
      final second = Completer<GetCommentListResp>();
      final repo = _DelayedListRepository([first, second]);
      final container = ProviderContainer(
        overrides: [commentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final auth = container.read(authNotifierProvider.notifier);
      await auth.onLoginSuccess(1, 'access-a', refreshToken: 'refresh-a');
      final subscription = container.listen(
        commentNotifierProvider('9'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await pumpEventQueue();
      expect(repo.calls, hasLength(1));

      await auth.onLoginSuccess(2, 'access-b', refreshToken: 'refresh-b');
      await pumpEventQueue();
      expect(repo.calls, hasLength(2));

      second.complete(_commentPage(2));
      await pumpEventQueue();
      expect(
        container.read(commentNotifierProvider('9')).comments.single.id,
        2,
      );

      first.complete(_commentPage(1));
      await pumpEventQueue();
      expect(
        container.read(commentNotifierProvider('9')).comments.single.id,
        2,
      );
    },
  );
}

GetCommentListResp _commentPage(int id) => GetCommentListResp.fromJson({
  'list': [_commentJson(id)],
  'total': 1,
  'page': 1,
  'pageSize': 20,
});

class _DelayedListRepository extends _FakeCommentRepository {
  final List<Completer<GetCommentListResp>> responses;

  _DelayedListRepository(this.responses) : super(pages: const []);

  @override
  Future<GetCommentListResp> fetchComments({
    required Object postId,
    required int page,
    required int pageSize,
    required int sortBy,
  }) {
    calls.add('list:$page:$sortBy');
    return responses.removeAt(0).future;
  }
}

class _PagingThenFailRepository extends _FakeCommentRepository {
  var _failNext = false;

  _PagingThenFailRepository()
    : super(
        pages: [
          List.generate(20, (i) => _commentJson(100 + i)),
          [_commentJson(3)],
        ],
      );

  @override
  Future<GetCommentListResp> fetchComments({
    required Object postId,
    required int page,
    required int pageSize,
    required int sortBy,
  }) async {
    calls.add('list:$page:$sortBy');
    if (page == 2 && !_failNext) {
      _failNext = true;
      throw Exception('page 2 failed');
    }
    if (page > pages.length) {
      return GetCommentListResp.fromJson({
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': page,
        'pageSize': pageSize,
      });
    }
    final list = pages[page - 1];
    return GetCommentListResp.fromJson({
      'list': list,
      'total': list.length,
      'page': page,
      'pageSize': pageSize,
    });
  }
}

class _FailingListRepository extends _FakeCommentRepository {
  _FailingListRepository() : super(pages: []);

  @override
  Future<GetCommentListResp> fetchComments({
    required Object postId,
    required int page,
    required int pageSize,
    required int sortBy,
  }) async {
    throw Exception('list failed');
  }
}
