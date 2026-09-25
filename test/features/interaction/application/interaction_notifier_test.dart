import 'dart:async';

import 'package:xiaobaihe_app/core/state/app_provider_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/interaction/application/interaction_notifier.dart';
import 'package:xiaobaihe_app/features/interaction/data/interaction_repository.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

GetPostResp _post({bool isLiked = false, bool isFavorited = false}) {
  return GetPostResp.fromJson({
    'id': 9,
    'authorId': 2,
    'authorName': '作者甲',
    'authorAvatar': '',
    'title': 't',
    'content': 'c',
    'images': <String>[],
    'tags': <String>[],
    'status': 1,
    'viewCount': 1,
    'likeCount': 10,
    'commentCount': 0,
    'favoriteCount': 5,
    'isLiked': isLiked,
    'isFavorited': isFavorited,
    'createdAt': 1700000000,
  });
}

class _FakeInteractionRepository implements InteractionRepository {
  final List<String> calls = [];
  final Set<String> failOn;

  _FakeInteractionRepository({this.failOn = const {}});

  void _record(String op, Object targetId) {
    calls.add('$op:$targetId');
    if (failOn.contains(op)) {
      throw Exception('$op failed');
    }
  }

  @override
  Future<void> likeTarget(Object targetId, int targetType) async =>
      _record('like', targetId);

  @override
  Future<void> unlikeTarget(Object targetId, int targetType) async =>
      _record('unlike', targetId);

  @override
  Future<void> favoritePost(Object postId) async => _record('favorite', postId);

  @override
  Future<void> unfavoritePost(Object postId) async =>
      _record('unfavorite', postId);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('toggleLike 乐观翻转并对账计数，成功后保持', () async {
    final repo = _FakeInteractionRepository();
    final notifier = InteractionNotifier(repository: repo);
    final post = _post();

    await notifier.toggleLike(post);
    expect(notifier.state.optimisticIsLiked, isTrue);
    expect(notifier.state.likeCountFor(count: 10, isLiked: false), 11);
    expect(repo.calls, ['like:9']);

    await notifier.toggleLike(post);
    expect(notifier.state.optimisticIsLiked, isFalse);
    expect(notifier.state.likeCountFor(count: 10, isLiked: false), 10);
    expect(repo.calls, ['like:9', 'unlike:9']);
  });

  test('toggleLike 失败回滚并抛出', () async {
    final repo = _FakeInteractionRepository(failOn: {'like'});
    final notifier = InteractionNotifier(repository: repo);
    final post = _post();

    await expectLater(notifier.toggleLike(post), throwsException);
    expect(notifier.state.optimisticIsLiked, isNull);
    expect(notifier.state.likeCountFor(count: 10, isLiked: false), 10);
  });

  test('toggleFavorite 基于服务端初值做乐观更新', () async {
    final repo = _FakeInteractionRepository();
    final notifier = InteractionNotifier(repository: repo);
    final post = _post(isFavorited: true);

    await notifier.toggleFavorite(post);
    expect(notifier.state.optimisticIsFavorited, isFalse);
    expect(notifier.state.favoriteCountFor(count: 5, isFavorited: true), 4);
    expect(repo.calls, ['unfavorite:9']);
  });

  test('toggleFavorite 失败回滚并抛出', () async {
    final repo = _FakeInteractionRepository(failOn: {'favorite'});
    final notifier = InteractionNotifier(repository: repo);
    final post = _post();

    await expectLater(notifier.toggleFavorite(post), throwsException);
    expect(notifier.state.optimisticIsFavorited, isNull);
    expect(notifier.state.favoriteCountFor(count: 5, isFavorited: false), 5);
  });

  test('忽略进行中的重复点赞', () async {
    final gate = Completer<void>();
    final repo = _GatedInteractionRepository(gate);
    final notifier = InteractionNotifier(repository: repo);
    final post = _post();

    final first = notifier.toggleLike(post);
    final ignored = notifier.toggleLike(post);
    gate.complete();
    await Future.wait([first, ignored]);

    expect(repo.calls, ['like:9']);
    expect(notifier.state.optimisticIsLiked, isTrue);
    expect(notifier.state.likeCountFor(count: 10, isLiked: false), 11);
  });

