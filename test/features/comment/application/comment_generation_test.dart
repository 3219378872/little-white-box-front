import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/comment/application/comment_notifier.dart';
import 'package:xiaobaihe_app/features/comment/data/comment_repository.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

class _DelayedComments implements CommentRepository {
  final requests = <Completer<GetCommentListResp>>[];
  final sorts = <int>[];
  final pages = <int>[];
  final replies = <Completer<GetCommentRepliesResp>>[];

  @override
  Future<GetCommentRepliesResp> fetchReplies({
    required Object commentId,
    required int page,
    required int pageSize,
  }) {
    final pending = Completer<GetCommentRepliesResp>();
    replies.add(pending);
    return pending.future;
  }

  @override
  Future<GetCommentListResp> fetchComments({
    required Object postId,
    required int page,
    required int pageSize,
    required int sortBy,
  }) {
    final pending = Completer<GetCommentListResp>();
    requests.add(pending);
    sorts.add(sortBy);
    pages.add(page);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GetCommentListResp _comments(int id, {int count = 1}) =>
    GetCommentListResp.fromJson({
      'list': List.generate(
        count,
        (index) => {
          'id': id + index,
          'userId': 3,
          'userName': 'user',
          'userAvatar': '',
          'parentId': 0,
          'replyUserId': 0,
          'content': '$id',
          'likeCount': 0,
          'createdAt': 1700000000,
          'replyCount': 0,
          'replies': [],
        },
      ),
      'total': count,
      'page': 1,
      'pageSize': 20,
    });

void main() {
  for (final count in [1, 20]) {
    test(
      'failed refresh retries page one with $count retained comments',
      () async {
        final repository = _DelayedComments();
        final notifier = CommentNotifier(
          repository: repository,
          postId: '9',
          loadImmediately: false,
        );
        addTearDown(notifier.dispose);
        final initial = notifier.loadInitial();
        repository.requests[0].complete(_comments(1, count: count));
        await initial;
        final refresh = notifier.loadInitial();
        repository.requests[1].completeError(StateError('offline'));
        await refresh;
        expect(notifier.state.comments, hasLength(count));
        final retry = notifier.retry();
        expect(repository.pages, [1, 1, 1]);
        repository.requests.last.complete(_comments(100));
        await retry;
        expect(notifier.state.comments.single.id, 100);
        expect(notifier.state.hasError, isFalse);
      },
    );
  }

  test('failed pagination retries the same next page', () async {
    final repository = _DelayedComments();
    final notifier = CommentNotifier(
      repository: repository,
      postId: '9',
      loadImmediately: false,
    );
    addTearDown(notifier.dispose);
    final initial = notifier.loadInitial();
    repository.requests[0].complete(_comments(1, count: 20));
    await initial;
    final more = notifier.loadMore();
    repository.requests[1].completeError(StateError('offline'));
    await more;
    final retry = notifier.retry();
    expect(repository.pages, [1, 2, 2]);
    repository.requests.last.complete(_comments(21));
    await retry;
    expect(
      notifier.state.comments.map((c) => c.id),
      List.generate(21, (i) => i + 1),
    );
  });

  for (final failOld in [false, true]) {
    test(
      'reopened reply thread ignores stale ${failOld ? 'error' : 'success'}',
      () async {
        final repository = _DelayedComments();
        final notifier = CommentNotifier(
          repository: repository,
          postId: '9',
          loadImmediately: false,
        );
        addTearDown(notifier.dispose);
        final parent = _comments(1).list.single;
        final old = notifier.toggleReplies(parent);
        await notifier.toggleReplies(parent);
        final current = notifier.toggleReplies(parent);
        if (failOld) {
          repository.replies[0].completeError(StateError('old failure'));
        } else {
          repository.replies[0].complete(
            GetCommentRepliesResp.fromJson({
              'list': [
                {'id': 2},
              ],
            }),
          );
        }
        await old;
        expect(notifier.state.loadingReplies, contains('1'));
        expect(notifier.state.threadReplies['1'], isNull);
        repository.replies[1].complete(
          GetCommentRepliesResp.fromJson({
            'list': [
              {'id': 3},
            ],
          }),
        );
        await current;
        expect(notifier.state.threadReplies['1']!.single.id, 3);
        expect(notifier.state.loadingReplies, isEmpty);
      },
    );
  }

  test(
    'old reply response cannot overwrite the completed reopened thread',
    () async {
      final repository = _DelayedComments();
      final notifier = CommentNotifier(
        repository: repository,
        postId: '9',
        loadImmediately: false,
      );
      addTearDown(notifier.dispose);
      final parent = _comments(1).list.single;
      final old = notifier.toggleReplies(parent);
      await notifier.toggleReplies(parent);
      final current = notifier.toggleReplies(parent);
      repository.replies[1].complete(
        GetCommentRepliesResp.fromJson({
          'list': [
            {'id': 3},
          ],
        }),
      );
      await current;
      repository.replies[0].complete(
        GetCommentRepliesResp.fromJson({
          'list': [
            {'id': 2},
          ],
        }),
      );
      await old;
      expect(notifier.state.threadReplies['1']!.single.id, 3);
    },
  );

  for (final failOld in [false, true]) {
    test(
      'new sort ignores old initial ${failOld ? 'failure' : 'success'}',
      () async {
        final repository = _DelayedComments();
        final notifier = CommentNotifier(
          repository: repository,
          postId: '9',
          loadImmediately: false,
        );
        addTearDown(notifier.dispose);
        final initial = notifier.loadInitial();
        final sorted = notifier.selectSort(2);
        repository.requests[1].complete(_comments(2));
        await sorted;
        if (failOld) {
          repository.requests[0].completeError(StateError('old failure'));
        } else {
          repository.requests[0].complete(_comments(1));
        }
        await initial;
        expect(notifier.state.comments.single.id, 2);
        expect(notifier.state.sortBy, 2);
        expect(notifier.state.hasError, isFalse);
        expect(notifier.state.isLoading, isFalse);
      },
    );
  }
  test(
    'old pagination cannot mix into new sort or advance its cursor',
    () async {
      final repository = _DelayedComments();
      final notifier = CommentNotifier(
        repository: repository,
        postId: '9',
        loadImmediately: false,
      );
      addTearDown(notifier.dispose);
      final initial = notifier.loadInitial();
      repository.requests[0].complete(_comments(1, count: 20));
      await initial;
      final older = notifier.loadMore();
      final sorted = notifier.selectSort(2);
      repository.requests[2].complete(_comments(100, count: 20));
      await sorted;
      repository.requests[1].complete(_comments(21));
      await older;
      expect(notifier.state.comments.first.id, 100);
      expect(notifier.state.comments.length, 20);
      final next = notifier.loadMore();
      expect(repository.pages.last, 2);
      expect(repository.sorts.last, 2);
      repository.requests.last.complete(_comments(120));
      await next;
    },
  );
}
