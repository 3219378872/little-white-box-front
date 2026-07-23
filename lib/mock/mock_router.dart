import 'dart:convert';
import 'mock_data.dart';

/// Mock 路由分发 + 内存状态

int _nextPostId = 100;
int _nextCommentId = 200;

final List<Map<String, dynamic>> _posts =
    seedPosts.map((p) => Map<String, dynamic>.from(p)).toList();

final Map<int, List<Map<String, dynamic>>> _comments = seedComments.map(
  (k, v) => MapEntry(k, v.map((c) => Map<String, dynamic>.from(c)).toList()),
);

final Map<int, Map<String, dynamic>> _users = seedUsers.map(
  (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
);

final Set<int> _likedPostIds = {};
final Set<int> _favoritedPostIds = {};
final Set<int> _followedUserIds = {};

/// 分发请求，返回完整的 JSON 响应字符串
String dispatch(String method, String path, String requestBody) {
  final uri = Uri.parse('http://mock$path');
  final segments = uri.pathSegments; // ['api', 'v1', ...]
  final query = uri.queryParameters;

  Map<String, dynamic>? body;
  if (requestBody.isNotEmpty) {
    try {
      body = jsonDecode(requestBody) as Map<String, dynamic>;
    } catch (_) {
      body = {};
    }
  }

  try {
    final data = _route(method, segments, query, body);
    return jsonEncode({'code': 0, 'desc': 'ok', 'data': data});
  } catch (e) {
    return jsonEncode({'code': 1, 'desc': e.toString(), 'data': null});
  }
}

Map<String, dynamic> _route(
  String method,
  List<String> segments,
  Map<String, String> query,
  Map<String, dynamic>? body,
) {
  // segments: ['api', 'v1', '<resource>', ...]
  if (segments.length < 3) return {};

  final resource = segments[2];

  switch (resource) {
    case 'health':
      return {'status': 'ok'};

    case 'auth':
      return _handleAuth(segments, body ?? {});

    case 'posts':
      return _handlePostList(query);

    case 'post':
      return _handlePost(method, segments, body);

    case 'comments':
      return _handleCommentList(segments, query);

    case 'comment':
      return _handleComment(method, segments, body);

    case 'like':
      return _handleLike(body ?? {});

    case 'favorite':
      return _handleFavorite(body ?? {});

    case 'user':
      return _handleUser(method, segments, body);

    case 'users':
      return _handleUsersList(method, segments, query);

    case 'media':
      return _handleMedia();

    default:
      return {};
  }
}

// ─── Auth ───

/// 构造用于测试的假 JWT：header.payload.fake-sig，payload 含 userId 字段
String _buildFakeJwt(int userId) {
  final header = base64Url
      .encode(utf8.encode('{"alg":"none","typ":"JWT"}'))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode('{"userId":$userId}'))
      .replaceAll('=', '');
  return '$header.$payload.fake-sig';
}

/// Default account used when the Mock web entry point starts.
String mockAccessTokenForUser(int userId) => _buildFakeJwt(userId);

Map<String, dynamic> _handleAuth(
  List<String> segments,
  Map<String, dynamic> body,
) {
  if (segments.length < 4) return {};

  switch (segments[3]) {
    case 'login':
      return {'userId': 1, 'token': _buildFakeJwt(1)};
    case 'register':
      return {'userId': 1, 'token': _buildFakeJwt(1)};
    case 'verify-code':
      return {};
    default:
      return {};
  }
}

// ─── Post List ───

Map<String, dynamic> _handlePostList(Map<String, String> query) {
  final page = int.tryParse(query['page'] ?? '1') ?? 1;
  final pageSize = int.tryParse(query['pageSize'] ?? '20') ?? 20;

  final sorted = List<Map<String, dynamic>>.from(_posts)
    ..sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));

  final start = (page - 1) * pageSize;
  final end = start + pageSize;
  final slice =
      start >= sorted.length ? <Map<String, dynamic>>[] : sorted.sublist(start, end.clamp(0, sorted.length));

  return {
    'list': slice,
    'total': sorted.length,
    'page': page,
    'pageSize': pageSize,
  };
}

// ─── Single Post ───

