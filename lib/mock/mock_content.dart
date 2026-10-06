part of 'mock_router.dart';

// v1 帖子列表：只含已发布帖子，sortBy 2 按点赞数、否则按发布时间倒序，游标分页。
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

// 帖子详情：未发布（草稿）只对作者可见，其他人按不存在处理。
Map<String, dynamic> _getPost(int postId, _Auth auth) {
  final post = _findPost(postId);
  if (_statusOf(post) != 1 &&
      (post['authorId'] as num).toInt() != auth.userId) {
    throw const _MockBiz(404, 2001, '内容不存在');
  }
  return _postItem(post, auth.userId);
}

// 发帖：同一幂等键重放时返回首次创建的帖子，不重复创建；status 0 为草稿、1 为发布。
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

// 编辑帖子：仅作者可改，expectedRevision 必须等于当前版本（乐观并发），
// 未传的字段沿用原值，成功后版本号加一。
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

// 删除帖子：作者与版本校验同 [_updatePost]，评论一并移除。
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

// 顶级评论列表：页码分页，sortBy 2 按点赞数、否则按时间倒序。
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

// 某条顶级评论下的全部回复，按时间正序；评论 ID 全局唯一，找到即返回。
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

// 顶级评论附带回复总数与前 3 条回复预览。
Map<String, dynamic> _withReplyPreview(Map<String, dynamic> comment) {
  final replies = _repliesOf((comment['id'] as num).toInt());
  return {
    ...comment,
    'replyCount': replies.length,
    'replies': replies.take(3).map(_stripNested).toList(),
  };
}

// 回复本身不再嵌套回复。
Map<String, dynamic> _stripNested(Map<String, dynamic> reply) => {
  ...reply,
  'replyCount': 0,
  'replies': const <Map<String, dynamic>>[],
};

// 楼中楼分页：只接受顶级评论 ID，回复的回复按不存在处理。
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

// 发表评论或回复（parentId 非 0）；同一幂等键重放返回首次创建的评论 ID。
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

// 删除评论：仅评论作者可删。
MockRouterResponse _deleteComment(int userId, int commentId) {
  for (final entry in _comments.entries) {
    final idx = entry.value.indexWhere((comment) => comment['id'] == commentId);
    if (idx < 0) continue;
    if ((entry.value[idx]['userId'] as num).toInt() != userId) {
      throw const _MockBiz(403, 1007, '权限不足');
    }
    // 与后端契约一致：删除顶级评论时其全部楼中楼回复一并删除（mock 直接移除，不做软删标记）
    entry.value.removeWhere(
      (comment) =>
          (comment['id'] as num).toInt() == commentId ||
          (comment['parentId'] as num).toInt() == commentId,
    );
    return _jsonResponse(const {});
  }
  throw const _MockBiz(404, 4, '资源不存在');
}

// 把内存帖子投影成网关帖子对象，按 [viewerId] 计算点赞/收藏态，评论数取实时值。
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

// 帖子游标分页的公共实现；游标内编码页码。
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

// 已发布（status 1）的帖子。
List<Map<String, dynamic>> _publishedPosts() {
  return _posts.where((post) => _statusOf(post) == 1).toList();
}

// 种子帖子未写 status 时视为已发布。
int _statusOf(Map<String, dynamic> post) =>
    (post['status'] as num?)?.toInt() ?? 1;

// 按 ID 查帖子，不存在抛 404/2001。
Map<String, dynamic> _findPost(int postId) {
  return _posts.firstWhere(
    (post) => (post['id'] as num).toInt() == postId,
    orElse: () => throw const _MockBiz(404, 2001, '内容不存在'),
  );
}

// 按 ID 查帖子下标，供原地替换或删除。
int _postIndex(int postId) {
  final idx = _posts.indexWhere(
    (post) => (post['id'] as num).toInt() == postId,
  );
  if (idx < 0) throw const _MockBiz(404, 2001, '内容不存在');
  return idx;
}

// 跨帖子按 ID 查评论。
Map<String, dynamic> _findComment(int commentId) {
  for (final entry in _comments.entries) {
    for (final comment in entry.value) {
      if ((comment['id'] as num).toInt() == commentId) return comment;
    }
  }
  throw const _MockBiz(404, 4, '资源不存在');
}

// 帖子字段校验：标题 1~120 字、正文 1~20000 字、图片不超过 9 张、标签不超过 10 个。
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
