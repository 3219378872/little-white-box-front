part of 'mock_router.dart';

MockRouterResponse _like(
  int userId,
  Map<String, dynamic> body, {
  required bool like,
}) {
  final targetId = (body['targetId'] as num?)?.toInt() ?? 0;
  final targetType = (body['targetType'] as num?)?.toInt() ?? 0;
  if (targetId <= 0 || targetType != 1) throw const _MockBiz(400, 2, '参数错误');
  final post = _findPost(targetId);
  if ((post['authorId'] as num).toInt() == userId && like) {
    throw const _MockBiz(400, 3005, '不能点赞自己');
  }
  final liked = _likedByUser.putIfAbsent(userId, () => {}).contains(targetId);
  if (like) {
    if (liked) throw const _MockBiz(400, 3001, '已点赞');
    _likedByUser[userId]!.add(targetId);
    post['likeCount'] = (post['likeCount'] as num).toInt() + 1;
  } else {
    if (!liked) throw const _MockBiz(400, 3003, '未点赞');
    _likedByUser[userId]!.remove(targetId);
    post['likeCount'] = ((post['likeCount'] as num).toInt() - 1).clamp(
      0,
      1 << 30,
    );
  }
  return _jsonResponse(const {});
}

MockRouterResponse _favorite(
  int userId,
  Map<String, dynamic> body, {
  required bool favorite,
}) {
  final postId = (body['postId'] as num?)?.toInt() ?? 0;
  if (postId <= 0) throw const _MockBiz(400, 2, '参数错误');
  final post = _findPost(postId);
  final favorited = _favoritedByUser
      .putIfAbsent(userId, () => {})
      .contains(postId);
  if (favorite) {
    if (favorited) throw const _MockBiz(400, 3002, '已收藏');
    _favoritedByUser[userId]!.add(postId);
    post['favoriteCount'] = (post['favoriteCount'] as num).toInt() + 1;
  } else {
    if (!favorited) throw const _MockBiz(400, 3004, '未收藏');
    _favoritedByUser[userId]!.remove(postId);
    post['favoriteCount'] = ((post['favoriteCount'] as num).toInt() - 1).clamp(
      0,
      1 << 30,
    );
  }
  return _jsonResponse(const {});
}

Map<String, dynamic> _getUser(int userId) {
  final user = _users[userId];
  if (user == null) throw const _MockBiz(404, 1001, '用户不存在');
  return Map<String, dynamic>.from(user);
}

MockRouterResponse _updateProfile(int userId, Map<String, dynamic> body) {
  final user = _users[userId]!;
  if (body.containsKey('nickname')) user['nickname'] = body['nickname'];
  if (body.containsKey('avatarUrl')) user['avatarUrl'] = body['avatarUrl'];
  if (body.containsKey('bio')) user['bio'] = body['bio'];
  return _jsonResponse(const {});
}

MockRouterResponse _follow(
  int userId,
  Map<String, dynamic> body, {
  required bool follow,
}) {
  final targetUserId = (body['targetUserId'] as num?)?.toInt() ?? 0;
  if (targetUserId <= 0) throw const _MockBiz(400, 2, '参数错误');
  if (targetUserId == userId) throw const _MockBiz(400, 3006, '不能关注自己');
  final target = _users[targetUserId];
  if (target == null) throw const _MockBiz(404, 1001, '用户不存在');
  final following = _followedByUser.putIfAbsent(userId, () => {});
  final actor = _users[userId]!;
  if (follow) {
    if (following.add(targetUserId)) {
      target['followerCount'] = (target['followerCount'] as num).toInt() + 1;
      actor['followingCount'] = (actor['followingCount'] as num).toInt() + 1;
    }
  } else if (following.remove(targetUserId)) {
    target['followerCount'] = ((target['followerCount'] as num).toInt() - 1)
        .clamp(0, 1 << 30);
    actor['followingCount'] = ((actor['followingCount'] as num).toInt() - 1)
        .clamp(0, 1 << 30);
  }
  return _jsonResponse(const {});
}

Map<String, dynamic> _userPosts(
  int userId,
  Map<String, String> query,
  _Auth auth,
) {
  if (!_users.containsKey(userId)) throw const _MockBiz(404, 1001, '用户不存在');
  final sortBy = _queryInt(query, 'sortBy', defaultValue: 1);
  final filtered =
      _posts.where((post) {
        if ((post['authorId'] as num).toInt() != userId) return false;
        return _statusOf(post) == 1 ||
            jsonInt64Id(auth.userId) == jsonInt64Id(userId);
      }).toList()..sort((a, b) {
        if (sortBy == 2) {
          return (b['likeCount'] as num).compareTo(a['likeCount'] as num);
        }
        return (b['createdAt'] as num).compareTo(a['createdAt'] as num);
      });
  return _pagedPosts(
    filtered,
    query['cursor'] ?? '',
    _userPostsPageSize(query),
    auth.userId,
  );
}

int _userPostsPageSize(Map<String, String> query) =>
    _clampPageSize(_queryInt(query, 'pageSize', defaultValue: 20));

Map<String, dynamic> _userFavorites(
  int userId,
  Map<String, String> query,
  _Auth auth,
) {
  final user = _users[userId];
  if (user == null) throw const _MockBiz(404, 1001, '用户不存在');
  final isOwner =
      auth.isAuthenticated && jsonInt64Id(auth.userId) == jsonInt64Id(userId);
  if (!isOwner && user['favoritesVisible'] != true) {
    throw const _MockBiz(403, 3007, '收藏列表已设为私密');
  }
  final pageSize = _clampPageSizeTo(
    _queryInt(query, 'pageSize', defaultValue: 20),
    20,
    100,
  );
  final ids = _favoritedByUser[userId] ?? const <int>{};
  final filtered = _publishedPosts()
      .where((post) => ids.contains((post['id'] as num).toInt()))
      .toList();
  return _pagedPosts(filtered, query['cursor'] ?? '', pageSize, auth.userId);
}

Map<String, dynamic> _uploadImage() {
  final seed = DateTime.now().microsecondsSinceEpoch % 10000;
  return {
    'mediaId': _nextMediaId++,
    'url': 'https://picsum.photos/seed/$seed/400/300',
    'thumbnailUrl': 'https://picsum.photos/seed/$seed/200/150',
  };
}
