part of 'mock_router.dart';

Map<String, dynamic> _postList(Map<String, String> query, _Auth auth) {
  final cursor = query['cursor'] ?? '';
  final pageSize = _clampPageSize(
    _queryInt(query, 'pageSize', defaultValue: 20),
  );
  final sortBy = _queryInt(query, 'sortBy', defaultValue: 1);
  final published = _publishedPosts();
  final sorted = [...published]
    ..sort((a, b) {
      if (sortBy == 2) {
        return (b['likeCount'] as num).compareTo(a['likeCount'] as num);
      }
      return (b['createdAt'] as num).compareTo(a['createdAt'] as num);
    });
  return _pagedPosts(sorted, cursor, pageSize, auth.userId);
}

Map<String, dynamic> _getPost(int postId, _Auth auth) {
  final post = _findPost(postId);
  if (_statusOf(post) != 1 &&
      (post['authorId'] as num).toInt() != auth.userId) {
    throw const _MockBiz(404, 2001, '内容不存在');
  }
  return _postItem(post, auth.userId);
}

Map<String, dynamic> _createPost(int userId, Map<String, dynamic> body) {
  final key = body['idempotencyKey']?.toString().trim() ?? '';
  if (key.isNotEmpty && _postIdempotencyKeys.containsKey(key)) {
    final existingId = _postIdempotencyKeys[key]!;
    final existing = _findPost(existingId);
    return {
      'postId': existingId,
      'status': _statusOf(existing),
      'revision': existing['revision'] ?? 1,
    };
  }
  final title = body['title']?.toString() ?? '';
  final content = body['content']?.toString() ?? '';
  _validatePostFields(title, content, body['images'], body['tags']);
  final status = (body['status'] as num?)?.toInt() ?? 0;
  if (status != 0 && status != 1) throw const _MockBiz(400, 2, '参数错误');
  final user = _users[userId]!;
  final id = _nextPostId++;
  final post = {
    'id': id,
    'authorId': userId,
    'authorName': user['nickname'],
    'authorAvatar': user['avatarUrl'],
    'title': title,
    'content': content,
    'images': _stringList(body['images']),
    'tags': _stringList(body['tags']),
    'status': status,
    'revision': 1,
    'viewCount': 0,
    'likeCount': 0,
    'commentCount': 0,
    'favoriteCount': 0,
    'createdAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  };
  _posts.insert(0, post);
  user['postCount'] = (user['postCount'] as num).toInt() + 1;
  if (key.isNotEmpty) _postIdempotencyKeys[key] = id;
  return {'postId': id, 'status': status, 'revision': 1};
}

Map<String, dynamic> _updatePost(
  int userId,
  int postId,
  Map<String, dynamic> body,
) {
  final idx = _postIndex(postId);
  final current = _posts[idx];
  if ((current['authorId'] as num).toInt() != userId) {
    throw const _MockBiz(403, 2002, '无权操作此内容');
  }
  final expected = (body['expectedRevision'] as num?)?.toInt() ?? 0;
  if (expected <= 0) throw const _MockBiz(400, 2, '参数错误');
  final revision = (current['revision'] as num?)?.toInt() ?? 1;
  if (expected != revision) throw const _MockBiz(409, 2007, '内容版本冲突');
  final title = body.containsKey('title')
      ? body['title']?.toString() ?? ''
      : current['title']?.toString() ?? '';
  final content = body.containsKey('content')
      ? body['content']?.toString() ?? ''
      : current['content']?.toString() ?? '';
  final images = body.containsKey('images')
      ? body['images']
      : current['images'];
  final tags = body.containsKey('tags') ? body['tags'] : current['tags'];
  _validatePostFields(title, content, images, tags);
  var status = _statusOf(current);
  if (body.containsKey('status') && body['status'] != null) {
    status = (body['status'] as num).toInt();
    if (status != 0 && status != 1) throw const _MockBiz(400, 2, '参数错误');
  }
  _posts[idx] = {
    ...current,
    'title': title,
    'content': content,
    'images': _stringList(images),
    'tags': _stringList(tags),
    'status': status,
    'revision': revision + 1,
  };
  return {'status': status, 'revision': revision + 1};
}

void _deletePost(int userId, int postId, Map<String, dynamic> body) {
  final idx = _postIndex(postId);
  final current = _posts[idx];
  if ((current['authorId'] as num).toInt() != userId) {
    throw const _MockBiz(403, 2002, '无权操作此内容');
  }
  final expected = (body['expectedRevision'] as num?)?.toInt() ?? 0;
  if (expected <= 0) throw const _MockBiz(400, 2, '参数错误');
  final revision = (current['revision'] as num?)?.toInt() ?? 1;
  if (expected != revision) throw const _MockBiz(409, 2007, '内容版本冲突');
  _posts.removeAt(idx);
  _comments.remove(postId);
}

Map<String, dynamic> _commentList(int postId, Map<String, String> query) {
  _findPost(postId);
  final page = _clampPage(_queryInt(query, 'page', defaultValue: 1));
  final pageSize = _clampPageSize(
    _queryInt(query, 'pageSize', defaultValue: 20),
  );
  final sortBy = _queryInt(query, 'sortBy', defaultValue: 1);
  final all =
      [...(_comments[postId] ?? const <Map<String, dynamic>>[])]
          .where((c) => (c['parentId'] as num).toInt() == 0)
          .toList()
        ..sort((a, b) {
          if (sortBy == 2) {
            return (b['likeCount'] as num).compareTo(a['likeCount'] as num);
          }
          return (b['createdAt'] as num).compareTo(a['createdAt'] as num);
        });
  final start = (page - 1) * pageSize;
  final slice = start >= all.length
      ? const <Map<String, dynamic>>[]
      : all.sublist(start, (start + pageSize).clamp(0, all.length));
  return {
    // 契约与后端一致：只返回顶级评论，内嵌前 3 条回复预览 + replyCount
    'list': slice.map(_withReplyPreview).toList(),
    'total': all.length,
    'page': page,
    'pageSize': pageSize,
  };
}

List<Map<String, dynamic>> _repliesOf(int parentId) {
  for (final entry in _comments.entries) {
    final replies =
        entry.value
            .where((c) => (c['parentId'] as num).toInt() == parentId)
            .toList()
          ..sort(
            (a, b) => (a['createdAt'] as num).compareTo(b['createdAt'] as num),
          );
    if (replies.isNotEmpty) return replies;
  }
  return const <Map<String, dynamic>>[];
}

Map<String, dynamic> _withReplyPreview(Map<String, dynamic> comment) {
  final replies = _repliesOf((comment['id'] as num).toInt());
  return {
    ...comment,
    'replyCount': replies.length,
    'replies': replies.take(3).map(_stripNested).toList(),
  };
}

Map<String, dynamic> _stripNested(Map<String, dynamic> reply) => {
  ...reply,
  'replyCount': 0,
  'replies': const <Map<String, dynamic>>[],
};

Map<String, dynamic> _commentReplies(int commentId, Map<String, String> query) {
  final page = _clampPage(_queryInt(query, 'page', defaultValue: 1));
  final pageSize = _clampPageSize(
    _queryInt(query, 'pageSize', defaultValue: 20),
  );
  final parent = _findComment(commentId);
  if ((parent['parentId'] as num).toInt() != 0) {
    throw const _MockBiz(404, 4, '资源不存在');
  }
  final all = _repliesOf(commentId);
  final start = (page - 1) * pageSize;
  final slice = start >= all.length
      ? const <Map<String, dynamic>>[]
      : all.sublist(start, (start + pageSize).clamp(0, all.length));
  return {
    'list': slice.map(_stripNested).toList(),
    'total': all.length,
    'page': page,
    'pageSize': pageSize,
  };
}

Map<String, dynamic> _createComment(int userId, Map<String, dynamic> body) {
  final postId = (body['postId'] as num?)?.toInt() ?? 0;
  final content = body['content']?.toString() ?? '';
  if (postId <= 0) throw const _MockBiz(400, 2, '参数错误');
  if (content.isEmpty) throw const _MockBiz(400, 2004, '内容不能为空');
  _findPost(postId);
  final key = body['idempotencyKey']?.toString().trim() ?? '';
  if (key.isNotEmpty && _commentIdempotencyKeys.containsKey(key)) {
    return {'commentId': _commentIdempotencyKeys[key]};
  }
  final user = _users[userId]!;
  final id = _nextCommentId++;
  final comment = {
    'id': id,
    'userId': userId,
    'userName': user['nickname'],
    'userAvatar': user['avatarUrl'],
    'parentId': (body['parentId'] as num?)?.toInt() ?? 0,
    'replyUserId': (body['replyUserId'] as num?)?.toInt() ?? 0,
    'content': content,
    'likeCount': 0,
    'createdAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  };
  _comments.putIfAbsent(postId, () => []).add(comment);
  if (key.isNotEmpty) _commentIdempotencyKeys[key] = id;
  return {'commentId': id};
}

MockRouterResponse _deleteComment(int userId, int commentId) {
  for (final entry in _comments.entries) {
    final idx = entry.value.indexWhere((comment) => comment['id'] == commentId);
    if (idx < 0) continue;
    if ((entry.value[idx]['userId'] as num).toInt() != userId) {
      throw const _MockBiz(403, 1007, '权限不足');
    }
    // 与后端契约一致：删除顶级评论时级联软删其全部楼中楼回复
    entry.value.removeWhere(
      (comment) =>
          (comment['id'] as num).toInt() == commentId ||
          (comment['parentId'] as num).toInt() == commentId,
    );
    return _jsonResponse(const {});
  }
  throw const _MockBiz(404, 4, '资源不存在');
}

Map<String, dynamic> _postItem(Map<String, dynamic> post, int viewerId) {
  final postId = (post['id'] as num).toInt();
  return {
    'id': postId,
    'authorId': post['authorId'],
    'authorName': post['authorName'] ?? '',
    'authorAvatar': post['authorAvatar'] ?? '',
    'title': post['title'] ?? '',
    'content': post['content'] ?? '',
    'images': _stringList(post['images']),
    'tags': _stringList(post['tags']),
    'status': _statusOf(post),
    'viewCount': post['viewCount'] ?? 0,
    'likeCount': post['likeCount'] ?? 0,
    'commentCount': (_comments[postId] ?? const []).length,
    'favoriteCount': post['favoriteCount'] ?? 0,
    'isLiked': _likedByUser[viewerId]?.contains(postId) ?? false,
    'isFavorited': _favoritedByUser[viewerId]?.contains(postId) ?? false,
    'revision': post['revision'] ?? 1,
    'createdAt': post['createdAt'] ?? 0,
  };
}

Map<String, dynamic> _pagedPosts(
  List<Map<String, dynamic>> posts,
  String cursor,
  int pageSize,
  int viewerId,
) {
  final page = _decodeCursorPage(cursor);
  if (page < 1) throw const _MockBiz(400, 2, '参数错误');
  final start = (page - 1) * pageSize;
  final slice = start >= posts.length
      ? const <Map<String, dynamic>>[]
      : posts.sublist(start, (start + pageSize).clamp(0, posts.length));
  // 满批且仍有余量时给下一页游标；空串表示没有更多。
  final hasMore =
      slice.length == pageSize && start + slice.length < posts.length;
  return {
    'list': [for (final post in slice) _postItem(post, viewerId)],
    'nextCursor': hasMore ? _encodeCursorPage(page + 1) : '',
  };
}

List<Map<String, dynamic>> _publishedPosts() {
  return _posts.where((post) => _statusOf(post) == 1).toList();
}

int _statusOf(Map<String, dynamic> post) =>
    (post['status'] as num?)?.toInt() ?? 1;

Map<String, dynamic> _findPost(int postId) {
  return _posts.firstWhere(
    (post) => (post['id'] as num).toInt() == postId,
    orElse: () => throw const _MockBiz(404, 2001, '内容不存在'),
  );
}

int _postIndex(int postId) {
  final idx = _posts.indexWhere(
    (post) => (post['id'] as num).toInt() == postId,
  );
  if (idx < 0) throw const _MockBiz(404, 2001, '内容不存在');
  return idx;
}

Map<String, dynamic> _findComment(int commentId) {
  for (final entry in _comments.entries) {
    for (final comment in entry.value) {
      if ((comment['id'] as num).toInt() == commentId) return comment;
    }
  }
  throw const _MockBiz(404, 4, '资源不存在');
}

void _validatePostFields(
  String title,
  String content,
  Object? images,
  Object? tags,
) {
  final titleRunes = title.runes.length;
  if (titleRunes < 1) throw const _MockBiz(400, 2005, '标题不能为空');
  if (titleRunes > 120) throw const _MockBiz(400, 2003, '内容过长');
  final contentRunes = content.runes.length;
  if (contentRunes < 1) throw const _MockBiz(400, 2004, '内容不能为空');
  if (contentRunes > 20000) throw const _MockBiz(400, 2003, '内容过长');
  final imageList = _stringList(images);
  if (imageList.length > 9) throw const _MockBiz(400, 2, '参数错误');
  final tagList = _stringList(tags);
  if (tagList.length > 10) throw const _MockBiz(400, 2, '参数错误');
}