Map<String, dynamic> _handlePost(
  String method,
  List<String> segments,
  Map<String, dynamic>? body,
) {
  // POST /api/v1/post (create)
  if (method == 'POST' && segments.length == 3) {
    final newId = _nextPostId++;
    final newPost = {
      'id': newId,
      'authorId': 1,
      'authorName': _users[1]!['nickname'],
      'authorAvatar': _users[1]!['avatarUrl'],
      'title': body?['title'] ?? '',
      'content': body?['content'] ?? '',
      'images': body?['images'] ?? <String>[],
      'tags': body?['tags'] ?? <String>[],
      'viewCount': 0,
      'likeCount': 0,
      'commentCount': 0,
      'favoriteCount': 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
    _posts.insert(0, newPost);
    return {'postId': newId};
  }

  // /api/v1/post/:id
  if (segments.length < 4) return {};
  final postId = int.tryParse(segments[3]) ?? 0;

  // GET — detail
  if (method == 'GET') {
    final post = _posts.firstWhere(
      (p) => p['id'] == postId,
      orElse: () => <String, dynamic>{},
    );
    if (post.isEmpty) throw Exception('帖子不存在');
    return {
      ...post,
      'isLiked': _likedPostIds.contains(postId),
      'isFavorited': _favoritedPostIds.contains(postId),
    };
  }

  // POST — update or delete (body 含 title 则为更新)
  if (body != null && body.containsKey('title')) {
    final idx = _posts.indexWhere((p) => p['id'] == postId);
    if (idx >= 0) {
      _posts[idx] = {
        ..._posts[idx],
        'title': body['title'],
        'content': body['content'] ?? _posts[idx]['content'],
        'images': body['images'] ?? _posts[idx]['images'],
        'tags': body['tags'] ?? _posts[idx]['tags'],
      };
    }
    return {};
  }

  // delete
  _posts.removeWhere((p) => p['id'] == postId);
  _comments.remove(postId);
  return {};
}

// ─── Comment List ───

Map<String, dynamic> _handleCommentList(
  List<String> segments,
  Map<String, String> query,
) {
  if (segments.length < 4) return {'list': [], 'total': 0, 'page': 1, 'pageSize': 20};

  final postId = int.tryParse(segments[3]) ?? 0;
  final page = int.tryParse(query['page'] ?? '1') ?? 1;
  final pageSize = int.tryParse(query['pageSize'] ?? '20') ?? 20;

  final all = _comments[postId] ?? [];
  final start = (page - 1) * pageSize;
  final end = start + pageSize;
  final slice =
      start >= all.length ? <Map<String, dynamic>>[] : all.sublist(start, end.clamp(0, all.length));

  return {
    'list': slice,
    'total': all.length,
    'page': page,
    'pageSize': pageSize,
  };
}

// ─── Single Comment ───

Map<String, dynamic> _handleComment(
  String method,
  List<String> segments,
  Map<String, dynamic>? body,
) {
  // POST /api/v1/comment (create)
  if (segments.length == 3 && body != null) {
    final postId = (body['postId'] as num).toInt();
    final newId = _nextCommentId++;
    final comment = {
      'id': newId,
      'userId': 1,
      'userName': _users[1]!['nickname'],
      'userAvatar': _users[1]!['avatarUrl'],
      'parentId': body['parentId'] ?? 0,
      'replyUserId': body['replyUserId'] ?? 0,
      'content': body['content'] ?? '',
      'likeCount': 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
    _comments.putIfAbsent(postId, () => []);
    _comments[postId]!.add(comment);

    // 更新帖子评论数
    final postIdx = _posts.indexWhere((p) => p['id'] == postId);
    if (postIdx >= 0) {
      _posts[postIdx] = {
        ..._posts[postIdx],
        'commentCount': (_posts[postIdx]['commentCount'] as num).toInt() + 1,
      };
    }

    return {'commentId': newId};
  }

  // POST /api/v1/comment/:id (delete)
  if (segments.length >= 4) {
    final commentId = int.tryParse(segments[3]) ?? 0;
    for (final list in _comments.values) {
      final idx = list.indexWhere((c) => c['id'] == commentId);
      if (idx >= 0) {
        list.removeAt(idx);
        break;
      }
    }
    return {};
  }

  return {};
}

// ─── Like (toggle) ───

Map<String, dynamic> _handleLike(Map<String, dynamic> body) {
  final targetId = (body['targetId'] as num?)?.toInt() ?? 0;
  final targetType = (body['targetType'] as num?)?.toInt() ?? 1;

  if (targetType == 1) {
    // 帖子点赞 toggle
    final postIdx = _posts.indexWhere((p) => p['id'] == targetId);
    if (_likedPostIds.contains(targetId)) {
      _likedPostIds.remove(targetId);
      if (postIdx >= 0) {
        _posts[postIdx] = {
          ..._posts[postIdx],
          'likeCount': ((_posts[postIdx]['likeCount'] as num).toInt() - 1).clamp(0, 999999),
        };
      }
    } else {
      _likedPostIds.add(targetId);
      if (postIdx >= 0) {
        _posts[postIdx] = {
          ..._posts[postIdx],
          'likeCount': (_posts[postIdx]['likeCount'] as num).toInt() + 1,
        };
      }
    }
  }

  return {};
}

// ─── Favorite (toggle) ───

Map<String, dynamic> _handleFavorite(Map<String, dynamic> body) {
  final postId = (body['postId'] as num?)?.toInt() ?? 0;
  final postIdx = _posts.indexWhere((p) => p['id'] == postId);

  if (_favoritedPostIds.contains(postId)) {
    _favoritedPostIds.remove(postId);
    if (postIdx >= 0) {
      _posts[postIdx] = {
        ..._posts[postIdx],
        'favoriteCount': ((_posts[postIdx]['favoriteCount'] as num).toInt() - 1).clamp(0, 999999),
      };
    }
  } else {
    _favoritedPostIds.add(postId);
    if (postIdx >= 0) {
      _posts[postIdx] = {
        ..._posts[postIdx],
        'favoriteCount': (_posts[postIdx]['favoriteCount'] as num).toInt() + 1,
      };
    }
  }

  return {};
}

// ─── User ───

Map<String, dynamic> _handleUser(
  String method,
  List<String> segments,
  Map<String, dynamic>? body,
) {
  if (segments.length < 4) return {};

  // GET /api/v1/user/:id
  if (method == 'GET') {
    final userId = int.tryParse(segments[3]) ?? 0;
    final user = _users[userId];
    if (user == null) throw Exception('用户不存在');
    return Map<String, dynamic>.from(user);
  }

  // POST /api/v1/user/profile
  if (segments[3] == 'profile' && body != null) {
    final user = _users[1]!;
    if (body.containsKey('nickname')) user['nickname'] = body['nickname'];
    if (body.containsKey('avatarUrl')) user['avatarUrl'] = body['avatarUrl'];
    if (body.containsKey('bio')) user['bio'] = body['bio'];
    return {};
  }

  // POST /api/v1/user/follow (toggle)
  if (segments[3] == 'follow' && body != null) {
    final targetUserId = (body['targetUserId'] as num?)?.toInt() ?? 0;
    final targetUser = _users[targetUserId];
    if (_followedUserIds.contains(targetUserId)) {
      _followedUserIds.remove(targetUserId);
      if (targetUser != null) {
        targetUser['followerCount'] =
            ((targetUser['followerCount'] as num).toInt() - 1).clamp(0, 999999);
      }
    } else {
      _followedUserIds.add(targetUserId);
      if (targetUser != null) {
        targetUser['followerCount'] =
            (targetUser['followerCount'] as num).toInt() + 1;
      }
    }
    return {};
  }

  return {};
}

// ─── Media ───

Map<String, dynamic> _handleMedia() {
  final seed = DateTime.now().microsecondsSinceEpoch % 10000;
  return {
    'mediaId': DateTime.now().millisecondsSinceEpoch,
    'url': 'https://picsum.photos/seed/$seed/400/300',
    'thumbnailUrl': 'https://picsum.photos/seed/$seed/200/150',
  };
}

// ─── Users (plural) — 用户的帖子/收藏列表 ───

Map<String, dynamic> _handleUsersList(
  String method,
  List<String> segments,
  Map<String, String> query,
) {
  // segments: ['api', 'v1', 'users', ':userId', 'posts'|'favorites']
  if (method != 'GET' || segments.length < 5) return {};

  final userId = int.tryParse(segments[3]) ?? 0;
  final kind = segments[4];
  final page = int.tryParse(query['page'] ?? '1') ?? 1;
  final pageSize = int.tryParse(query['pageSize'] ?? '20') ?? 20;

  List<Map<String, dynamic>> filtered;
  if (kind == 'posts') {
    filtered = _posts.where((p) => (p['authorId'] as num).toInt() == userId).toList()
      ..sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));
  } else if (kind == 'favorites') {
    if (userId == 1) {
      filtered = _posts
          .where((p) => _favoritedPostIds.contains((p['id'] as num).toInt()))
          .toList();
    } else {
      filtered = [];
    }
  } else {
    return {};
  }

  final start = (page - 1) * pageSize;
  final end = start + pageSize;
  final slice = start >= filtered.length
      ? <Map<String, dynamic>>[]
      : filtered.sublist(start, end.clamp(0, filtered.length));

  return {
    'list': slice,
    'total': filtered.length,
    'page': page,
    'pageSize': pageSize,
  };
}