  for (final favorite in [false, true]) {
    final name = favorite ? 'favorite' : 'like';
    test(
      '$name reconciles simultaneous old/new snapshots and reverse writes',
      () async {
        final repo = _PendingInteractionRepository();
        final notifier = InteractionNotifier(repository: repo);
        addTearDown(notifier.dispose);
        Future<void> toggle() => favorite
            ? notifier.toggleFavorite(_post())
            : notifier.toggleLike(_post());
        int count(int value, bool active) => favorite
            ? notifier.state.favoriteCountFor(count: value, isFavorited: active)
            : notifier.state.likeCountFor(count: value, isLiked: active);

        final first = toggle();
        expect(count(42, false), 43);
        // A read can observe the committed relation before the write response.
        expect(count(43, true), 43);
        repo.pending.complete();
        await first;
        expect(count(42, false), 43);
        expect(count(43, true), 43);
        // Counts are eventually consistent; do not invent a second accepted
        // contribution while the server relationship is already true.
        expect(count(42, true), 42);

        final reverse = toggle();
        expect(count(42, false), 42);
        expect(count(43, true), 42);
        expect(count(42, false), 42); // refreshed after the reverse write
        repo.pending.complete();
        await reverse;
        expect(count(42, false), 42);
        expect(count(43, true), 42);
      },
    );

    test(
      '$name failure restores the prior override without pinning a stale snapshot',
      () async {
        final repo = _PendingInteractionRepository();
        final notifier = InteractionNotifier(repository: repo);
        addTearDown(notifier.dispose);
        Future<void> toggle() => favorite
            ? notifier.toggleFavorite(_post())
            : notifier.toggleLike(_post());
        int count(int value, bool active) => favorite
            ? notifier.state.favoriteCountFor(count: value, isFavorited: active)
            : notifier.state.likeCountFor(count: value, isLiked: active);

        final failed = toggle();
        final failedExpectation = expectLater(failed, throwsStateError);
        expect(count(43, true), 43);
        repo.pending.completeError(StateError('uncertain response'));
        await failedExpectation;
        expect(count(42, false), 42);
        // With no prior local override, the updated server snapshot wins.
        expect(count(43, true), 43);

        final accepted = toggle();
        repo.pending.complete();
        await accepted;
        final reverse = toggle();
        final reverseExpectation = expectLater(reverse, throwsStateError);
        expect(count(43, true), 42);
        repo.pending.completeError(StateError('reverse rejected'));
        await reverseExpectation;
        expect(count(42, false), 43);
        expect(count(43, true), 43);
      },
    );
  }

  test(
    'one failed interaction does not roll back the other successful relation',
    () async {
      final gate = Completer<void>();
      final repo = _GatedInteractionRepository(gate);
      final notifier = InteractionNotifier(repository: repo);
      addTearDown(notifier.dispose);
      final like = notifier.toggleLike(_post());
      final failed = expectLater(like, throwsStateError);
      await notifier.toggleFavorite(_post());
      gate.completeError(StateError('like rejected'));
      await failed;
      expect(notifier.state.optimisticIsLiked, isNull);
      expect(notifier.state.optimisticIsFavorited, isTrue);
      expect(notifier.state.favoriteCountFor(count: 5, isFavorited: false), 6);
      expect(notifier.state.favoriteCountFor(count: 6, isFavorited: true), 6);
    },
  );

  test('account switch clears optimistic interaction state', () async {
    final repo = _FakeInteractionRepository();
    final container = createAppProviderContainer(
      overrides: [interactionRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final auth = container.read(authNotifierProvider.notifier);
    await auth.onLoginSuccess(1, 'access-a', refreshToken: 'refresh-a');
    final subscription = container.listen(
      interactionNotifierProvider('9'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container
        .read(interactionNotifierProvider('9').notifier)
        .toggleLike(_post());
    expect(
      container.read(interactionNotifierProvider('9')).optimisticIsLiked,
      isTrue,
    );

    await auth.onLoginSuccess(2, 'access-b', refreshToken: 'refresh-b');
    await pumpEventQueue();
    final switched = container.read(interactionNotifierProvider('9'));
    expect(switched.optimisticIsLiked, isNull);
    expect(switched.likeCountFor(count: 10, isLiked: false), 10);
  });
}

class _GatedInteractionRepository extends _FakeInteractionRepository {
  final Completer<void> gate;

  _GatedInteractionRepository(this.gate);

  @override
  Future<void> likeTarget(Object targetId, int targetType) async {
    await gate.future;
    await super.likeTarget(targetId, targetType);
  }
}

class _PendingInteractionRepository extends _FakeInteractionRepository {
  late Completer<void> pending;

  Future<void> _wait() {
    pending = Completer<void>();
    return pending.future;
  }

  @override
  Future<void> likeTarget(Object targetId, int targetType) => _wait();
  @override
  Future<void> unlikeTarget(Object targetId, int targetType) => _wait();
  @override
  Future<void> favoritePost(Object postId) => _wait();
  @override
  Future<void> unfavoritePost(Object postId) => _wait();
}
