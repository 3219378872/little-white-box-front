import 'package:flutter_test/flutter_test.dart';
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
  test('toggleLike 乐观翻转并累计计数，成功后保持', () async {
    final repo = _FakeInteractionRepository();
    final notifier = InteractionNotifier(repository: repo);
    final post = _post();

    await notifier.toggleLike(post);
    expect(notifier.state.optimisticIsLiked, isTrue);
    expect(notifier.state.likeCountDelta, 1);
    expect(repo.calls, ['like:9']);

    await notifier.toggleLike(post);
    expect(notifier.state.optimisticIsLiked, isFalse);
    expect(notifier.state.likeCountDelta, 0);
    expect(repo.calls, ['like:9', 'unlike:9']);
  });

  test('toggleLike 失败回滚并抛出', () async {
    final repo = _FakeInteractionRepository(failOn: {'like'});
    final notifier = InteractionNotifier(repository: repo);
    final post = _post();

    await expectLater(notifier.toggleLike(post), throwsException);
    expect(notifier.state.optimisticIsLiked, isFalse);
    expect(notifier.state.likeCountDelta, 0);
  });

  test('toggleFavorite 基于服务端初值做乐观更新', () async {
    final repo = _FakeInteractionRepository();
    final notifier = InteractionNotifier(repository: repo);
    final post = _post(isFavorited: true);

    await notifier.toggleFavorite(post);
    expect(notifier.state.optimisticIsFavorited, isFalse);
    expect(notifier.state.favoriteCountDelta, -1);
    expect(repo.calls, ['unfavorite:9']);
  });

  test('toggleFavorite 失败回滚并抛出', () async {
    final repo = _FakeInteractionRepository(failOn: {'favorite'});
    final notifier = InteractionNotifier(repository: repo);
    final post = _post();

    await expectLater(notifier.toggleFavorite(post), throwsException);
    expect(notifier.state.optimisticIsFavorited, isFalse);
    expect(notifier.state.favoriteCountDelta, 0);
  });
}
