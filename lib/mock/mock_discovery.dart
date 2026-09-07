part of 'mock_router.dart';

MockRouterResponse _recommendFeed(Map<String, String> query, _Auth auth) {
  final requestId = query['requestId']?.trim() ?? '';
  final pageSize = _queryInt(query, 'pageSize', defaultValue: 20);
  if (requestId.isEmpty || pageSize <= 0 || pageSize > 100) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  if (!auth.isAuthenticated && (query['anonymousId']?.trim() ?? '').isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final published = _publishedPosts();
  final cursor = query['cursor'] ?? '';
  final offset = cursor.isEmpty ? 0 : _decodeRecommendCursor(cursor);
  if (offset == null || offset < 0 || offset > published.length) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final end = (offset + pageSize).clamp(0, published.length).toInt();
  final experimentId = query['experimentId']?.trim().isNotEmpty == true
      ? query['experimentId']!.trim()
      : 'mock-home-v1';
  const recallSources = ['popular', 'latest', 'itemcf'];
  final items = <Map<String, dynamic>>[];
  for (var index = offset; index < end; index++) {
    final post = published[index];
    items.add(
      _feedItem(
        post,
        auth.userId,
        feedType: 2,
        extra: {
          'score': 1 - (index * 0.05),
          'reason':
              '${recallSources[index % recallSources.length]} recommendation',
          'recallSource': recallSources[index % recallSources.length],
          'modelVersion': 'mock-rank-v1',
          'experimentId': experimentId,
          'position': index + 1,
        },
      ),
    );
  }
  return _jsonResponse({
    'items': items,
    'nextCursor': end < published.length ? _encodeRecommendCursor(end) : '',
    'hasMore': end < published.length,
    'requestId': requestId,
  });
}

MockRouterResponse _followFeed(Map<String, String> query, _Auth auth) {
  final pageSize = _queryInt(query, 'pageSize', defaultValue: 20);
  final cursorCreatedAt = _queryInt(query, 'cursorCreatedAt', defaultValue: 0);
  final cursorPostId = _queryInt(query, 'cursorPostId', defaultValue: 0);
  if (pageSize <= 0 ||
      pageSize > 100 ||
      cursorCreatedAt < 0 ||
      cursorPostId < 0) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final following = _followedByUser[auth.userId] ?? const <int>{};
  final sorted =
      _publishedPosts()
          .where(
            (post) => following.contains((post['authorId'] as num).toInt()),
          )
          .toList()
        ..sort((a, b) {
          final createdAt = (b['createdAt'] as num).compareTo(
            a['createdAt'] as num,
          );
          if (createdAt != 0) return createdAt;
          return (b['id'] as num).compareTo(a['id'] as num);
        });
  final hasCursor = cursorCreatedAt != 0 || cursorPostId != 0;
  final candidates = sorted.where((post) {
    if (!hasCursor) return true;
    final createdAt = (post['createdAt'] as num).toInt();
    final postId = (post['id'] as num).toInt();
    return createdAt < cursorCreatedAt ||
        (createdAt == cursorCreatedAt && postId < cursorPostId);
  }).toList();
  final page = candidates.take(pageSize).toList();
  final items = [
    for (final post in page) _feedItem(post, auth.userId, feedType: 1),
  ];
  final last = page.isEmpty ? null : page.last;
  return _jsonResponse({
    'items': items,
    'hasMore': candidates.length > page.length,
    'nextCursorCreatedAt': last?['createdAt'] ?? 0,
    'nextCursorPostId': last?['id'] ?? 0,
  });
}

MockRouterResponse _behaviorEvents(Map<String, dynamic>? body, _Auth auth) {
  final anonymousId = body?['anonymousId']?.toString().trim() ?? '';
  if (!auth.isAuthenticated && anonymousId.isEmpty) {
    throw const _MockBiz(400, 2, '匿名行为必须提供 anonymousId');
  }
  final rawEvents = body?['events'];
  if (rawEvents is! List || rawEvents.isEmpty || rawEvents.length > 100) {
    throw const _MockBiz(400, 2, '行为事件数量必须在 1 到 100 之间');
  }
  final results = <Map<String, dynamic>>[];
  var acceptedCount = 0;
  for (final rawEvent in rawEvents) {
    final event = rawEvent is Map
        ? Map<String, dynamic>.from(rawEvent)
        : const <String, dynamic>{};
    final clientEventId = event['clientEventId']?.toString().trim() ?? '';
    final reason = _behaviorRejectReason(event, clientEventId);
    final accepted = reason == null;
    if (accepted) acceptedCount++;
    results.add({
      'clientEventId': clientEventId,
      'eventId': accepted
          ? _behaviorEventIds.putIfAbsent(
              clientEventId,
              () => _behaviorEventIds.length + 1000,
            )
          : 0,
      'accepted': accepted,
      'code': accepted ? 0 : 2,
      'reason': reason ?? '',
    });
  }
  return _jsonResponse({
    'results': results,
    'acceptedCount': acceptedCount,
    'rejectedCount': rawEvents.length - acceptedCount,
  }, statusCode: 202);
}

String? _behaviorRejectReason(
  Map<String, dynamic> event,
  String clientEventId,
) {
  if (clientEventId.isEmpty) return 'client_event_id is required';
  if (clientEventId.length > 128) return 'client_event_id is too long';
  final occurredAt = (event['occurredAt'] as num?)?.toInt() ?? 0;
  if (occurredAt <= 0) return 'event_time is required';
  final action = event['action']?.toString() ?? '';
  if (!_supportedActions.contains(action)) return 'action is unsupported';
  final targetId = (event['targetId'] as num?)?.toInt() ?? 0;
  if (targetId <= 0) return 'target_id is required';
  final targetType = event['targetType']?.toString().trim() ?? '';
  if (targetType.isEmpty) return 'target_type is required';
  final position = (event['position'] as num?)?.toInt();
  if (position != null && position < 0) return 'position must not be negative';
  if (action == 'exposure') {
    if ((event['requestId']?.toString().trim() ?? '').isEmpty) {
      return 'request_id is required for exposure';
    }
    if ((event['scene']?.toString().trim() ?? '').isEmpty) {
      return 'scene is required for exposure';
    }
    if (position == null) return 'position is required for exposure';
    if (position < 1) return 'position must start from 1 for exposure';
  }
  final durationMs = (event['durationMs'] as num?)?.toInt();
  if (durationMs != null && durationMs < 0) {
    return 'duration_ms must not be negative';
  }
  if (durationMs != null && !_durationActions.contains(action)) {
    return 'duration_ms is not allowed for action $action';
  }
  if (_durationActions.contains(action) && durationMs == null) {
    return 'duration_ms is required for action $action';
  }
  if (!_clientAllowedActions.contains(action)) {
    return 'action $action is not allowed from clients';
  }
  return null;
}

MockRouterResponse _search(
  Map<String, String> query, {
  bool includePosts = false,
  bool usersOnly = false,
}) {
  final page = _queryInt(query, 'page', defaultValue: 1);
  final pageSize = _queryInt(query, 'pageSize', defaultValue: 20);
  if (page <= 0 || pageSize <= 0 || pageSize > 100) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final keyword = (query['keyword'] ?? '').trim();
  if (keyword.isEmpty) throw const _MockBiz(400, 5001, '搜索关键词为空');
  final normalized = keyword.toLowerCase();
  final matchingPosts = _publishedPosts().where((post) {
    final tags = _stringList(post['tags']).join(' ').toLowerCase();
    return '${post['title']} ${post['content']} $tags'.toLowerCase().contains(
      normalized,
    );
  }).toList();
  final matchingUsers = _users.values.where((user) {
    return '${user['username']} ${user['nickname']} ${user['bio']}'
        .toLowerCase()
        .contains(normalized);
  }).toList();
  final offset = (page - 1) * pageSize;
  List<Map<String, dynamic>> pageOf(List<Map<String, dynamic>> values) =>
      values.skip(offset).take(pageSize).toList(growable: false);

  if (usersOnly) {
    return _jsonResponse({
      'users': pageOf(matchingUsers).map(_searchUser).toList(),
      'total': matchingUsers.length,
    });
  }
  return _jsonResponse({
    'posts': pageOf(matchingPosts).map(_searchPost).toList(),
    'users': pageOf(matchingUsers).map(_searchUser).toList(),
    'tags': _matchingTags(normalized, pageSize),
    'degraded': false,
    'unavailableTypes': <String>[],
  });
}

MockRouterResponse _searchTags(Map<String, String> query) {
  final limit = _queryInt(query, 'limit', defaultValue: 20);
  if (limit <= 0 || limit > 100) throw const _MockBiz(400, 2, '参数错误');
  final keyword = (query['keyword'] ?? '').trim();
  if (keyword.isEmpty) throw const _MockBiz(400, 5001, '搜索关键词为空');
  return _jsonResponse({'tags': _matchingTags(keyword.toLowerCase(), limit)});
}

Map<String, dynamic> _feedItem(
  Map<String, dynamic> post,
  int viewerId, {
  required int feedType,
  Map<String, dynamic> extra = const {},
}) {
  final item = _postItem(post, viewerId);
  return {
    'postId': item['id'],
    'authorId': item['authorId'],
    'authorName': item['authorName'],
    'authorAvatar': item['authorAvatar'],
    'createdAt': item['createdAt'],
    'feedType': feedType,
    'title': item['title'],
    'content': item['content'],
    'images': item['images'],
    'tags': item['tags'],
    'viewCount': item['viewCount'],
    'likeCount': item['likeCount'],
    'commentCount': item['commentCount'],
    'favoriteCount': item['favoriteCount'],
    'isLiked': item['isLiked'],
    ...extra,
  };
}

Map<String, dynamic> _searchPost(Map<String, dynamic> post) {
  final content = post['content']?.toString() ?? '';
  return {
    'id': post['id'],
    'title': post['title'],
    'contentHighlight': content.length > 120
        ? '${content.substring(0, 120)}...'
        : content,
    'authorId': post['authorId'],
    'authorName': post['authorName'],
    'authorAvatar': post['authorAvatar'],
    'likeCount': post['likeCount'],
    'commentCount': (_comments[(post['id'] as num).toInt()] ?? const []).length,
    'createdAt': post['createdAt'],
  };
}

Map<String, dynamic> _searchUser(Map<String, dynamic> user) {
  return {
    'id': user['id'],
    'username': user['username'],
    'nickname': user['nickname'],
    'avatarUrl': user['avatarUrl'],
    'bio': user['bio'],
    'followerCount': user['followerCount'],
  };
}

List<Map<String, dynamic>> _matchingTags(String normalized, int limit) {
  final tagCounts = <String, int>{};
  for (final post in _publishedPosts()) {
    for (final tag in _stringList(post['tags'])) {
      if (tag.toLowerCase().contains(normalized)) {
        tagCounts.update(tag, (count) => count + 1, ifAbsent: () => 1);
      }
    }
  }
  final tags =
      tagCounts.entries
          .map((entry) => {'name': entry.key, 'postCount': entry.value})
          .toList()
        ..sort(
          (a, b) => (b['postCount'] as int).compareTo(a['postCount'] as int),
        );
  return tags.take(limit).toList(growable: false);
}

/// 与网关契约对齐的游标分页：游标为 base64url(JSON{"p":页码})，首页传空。
String _encodeCursorPage(int page) {
  final raw = utf8.encode(jsonEncode({'p': page}));
  return base64Url.encode(raw).replaceAll('=', '');
}

int _decodeCursorPage(String cursor) {
  if (cursor.isEmpty) return 1;
  try {
    final raw = utf8.decode(base64Url.decode(base64Url.normalize(cursor)));
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return 0;
    return (decoded['p'] as num?)?.toInt() ?? 0;
  } catch (_) {
    throw const _MockBiz(400, 2, '参数错误');
  }
}

String _encodeRecommendCursor(int offset) {
  return 'mock_${base64Url.encode(utf8.encode('$offset')).replaceAll('=', '')}';
}

int? _decodeRecommendCursor(String cursor) {
  if (!cursor.startsWith('mock_')) return null;
  try {
    final encoded = base64Url.normalize(cursor.substring(5));
    return int.tryParse(utf8.decode(base64Url.decode(encoded)));
  } catch (_) {
    return null;
  }
}
