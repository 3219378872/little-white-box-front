import 'dart:convert';

import 'mock_data.dart';

/// Mock 路由分发 + 内存状态

int _nextPostId = 100;
int _nextCommentId = 200;
int _nextBehaviorEventId = 1000;
int _nextMessageId = 10000;
int _nextConversationId = 100;

final List<Map<String, dynamic>> _posts = seedPosts
    .map((p) => Map<String, dynamic>.from(p))
    .toList();

final Map<int, List<Map<String, dynamic>>> _comments = seedComments.map(
  (k, v) => MapEntry(k, v.map((c) => Map<String, dynamic>.from(c)).toList()),
);

final Map<int, Map<String, dynamic>> _users = seedUsers.map(
  (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
);

final Set<int> _likedPostIds = seedPosts
    .where((post) => post['isLiked'] == true)
    .map((post) => (post['id'] as num).toInt())
    .toSet();
final Set<int> _favoritedPostIds = {};
final Set<int> _followedUserIds = {};
bool _personalizationEnabled = true;
final Map<String, int> _postIdempotencyKeys = {};
final Map<String, int> _behaviorEventIds = {};
final Map<String, int> _messageIdempotencyKeys = {};
final int _messageSeedTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
final List<Map<String, dynamic>> _mockConversations = [
  {
    'id': 11,
    'targetUserId': 2,
    'targetUserName': '萌萌哒小兔',
    'targetUserAvatar': '',
    'lastMessage': '周末一起去探店吗？',
    'lastMessageTime': 0,
    'unreadCount': 2,
  },
  {
    'id': 12,
    'targetUserId': 3,
    'targetUserName': '科技宅小明',
    'targetUserAvatar': '',
    'lastMessage': '评测文章已经更新啦',
    'lastMessageTime': 0,
    'unreadCount': 0,
  },
];
final Map<int, List<Map<String, dynamic>>> _mockMessages = {
  11: [
    {
      'id': 101,
      'conversationId': 11,
      'senderId': 2,
      'receiverId': 1,
      'content': '发现一家新的面馆，味道很不错。',
      'msgType': 1,
      'status': 1,
      'createdAt': 0,
    },
    {
      'id': 102,
      'conversationId': 11,
      'senderId': 2,
      'receiverId': 1,
      'content': '周末一起去探店吗？',
      'msgType': 1,
      'status': 1,
      'createdAt': 0,
    },
  ],
  12: [
    {
      'id': 201,
      'conversationId': 12,
      'senderId': 1,
      'receiverId': 3,
      'content': '想看看最近的手机推荐。',
      'msgType': 1,
      'status': 1,
      'createdAt': 0,
    },
    {
      'id': 202,
      'conversationId': 12,
      'senderId': 3,
      'receiverId': 1,
      'content': '评测文章已经更新啦',
      'msgType': 1,
      'status': 1,
      'createdAt': 0,
    },
  ],
};

class MockRouterResponse {
  final String body;
  final int statusCode;
  final Map<String, String> headers;

  const MockRouterResponse({
    required this.body,
    required this.statusCode,
    required this.headers,
  });
}

/// 分发请求，返回完整的 JSON 响应字符串
String dispatch(String method, String path, String requestBody) {
  return dispatchResponse(method, path, requestBody).body;
}

/// Structured dispatch used by the mock HTTP client to preserve HTTP semantics.
MockRouterResponse dispatchResponse(
  String method,
  String path,
  String requestBody, {
  Map<String, String> headers = const {},
}) {
  final uri = Uri.parse('http://mock$path');
  final segments = uri.pathSegments; // ['api', 'v1', ...]
  final query = uri.queryParameters;
  final isV2 = segments.length >= 2 && segments[1] == 'v2';

  Map<String, dynamic>? body;
  if (requestBody.isNotEmpty) {
    try {
      final decoded = jsonDecode(requestBody);
      body = decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      body = {};
    }
  }

  try {
    if (isV2) {
      return _routeV2(method.toUpperCase(), segments, query, body, headers);
    }

    final data = _route(method.toUpperCase(), segments, query, body);
    return _jsonResponse({'code': 0, 'desc': 'ok', 'data': data});
  } catch (e) {
    if (isV2) {
      return _errorResponse(500, 3, e.toString());
    }
    return _jsonResponse({'code': 1, 'desc': e.toString(), 'data': null});
  }
}

MockRouterResponse _routeV2(
  String method,
  List<String> segments,
  Map<String, String> query,
  Map<String, dynamic>? body,
  Map<String, String> headers,
) {
  final route = segments.join('/');
  final authState = _authState(headers);

  switch (route) {
    case 'api/v2/feed/recommend':
      if (method != 'GET') return _methodNotAllowed();
      return _handleRecommendFeed(query, authState);
    case 'api/v2/feed/follow':
      if (method != 'GET') return _methodNotAllowed();
      return _handleFollowFeed(query, authState);
    case 'api/v2/behavior/events':
      if (method != 'POST') return _methodNotAllowed();
      return _handleBehaviorEvents(body, authState);
    case 'api/v2/search':
      if (method != 'GET') return _methodNotAllowed();
      return _handleV2Search(query, includePosts: true);
    case 'api/v2/search/users':
      if (method != 'GET') return _methodNotAllowed();
      return _handleV2Search(query, usersOnly: true);
    case 'api/v2/search/tags':
      if (method != 'GET') return _methodNotAllowed();
      return _handleV2Search(query, tagsOnly: true);
    case 'api/v2/assistant/chat':
      if (method != 'POST') return _methodNotAllowed();
      return _handleAssistantChat(body, authState);
    case 'api/v2/me/personalization':
      return _handlePersonalization(method, body, authState);
    default:
      if (segments.length >= 3 && segments[2] == 'post') {
        return _handleV2Post(method, segments, body, authState);
      }
      if (segments.length >= 3 && segments[2] == 'messages') {
        return _handleV2Messages(method, segments, query, body, authState);
      }
      return _errorResponse(404, 4, 'resource not found');
  }
}

MockRouterResponse _handleRecommendFeed(
  Map<String, String> query,
  String authState,
) {
  final anonymousId = query['anonymousId']?.trim() ?? '';
  if (authState != 'authenticated' && anonymousId.isEmpty) {
    return _errorResponse(400, 2, 'anonymousId is required', authState);
  }

  final requestId = query['requestId']?.trim() ?? '';
  if (requestId.isEmpty) {
    return _errorResponse(400, 2, 'requestId is required', authState);
  }

  final pageSize = _pageSize(query);
  if (pageSize == null) {
    return _errorResponse(400, 2, 'invalid pageSize', authState);
  }

  final cursor = query['cursor'] ?? '';
  final offset = cursor.isEmpty ? 0 : _decodeRecommendCursor(cursor);
  if (offset == null || offset > _posts.length) {
    return _errorResponse(400, 2, 'invalid cursor', authState);
  }

  final end = (offset + pageSize).clamp(0, _posts.length).toInt();
  final experimentId = query['experimentId']?.trim().isNotEmpty == true
      ? query['experimentId']!.trim()
      : 'mock-home-v1';
  const recallSources = ['popular', 'latest', 'itemcf'];
  final items = <Map<String, dynamic>>[];
  for (var index = offset; index < end; index++) {
    final post = _posts[index];
    final source = recallSources[index % recallSources.length];
    items.add({
      'postId': post['id'],
      'feedType': 2,
      'post': _postSnapshot(post),
      'score': 1 - (index * 0.05),
      'reason': '$source recommendation',
      'recallSource': source,
      'modelVersion': 'mock-rank-v1',
      'experimentId': experimentId,
      'position': index + 1,
    });
  }

  final hasMore = end < _posts.length;
  return _jsonResponse(
    {
      'items': items,
      'nextCursor': hasMore ? _encodeRecommendCursor(end) : '',
      'hasMore': hasMore,
      'requestId': requestId,
    },
    headers: {'x-auth-state': authState},
  );
}

MockRouterResponse _handleFollowFeed(
  Map<String, String> query,
  String authState,
) {
  if (authState != 'authenticated') {
    return _errorResponse(401, 1006, 'login required', authState);
  }

  final pageSize = _pageSize(query);
  final cursorCreatedAt = int.tryParse(query['cursorCreatedAt'] ?? '0');
  final cursorPostId = int.tryParse(query['cursorPostId'] ?? '0');
  if (pageSize == null ||
      cursorCreatedAt == null ||
      cursorPostId == null ||
      cursorCreatedAt < 0 ||
      cursorPostId < 0) {
    return _errorResponse(400, 2, 'invalid cursor or pageSize', authState);
  }

  final sorted =
      _posts.where((post) => (post['authorId'] as num).toInt() != 1).toList()
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

  final items = <Map<String, dynamic>>[];
  for (final post in page) {
    final globalPosition =
        sorted.indexWhere((candidate) => candidate['id'] == post['id']) + 1;
    items.add({
      'postId': post['id'],
      'authorId': post['authorId'],
      'createdAt': post['createdAt'],
      'feedType': 1,
      'post': _postSnapshot(post),
      'score': 1.0,
      'reason': 'followed author',
      'recallSource': 'follow',
      'modelVersion': 'mock-follow-v1',
      'experimentId': '',
      'position': globalPosition,
    });
  }

  final last = page.isEmpty ? null : page.last;
  return _jsonResponse(
    {
      'items': items,
      'hasMore': candidates.length > page.length,
      'nextCursorCreatedAt': last?['createdAt'] ?? 0,
      'nextCursorPostId': last?['id'] ?? 0,
    },
    headers: {'x-auth-state': authState},
  );
}

MockRouterResponse _handleBehaviorEvents(
  Map<String, dynamic>? body,
  String authState,
) {
  final anonymousId = body?['anonymousId']?.toString().trim() ?? '';
  if (authState != 'authenticated' && anonymousId.isEmpty) {
    return _errorResponse(400, 2, 'anonymousId is required', authState);
  }

  final rawEvents = body?['events'];
  if (rawEvents is! List || rawEvents.isEmpty || rawEvents.length > 100) {
    return _errorResponse(
      400,
      2,
      'events must contain 1 to 100 items',
      authState,
    );
  }

  final results = <Map<String, dynamic>>[];
  var acceptedCount = 0;
  for (final rawEvent in rawEvents) {
    final event = rawEvent is Map ? rawEvent : const <String, dynamic>{};
    final clientEventId = event['clientEventId']?.toString().trim() ?? '';
    final action = event['action']?.toString() ?? '';
    const forbidden = {
      'like',
      'unlike',
      'favorite',
      'unfavorite',
      'comment',
      'follow',
      'unfollow',
    };
    final accepted = clientEventId.isNotEmpty && !forbidden.contains(action);
    if (accepted) acceptedCount++;
    results.add({
      'clientEventId': clientEventId,
      'eventId': accepted
          ? _behaviorEventIds.putIfAbsent(
              clientEventId,
              () => _nextBehaviorEventId++,
            )
          : 0,
      'accepted': accepted,
      'code': accepted ? 0 : 2,
      'reason': accepted
          ? ''
          : (forbidden.contains(action)
                ? 'client must not submit authoritative actions'
                : 'clientEventId is required'),
    });
  }

  return _jsonResponse(
    {
      'results': results,
      'acceptedCount': acceptedCount,
      'rejectedCount': rawEvents.length - acceptedCount,
    },
    statusCode: 202,
    headers: {'x-auth-state': authState},
  );
}

MockRouterResponse _handleV2Search(
  Map<String, String> query, {
  bool includePosts = false,
  bool usersOnly = false,
  bool tagsOnly = false,
}) {
  final keyword = query['keyword']?.trim() ?? '';
  if (keyword.isEmpty) return _errorResponse(400, 2, 'keyword is required');
  final normalized = keyword.toLowerCase();
  final page = int.tryParse(query['page'] ?? '1');
  final pageSize = int.tryParse(query[tagsOnly ? 'limit' : 'pageSize'] ?? '20');
  if (page == null ||
      page <= 0 ||
      pageSize == null ||
      pageSize <= 0 ||
      pageSize > 100) {
    return _errorResponse(400, 2, 'invalid pagination');
  }

  final matchingPosts = _posts.where((post) {
    final tags = (post['tags'] as List<dynamic>? ?? const [])
        .map((tag) => tag.toString().toLowerCase())
        .join(' ');
    final text = '${post['title']} ${post['content']} $tags'.toLowerCase();
    return text.contains(normalized);
  }).toList();
  final matchingUsers = _users.values.where((user) {
    final text = '${user['username']} ${user['nickname']} ${user['bio']}'
        .toLowerCase();
    return text.contains(normalized);
  }).toList();
  final tagCounts = <String, int>{};
  for (final post in _posts) {
    for (final rawTag in post['tags'] as List<dynamic>? ?? const []) {
      final tag = rawTag.toString();
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

  final offset = (page - 1) * pageSize;
  List<Map<String, dynamic>> pageOf(List<Map<String, dynamic>> values) =>
      values.skip(offset).take(pageSize).toList(growable: false);
  final postResults = pageOf(matchingPosts)
      .map((post) {
        final content = post['content']?.toString() ?? '';
        return {
          'id': post['id'],
          'title': post['title'],
          'contentHighlight': content.length > 120
              ? '${content.substring(0, 120)}...'
              : content,
          'authorName': post['authorName'],
          'likeCount': post['likeCount'],
          'commentCount': post['commentCount'],
          'createdAt': post['createdAt'],
        };
      })
      .toList(growable: false);
  final userResults = pageOf(matchingUsers)
      .map(
        (user) => {
          'id': user['id'],
          'username': user['username'],
          'nickname': user['nickname'],
          'avatarUrl': user['avatarUrl'],
          'bio': user['bio'],
          'followerCount': user['followerCount'],
        },
      )
      .toList(growable: false);

  if (usersOnly) {
    return _jsonResponse({'users': userResults, 'total': matchingUsers.length});
  }
  if (tagsOnly) {
    return _jsonResponse({'tags': tags.take(pageSize).toList(growable: false)});
  }
  if (includePosts) {
    return _jsonResponse({
      'posts': postResults,
      'users': userResults,
      'tags': tags.take(pageSize).toList(growable: false),
      'degraded': false,
      'unavailableTypes': <String>[],
    });
  }
  return _errorResponse(404, 4, 'resource not found');
}

MockRouterResponse _handleV2Messages(
  String method,
  List<String> segments,
  Map<String, String> query,
  Map<String, dynamic>? body,
  String authState,
) {
  if (authState != 'authenticated') {
    return _errorResponse(401, 1006, 'login required', authState);
  }

  if (segments.length == 3 && method == 'POST') {
    return _sendMockMessage(body, authState);
  }
  if (segments.length == 4 && segments[3] == 'unread' && method == 'GET') {
    final messageUnread = _mockConversations.fold<int>(
      0,
      (total, conversation) =>
          total + ((conversation['unreadCount'] as num?)?.toInt() ?? 0),
    );
    return _jsonResponse(
      {'messageUnread': messageUnread, 'notificationUnread': 2},
      headers: {'x-auth-state': authState},
    );
  }
  if (segments.length == 4 &&
      segments[3] == 'conversations' &&
      method == 'GET') {
    final page = int.tryParse(query['page'] ?? '1');
    final pageSize = int.tryParse(query['pageSize'] ?? '20');
    if (page == null ||
        page <= 0 ||
        pageSize == null ||
        pageSize <= 0 ||
        pageSize > 100) {
      return _errorResponse(400, 2, 'invalid pagination', authState);
    }
    _initializeMockMessageTimes();
    final sorted =
        _mockConversations
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
          ..sort(
            (a, b) => (b['lastMessageTime'] as int).compareTo(
              a['lastMessageTime'] as int,
            ),
          );
    final offset = (page - 1) * pageSize;
    return _jsonResponse(
      {
        'conversations': sorted.skip(offset).take(pageSize).toList(),
        'total': sorted.length,
      },
      headers: {'x-auth-state': authState},
    );
  }
  if (segments.length >= 5 && segments[3] == 'conversations') {
    final conversationId = int.tryParse(segments[4]);
    final conversation = _mockConversations.where(
      (item) => item['id'] == conversationId,
    );
    if (conversationId == null || conversation.isEmpty) {
      return _errorResponse(404, 4, 'conversation not found', authState);
    }
    if (segments.length == 6 && segments[5] == 'read' && method == 'POST') {
      conversation.first['unreadCount'] = 0;
      return _jsonResponse(const {}, headers: {'x-auth-state': authState});
    }
    if (segments.length == 5 && method == 'GET') {
      _initializeMockMessageTimes();
      final lastId = int.tryParse(query['lastId'] ?? '0');
      final pageSize = int.tryParse(query['pageSize'] ?? '20');
      if (lastId == null ||
          lastId < 0 ||
          pageSize == null ||
          pageSize <= 0 ||
          pageSize > 100) {
        return _errorResponse(400, 2, 'invalid pagination', authState);
      }
      final all =
          (_mockMessages[conversationId] ?? const [])
              .where(
                (message) => lastId == 0 || (message['id'] as int) < lastId,
              )
              .map((message) => Map<String, dynamic>.from(message))
              .toList()
            ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      return _jsonResponse(
        {
          'messages': all.take(pageSize).toList(growable: false),
          'hasMore': all.length > pageSize,
        },
        headers: {'x-auth-state': authState},
      );
    }
  }
  return _errorResponse(404, 4, 'resource not found', authState);
}

MockRouterResponse _sendMockMessage(
  Map<String, dynamic>? body,
  String authState,
) {
  final receiverId = (body?['receiverId'] as num?)?.toInt();
  final content = body?['content']?.toString().trim() ?? '';
  final msgType = (body?['msgType'] as num?)?.toInt() ?? 1;
  final idempotencyKey = body?['idempotencyKey']?.toString().trim() ?? '';
  if (receiverId == null ||
      receiverId <= 0 ||
      content.isEmpty ||
      msgType < 1 ||
      msgType > 4 ||
      idempotencyKey.isEmpty) {
    return _errorResponse(400, 2, 'invalid message', authState);
  }
  final existing = _messageIdempotencyKeys[idempotencyKey];
  if (existing != null) {
    return _jsonResponse(
      {'messageId': existing},
      headers: {'x-auth-state': authState},
    );
  }

  var conversation = _mockConversations
      .where((item) => item['targetUserId'] == receiverId)
      .firstOrNull;
  if (conversation == null) {
    final user = _users[receiverId];
    conversation = {
      'id': _nextConversationId++,
      'targetUserId': receiverId,
      'targetUserName': user?['nickname'] ?? '用户 $receiverId',
      'targetUserAvatar': user?['avatarUrl'] ?? '',
      'lastMessage': '',
      'lastMessageTime': 0,
      'unreadCount': 0,
    };
    _mockConversations.add(conversation);
  }
  final messageId = _nextMessageId++;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final conversationId = conversation['id'] as int;
  _mockMessages.putIfAbsent(conversationId, () => []).add({
    'id': messageId,
    'conversationId': conversationId,
    'senderId': 1,
    'receiverId': receiverId,
    'content': content,
    'msgType': msgType,
    'status': 1,
    'createdAt': now,
  });
  conversation['lastMessage'] = content;
  conversation['lastMessageTime'] = now;
  _messageIdempotencyKeys[idempotencyKey] = messageId;
  return _jsonResponse(
    {'messageId': messageId},
    headers: {'x-auth-state': authState},
  );
}

void _initializeMockMessageTimes() {
  if (_mockConversations.first['lastMessageTime'] != 0) return;
  _mockConversations[0]['lastMessageTime'] = _messageSeedTime - 300;
  _mockConversations[1]['lastMessageTime'] = _messageSeedTime - 3600;
  _mockMessages[11]![0]['createdAt'] = _messageSeedTime - 900;
  _mockMessages[11]![1]['createdAt'] = _messageSeedTime - 300;
  _mockMessages[12]![0]['createdAt'] = _messageSeedTime - 7200;
  _mockMessages[12]![1]['createdAt'] = _messageSeedTime - 3600;
}

MockRouterResponse _handleAssistantChat(
  Map<String, dynamic>? body,
  String authState,
) {
  if (authState != 'authenticated') {
    return _errorResponse(401, 1006, 'login required', authState);
  }
  final message = body?['message']?.toString().trim() ?? '';
  final requestId = body?['requestId']?.toString().trim() ?? '';
  if (message.isEmpty || message.length > 2000 || requestId.isEmpty) {
    return _errorResponse(400, 2, 'invalid assistant request', authState);
  }
  final conversationId =
      body?['conversationId']?.toString().trim().isNotEmpty == true
      ? body!['conversationId'].toString().trim()
      : 'mock-$requestId';
  final events = [
    {
      'type': 'token',
      'text': '我根据社区内容找到了与“$message”相关的信息。',
      'conversationId': conversationId,
    },
    {
      'type': 'source',
      'source': {
        'sourceType': 'post',
        'sourceId': '${_posts.first['id']}',
        'title': _posts.first['title'],
      },
      'conversationId': conversationId,
    },
    {'type': 'done', 'conversationId': conversationId},
  ];
  final payload = events
      .map((event) => 'data: ${jsonEncode(event)}\n\n')
      .join();
  return MockRouterResponse(
    body: payload,
    statusCode: 200,
    headers: {
      'content-type': 'text/event-stream; charset=utf-8',
      'cache-control': 'no-cache',
      'x-auth-state': authState,
    },
  );
}

Map<String, dynamic> _postSnapshot(Map<String, dynamic> post) {
  final postId = (post['id'] as num).toInt();
  return {
    ...post,
    'status': post['status'] ?? 1,
    'revision': post['revision'] ?? 1,
    'favoriteCount': post['favoriteCount'] ?? 0,
    'isLiked': _likedPostIds.contains(postId),
    'isFavorited': _favoritedPostIds.contains(postId),
  };
}

MockRouterResponse _handlePersonalization(
  String method,
  Map<String, dynamic>? body,
  String authState,
) {
  if (authState != 'authenticated') {
    return _errorResponse(401, 1006, 'login required', authState);
  }
  if (method == 'GET') {
    return _jsonResponse(
      {
        'enabled': _personalizationEnabled,
        'optedOutAt': _personalizationEnabled
            ? 0
            : DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      headers: {'x-auth-state': authState},
    );
  }
  if (method == 'PUT') {
    _personalizationEnabled = body?['enabled'] == true;
    return _jsonResponse(const {}, headers: {'x-auth-state': authState});
  }
  return _methodNotAllowed();
}

MockRouterResponse _handleV2Post(
  String method,
  List<String> segments,
  Map<String, dynamic>? body,
  String authState,
) {
  if (authState != 'authenticated') {
    return _errorResponse(401, 1006, 'login required', authState);
  }
  if (method == 'POST' && segments.length == 3) {
    final key = body?['idempotencyKey']?.toString().trim() ?? '';
    if (key.isNotEmpty && _postIdempotencyKeys.containsKey(key)) {
      final existingId = _postIdempotencyKeys[key]!;
      final existing = _posts.firstWhere((post) => post['id'] == existingId);
      return _jsonResponse(
        {
          'postId': existingId,
          'status': existing['status'] ?? 1,
          'revision': existing['revision'] ?? 1,
        },
        headers: {'x-auth-state': authState},
      );
    }
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
      'status': body?['status'] ?? 1,
      'revision': 1,
      'viewCount': 0,
      'likeCount': 0,
      'isLiked': false,
      'commentCount': 0,
      'favoriteCount': 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
    _posts.insert(0, newPost);
    if (key.isNotEmpty) _postIdempotencyKeys[key] = newId;
    return _jsonResponse(
      {'postId': newId, 'status': newPost['status'], 'revision': 1},
      headers: {'x-auth-state': authState},
    );
  }
  if (segments.length < 4) {
    return _errorResponse(404, 4, 'resource not found', authState);
  }
  final postId = int.tryParse(segments[3]) ?? 0;
  final idx = _posts.indexWhere((post) => post['id'] == postId);
  if (idx < 0) return _errorResponse(404, 2001, '帖子不存在', authState);
  final expected = (body?['expectedRevision'] as num?)?.toInt() ?? 0;
  final current = (_posts[idx]['revision'] as num?)?.toInt() ?? 1;
  if (expected <= 0) {
    return _errorResponse(400, 2, 'expectedRevision required', authState);
  }
  if (expected != current) {
    return _errorResponse(409, 2007, '内容版本冲突', authState);
  }
  if (method == 'PUT') {
    _posts[idx] = {
      ..._posts[idx],
      'title': body?['title'] ?? _posts[idx]['title'],
      'content': body?['content'] ?? _posts[idx]['content'],
      'images': body?['images'] ?? _posts[idx]['images'],
      'tags': body?['tags'] ?? _posts[idx]['tags'],
      'status': body?['status'] ?? _posts[idx]['status'] ?? 1,
      'revision': current + 1,
    };
    return _jsonResponse(
      {'status': _posts[idx]['status'], 'revision': current + 1},
      headers: {'x-auth-state': authState},
    );
  }
  if (method == 'DELETE') {
    _posts.removeAt(idx);
    _comments.remove(postId);
    return _jsonResponse(const {}, headers: {'x-auth-state': authState});
  }
  return _methodNotAllowed();
}

int? _pageSize(Map<String, String> query) {
  final value = int.tryParse(query['pageSize'] ?? '20');
  if (value == null || value <= 0 || value > 100) return null;
  return value;
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

String _authState(Map<String, String> headers) {
  var authorization = '';
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == 'authorization') {
      authorization = entry.value.trim();
      break;
    }
  }
  if (authorization.isEmpty) return 'anonymous';
  if (authorization.startsWith('Bearer ') &&
      authorization.substring(7).trim().isNotEmpty) {
    return 'authenticated';
  }
  return 'invalid';
}

MockRouterResponse _methodNotAllowed() {
  return _errorResponse(405, 1, 'method not allowed');
}

MockRouterResponse _errorResponse(
  int statusCode,
  int code,
  String message, [
  String? authState,
]) {
  return _jsonResponse(
    {'code': code, 'message': message, 'data': null},
    statusCode: statusCode,
    headers: authState == null ? const {} : {'x-auth-state': authState},
  );
}

MockRouterResponse _jsonResponse(
  Map<String, dynamic> payload, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) {
  return MockRouterResponse(
    body: jsonEncode(payload),
    statusCode: statusCode,
    headers: {'content-type': 'application/json; charset=utf-8', ...headers},
  );
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
      return _handleLike(method, body ?? {});

    case 'favorite':
      return _handleFavorite(method, body ?? {});

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
  final slice = start >= sorted.length
      ? <Map<String, dynamic>>[]
      : sorted.sublist(start, end.clamp(0, sorted.length));

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
  if (method != 'GET' || segments.length < 4) {
    throw Exception('use /api/v2/post');
  }
  final postId = int.tryParse(segments[3]) ?? 0;
  final post = _posts.firstWhere(
    (p) => p['id'] == postId,
    orElse: () => <String, dynamic>{},
  );
  if (post.isEmpty) throw Exception('帖子不存在');
  return _postSnapshot(post);
}

// ─── Comment List ───

Map<String, dynamic> _handleCommentList(
  List<String> segments,
  Map<String, String> query,
) {
  if (segments.length < 4) {
    return {'list': [], 'total': 0, 'page': 1, 'pageSize': 20};
  }

  final postId = int.tryParse(segments[3]) ?? 0;
  final page = int.tryParse(query['page'] ?? '1') ?? 1;
  final pageSize = int.tryParse(query['pageSize'] ?? '20') ?? 20;

  final all = _comments[postId] ?? [];
  final start = (page - 1) * pageSize;
  final end = start + pageSize;
  final slice = start >= all.length
      ? <Map<String, dynamic>>[]
      : all.sublist(start, end.clamp(0, all.length));

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

  if (method == 'DELETE' && segments.length >= 4) {
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

Map<String, dynamic> _handleLike(String method, Map<String, dynamic> body) {
  final targetId = (body['targetId'] as num?)?.toInt() ?? 0;
  final targetType = (body['targetType'] as num?)?.toInt() ?? 1;
  if (targetType != 1 || targetId <= 0) return {};
  final postIdx = _posts.indexWhere((p) => p['id'] == targetId);
  final liked = _likedPostIds.contains(targetId);
  if (method == 'DELETE') {
    if (!liked) return {};
    _likedPostIds.remove(targetId);
    if (postIdx >= 0) {
      _posts[postIdx] = {
        ..._posts[postIdx],
        'likeCount': ((_posts[postIdx]['likeCount'] as num).toInt() - 1).clamp(
          0,
          999999,
        ),
        'isLiked': false,
      };
    }
    return {};
  }
  if (liked) return {};
  _likedPostIds.add(targetId);
  if (postIdx >= 0) {
    _posts[postIdx] = {
      ..._posts[postIdx],
      'likeCount': (_posts[postIdx]['likeCount'] as num).toInt() + 1,
      'isLiked': true,
    };
  }
  return {};
}

// ─── Favorite (toggle) ───

Map<String, dynamic> _handleFavorite(String method, Map<String, dynamic> body) {
  final postId = (body['postId'] as num?)?.toInt() ?? 0;
  final postIdx = _posts.indexWhere((p) => p['id'] == postId);
  final favorited = _favoritedPostIds.contains(postId);
  if (method == 'DELETE') {
    if (!favorited) return {};
    _favoritedPostIds.remove(postId);
    if (postIdx >= 0) {
      _posts[postIdx] = {
        ..._posts[postIdx],
        'favoriteCount': ((_posts[postIdx]['favoriteCount'] as num).toInt() - 1)
            .clamp(0, 999999),
      };
    }
    return {};
  }
  if (favorited) return {};
  _favoritedPostIds.add(postId);
  if (postIdx >= 0) {
    _posts[postIdx] = {
      ..._posts[postIdx],
      'favoriteCount': (_posts[postIdx]['favoriteCount'] as num).toInt() + 1,
    };
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

  if (segments[3] == 'profile' && method == 'PUT' && body != null) {
    final user = _users[1]!;
    if (body.containsKey('nickname')) user['nickname'] = body['nickname'];
    if (body.containsKey('avatarUrl')) user['avatarUrl'] = body['avatarUrl'];
    if (body.containsKey('bio')) user['bio'] = body['bio'];
    return {};
  }

  if (segments[3] == 'follow' && body != null) {
    final targetUserId = (body['targetUserId'] as num?)?.toInt() ?? 0;
    final targetUser = _users[targetUserId];
    final following = _followedUserIds.contains(targetUserId);
    if (method == 'DELETE') {
      if (!following) return {};
      _followedUserIds.remove(targetUserId);
      if (targetUser != null) {
        targetUser['followerCount'] =
            ((targetUser['followerCount'] as num).toInt() - 1).clamp(0, 999999);
      }
      return {};
    }
    if (following) return {};
    _followedUserIds.add(targetUserId);
    if (targetUser != null) {
      targetUser['followerCount'] =
          (targetUser['followerCount'] as num).toInt() + 1;
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
    filtered =
        _posts.where((p) => (p['authorId'] as num).toInt() == userId).toList()
          ..sort(
            (a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int),
          );
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
