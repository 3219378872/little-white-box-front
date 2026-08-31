import 'dart:convert';

import 'package:characters/characters.dart';

import '../core/api/json_int64.dart';
import 'mock_data.dart';

/// In-memory Gateway mock aligned with `app/gateway/gateway.api`.
///
/// Success bodies are the typed payloads (no `{code,desc,data}` wrapper).
/// Errors use `{code, message}` and the same HTTP statuses as `errx`.

const mockDevPassword = '123456';

/// 与真实网关对齐：access token 30 分钟，refresh token 7 天。
const int _mockAccessTtlSeconds = 30 * 60;
const int _mockRefreshTtlSeconds = 7 * 24 * 60 * 60;

const _clientAllowedActions = {
  'exposure',
  'click',
  'dwell',
  'play',
  'view',
  'share',
  'hide',
  'dislike',
};

const _supportedActions = {
  ..._clientAllowedActions,
  'like',
  'unlike',
  'favorite',
  'unfavorite',
  'comment',
  'follow',
  'unfollow',
};

const _durationActions = {'dwell', 'play', 'view'};

int _nextPostId = 100;
int _nextCommentId = 200;
int _nextMessageId = 10000;
int _nextConversationId = 100;
int _nextUserId = 10;
int _nextMediaId = 1000;

late List<Map<String, dynamic>> _posts;
late Map<int, List<Map<String, dynamic>>> _comments;
late Map<int, Map<String, dynamic>> _users;
late Map<String, String> _passwords;
late Map<int, Set<int>> _likedByUser;
late Map<int, Set<int>> _favoritedByUser;
late Map<int, Set<int>> _followedByUser;
late Map<String, int> _postIdempotencyKeys;
late Map<String, int> _commentIdempotencyKeys;
late Map<String, int> _behaviorEventIds;
late Map<String, int> _messageIdempotencyKeys;
late List<Map<String, dynamic>> _conversations;
late Map<int, List<Map<String, dynamic>>> _messages;
late Map<int, bool> _personalizationEnabled;
late Map<int, Map<String, dynamic>> _agentConsent;
late Map<int, List<Map<String, dynamic>>> _assistantMemories;
late Map<int, List<Map<String, dynamic>>> _assistantWatches;
late Map<int, Map<String, dynamic>> _assistantThreads;
late Map<int, List<Map<String, dynamic>>> _assistantMessages;
late Map<int, List<Map<String, dynamic>>> _assistantRunEvents;
late Map<int, Map<String, dynamic>> _assistantRuns;
late Map<int, List<Map<String, dynamic>>> _assistantQueue;
late Map<int, List<Map<String, dynamic>>> _assistantMemoryChanges;
late int _messageSeedTime;
late Set<String> _usedRefreshTokens;
int _mockJwtNonce = 0;
int _nextWatchId = 1;
int _nextAssistantMessageId = 1;
int _nextAssistantRunId = 1;

int _nextMemoryId = 1;
int _nextChangeId = 1;

bool _seeded = false;

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

class _MockBiz implements Exception {
  final int statusCode;
  final int code;
  final String message;

  const _MockBiz(this.statusCode, this.code, this.message);
}

class _Auth {
  final String state;
  final int userId;

  const _Auth(this.state, this.userId);

  bool get isAuthenticated => state == 'authenticated' && userId > 0;
}

void resetMockState() {
  _nextPostId = 100;
  _nextCommentId = 200;
  _nextMessageId = 10000;
  _nextConversationId = 100;
  _nextUserId = 10;
  _nextMediaId = 1000;
  _posts = seedPosts.map(_copyMap).toList();
  _comments = {
    for (final entry in seedComments.entries)
      entry.key: entry.value.map(_copyMap).toList(),
  };
  _users = {
    for (final entry in seedUsers.entries) entry.key: _copyMap(entry.value),
  };
  _passwords = {
    for (final user in _users.values)
      user['username'] as String: mockDevPassword,
  };
  _likedByUser = {
    1: {
      for (final post in _posts)
        if (post['isLiked'] == true) (post['id'] as num).toInt(),
    },
  };
  _favoritedByUser = {};
  _followedByUser = {
    1: {2, 3},
  };
  _postIdempotencyKeys = {};
  _commentIdempotencyKeys = {};
  _behaviorEventIds = {};
  _messageIdempotencyKeys = {};
  _messageSeedTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  _conversations = [
    {
      'id': 11,
      'targetUserId': 2,
      'targetUserName': '萌萌哒小兔',
      'targetUserAvatar': '',
      'lastMessage': '周末一起去探店吗？',
      'lastMessageTime': _messageSeedTime - 300,
      'unreadCount': 2,
    },
    {
      'id': 12,
      'targetUserId': 3,
      'targetUserName': '科技宅小明',
      'targetUserAvatar': '',
      'lastMessage': '评测文章已经更新啦',
      'lastMessageTime': _messageSeedTime - 3600,
      'unreadCount': 0,
    },
  ];
  _messages = {
    11: [
      {
        'id': 101,
        'conversationId': 11,
        'senderId': 2,
        'receiverId': 1,
        'content': '发现一家新的面馆，味道很不错。',
        'msgType': 1,
        'status': 1,
        'createdAt': _messageSeedTime - 900,
      },
      {
        'id': 102,
        'conversationId': 11,
        'senderId': 2,
        'receiverId': 1,
        'content': '周末一起去探店吗？',
        'msgType': 1,
        'status': 1,
        'createdAt': _messageSeedTime - 300,
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
        'createdAt': _messageSeedTime - 7200,
      },
      {
        'id': 202,
        'conversationId': 12,
        'senderId': 3,
        'receiverId': 1,
        'content': '评测文章已经更新啦',
        'msgType': 1,
        'status': 1,
        'createdAt': _messageSeedTime - 3600,
      },
    ],
  };
  _personalizationEnabled = {for (final id in _users.keys) id: true};
  _agentConsent = {
    for (final id in _users.keys)
      id: {
        'granted': true,
        'grantedAt': DateTime.now().millisecondsSinceEpoch,
        'revokedAt': 0,
        'consentVersion': 2,
        'currentVersion': 2,
      },
  };
  _nextWatchId = 2;
  _nextAssistantMessageId = 1;
  _nextAssistantRunId = 1;

  _nextMemoryId = 3;
  _nextChangeId = 1;
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  _assistantMemories = {
    1: [
      {
        'id': 1,
        'target': 'memory',
        'content': '喜欢美食探店',
        'version': 1,
        'createdAtMs': nowMs,
        'updatedAtMs': nowMs,
      },
      {
        'id': 2,
        'target': 'user',
        'content': '常用中文交流',
        'version': 1,
        'createdAtMs': nowMs,
        'updatedAtMs': nowMs,
      },
    ],
  };
  _assistantWatches = {
    1: [
      {
        'id': 1,
        'conditionType': 'author_new_post',
        'targetType': 'author',
        'targetId': 2,
        'targetText': '',
        'enabled': true,
        'version': 1,
        'createdAt': nowMs,
      },
    ],
  };
  _assistantThreads = {
    for (final id in _users.keys)
      id: {
        'sessionId': 1,
        'unreadCount': id == 1 ? 1 : 0,
        'lastMessageId': 0,
        'lastMessagePreview': id == 1 ? '有新的作者动态' : '',
        'lastMessageAtMs': nowMs,
        'activeRunId': 0,
        'activeRunStatus': '',
        'activeRunPhase': '',
      },
  };
  _assistantMessages = {1: <Map<String, dynamic>>[]};
  _assistantRunEvents = {};
  _assistantRuns = {};
  _assistantQueue = {};
  _assistantMemoryChanges = {};
  _usedRefreshTokens = {};
  _mockJwtNonce = 0;
  _seeded = true;
}

void _ensureState() {
  if (!_seeded) resetMockState();
}

String dispatch(
  String method,
  String path,
  String requestBody, {
  Map<String, String> headers = const {},
}) {
  return dispatchResponse(method, path, requestBody, headers: headers).body;
}

MockRouterResponse dispatchResponse(
  String method,
  String path,
  String requestBody, {
  Map<String, String> headers = const {},
}) {
  _ensureState();
  final uri = Uri.parse('http://mock$path');
  final segments = uri.pathSegments;
  final query = uri.queryParameters;
  final auth = _parseAuth(headers);
  final isMultipart = requestBody.startsWith('<multipart-');

  Map<String, dynamic>? body;
  var malformed = false;
  if (requestBody.isNotEmpty && !isMultipart) {
    try {
      final decoded = decodeApiJson(requestBody);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else {
        malformed = true;
      }
    } catch (_) {
      malformed = true;
    }
  }

  try {
    if (malformed) {
      throw const _MockBiz(400, 2, '参数错误');
    }
    if (segments.length < 2 || segments[0] != 'api') {
      throw const _MockBiz(404, 4, '资源不存在');
    }
    if (segments[1] == 'v2') {
      return _routeV2(
        method.toUpperCase(),
        segments,
        query,
        body,
        auth,
        headers,
      );
    }
    if (segments[1] == 'v1') {
      return _routeV1(
        method.toUpperCase(),
        segments,
        query,
        body,
        requestBody,
        isMultipart,
        auth,
      );
    }
    throw const _MockBiz(404, 4, '资源不存在');
  } on _MockBiz catch (error) {
    return _errorResponse(error.statusCode, error.code, error.message, auth);
  } catch (error) {
    return _errorResponse(500, 3, error.toString(), auth);
  }
}

MockRouterResponse _routeV1(
  String method,
  List<String> segments,
  Map<String, String> query,
  Map<String, dynamic>? body,
  String requestBody,
  bool isMultipart,
  _Auth auth,
) {
  final route = segments.join('/');

  switch (route) {
    case 'api/v1/health':
      _requireMethod(method, 'GET');
      return _jsonResponse({'status': 'ok'});
    case 'api/v1/health/ready':
      _requireMethod(method, 'GET');
      return _jsonResponse({
        'status': 'ready',
        'dependencies': {'mock': 'ok'},
      });
    case 'api/v1/auth/login':
      _requireMethod(method, 'POST');
      return _jsonResponse(_login(body ?? const {}));
    case 'api/v1/auth/register':
      _requireMethod(method, 'POST');
      return _jsonResponse(_register(body ?? const {}));
    case 'api/v1/auth/refresh':
      _requireMethod(method, 'POST');
      return _jsonResponse(_refreshTokens(body ?? const {}));
    case 'api/v1/auth/verify-code':
      _requireMethod(method, 'POST');
      return _sendVerifyCode(body ?? const {});
    case 'api/v1/posts':
      _requireMethod(method, 'GET');
      return _withAuthState(auth, _jsonResponse(_postList(query, auth)));
    case 'api/v1/user/profile':
      _requireMethod(method, 'PUT');
      _requireAuth(auth);
      return _updateProfile(auth.userId, body ?? const {});
    case 'api/v1/user/follow':
      _requireAuth(auth);
      if (method == 'POST') {
        return _follow(auth.userId, body ?? const {}, follow: true);
      }
      if (method == 'DELETE') {
        return _follow(auth.userId, body ?? const {}, follow: false);
      }
      throw const _MockBiz(405, 1, '未知错误');
    case 'api/v1/comment':
      _requireMethod(method, 'POST');
      _requireAuth(auth);
      return _jsonResponse(_createComment(auth.userId, body ?? const {}));
    case 'api/v1/like':
      _requireAuth(auth);
      if (method == 'POST') {
        return _like(auth.userId, body ?? const {}, like: true);
      }
      if (method == 'DELETE') {
        return _like(auth.userId, body ?? const {}, like: false);
      }
      throw const _MockBiz(405, 1, '未知错误');
    case 'api/v1/favorite':
      _requireAuth(auth);
      if (method == 'POST') {
        return _favorite(auth.userId, body ?? const {}, favorite: true);
      }
      if (method == 'DELETE') {
        return _favorite(auth.userId, body ?? const {}, favorite: false);
      }
      throw const _MockBiz(405, 1, '未知错误');
    case 'api/v1/media/image':
      _requireMethod(method, 'POST');
      _requireAuth(auth);
      if (!isMultipart) throw const _MockBiz(400, 2, '参数错误');
      return _jsonResponse(_uploadImage());
  }

  if (segments.length == 4 && segments[2] == 'post') {
    _requireMethod(method, 'GET');
    return _withAuthState(
      auth,
      _jsonResponse(_getPost(_pathId(segments[3]), auth)),
    );
  }
  if (segments.length == 4 && segments[2] == 'comments') {
    _requireMethod(method, 'GET');
    return _withAuthState(
      auth,
      _jsonResponse(_commentList(_pathId(segments[3]), query)),
    );
  }
  if (segments.length == 5 &&
      segments[2] == 'comments' &&
      segments[4] == 'replies') {
    _requireMethod(method, 'GET');
    return _withAuthState(
      auth,
      _jsonResponse(_commentReplies(_pathId(segments[3]), query)),
    );
  }
  if (segments.length == 4 && segments[2] == 'comment') {
    _requireMethod(method, 'DELETE');
    _requireAuth(auth);
    return _deleteComment(auth.userId, _pathId(segments[3]));
  }
  if (segments.length == 4 && segments[2] == 'user') {
    _requireMethod(method, 'GET');
    return _jsonResponse(_getUser(_pathId(segments[3])));
  }
  if (segments.length == 5 && segments[2] == 'users') {
    _requireMethod(method, 'GET');
    final userId = _pathId(segments[3]);
    // Gateway does not attach OptionalAuth here, so viewer identity is ignored.
    const publicAuth = _Auth('anonymous', 0);
    if (segments[4] == 'posts') {
      return _jsonResponse(_userPosts(userId, query, publicAuth));
    }
    if (segments[4] == 'favorites') {
      return _jsonResponse(_userFavorites(userId, query, publicAuth));
    }
  }

  throw const _MockBiz(404, 4, '资源不存在');
}

MockRouterResponse _routeV2(
  String method,
  List<String> segments,
  Map<String, String> query,
  Map<String, dynamic>? body,
  _Auth auth,
  Map<String, String> headers,
) {
  final route = segments.join('/');

  switch (route) {
    case 'api/v2/feed/recommend':
      _requireMethod(method, 'GET');
      return _withAuthState(auth, _recommendFeed(query, auth));
    case 'api/v2/feed/follow':
      _requireMethod(method, 'GET');
      _requireAuth(auth);
      return _followFeed(query, auth);
    case 'api/v2/behavior/events':
      _requireMethod(method, 'POST');
      return _withAuthState(auth, _behaviorEvents(body, auth));
    case 'api/v2/search':
      _requireMethod(method, 'GET');
      return _search(query, includePosts: true);
    case 'api/v2/search/users':
      _requireMethod(method, 'GET');
      return _search(query, usersOnly: true);
    case 'api/v2/search/tags':
      _requireMethod(method, 'GET');
      return _searchTags(query);
    case 'api/v2/assistant/consent':
      _requireAuth(auth);
      if (method == 'GET') {
        return _jsonResponse(_consentOf(auth.userId));
      }
      _requireMethod(method, 'POST');
      final granted = body?['granted'] == true;
      _agentConsent[auth.userId] = {
        'granted': granted,
        'grantedAt': granted ? DateTime.now().millisecondsSinceEpoch : 0,
        'revokedAt': granted ? 0 : DateTime.now().millisecondsSinceEpoch,
        'consentVersion': granted ? 2 : 0,
        'currentVersion': 2,
      };
      return _jsonResponse(const {});
    case 'api/v2/assistant/thread':
      _requireMethod(method, 'GET');
      _requireAuth(auth);
      return _jsonResponse({'thread': _threadOf(auth.userId)});
    case 'api/v2/assistant/thread/read':
      _requireMethod(method, 'POST');
      _requireAuth(auth);
      return _jsonResponse(_markAssistantRead(auth.userId));
    case 'api/v2/assistant/messages':
      _requireAuth(auth);
      if (method == 'GET') {
        return _jsonResponse(_listAssistantMessages(auth.userId, query));
      }
      _requireMethod(method, 'POST');
      return _jsonResponse(
        _postAssistantMessage(auth.userId, body ?? const {}),
      );
    case 'api/v2/assistant/history':
      _requireMethod(method, 'DELETE');
      _requireAuth(auth);
      _deleteAssistantHistory(auth.userId);
      return _jsonResponse(const {});
    case 'api/v2/assistant/memory':
      _requireAuth(auth);
      if (method == 'GET') {
        return _jsonResponse(_listMemory(auth.userId, query['target']));
      }
      _requireMethod(method, 'POST');
      return _jsonResponse(_addMemory(auth.userId, body ?? const {}));
    case 'api/v2/assistant/memory/batch':
      _requireMethod(method, 'POST');
      _requireAuth(auth);
      return _jsonResponse(_batchMemory(auth.userId, body ?? const {}));
    case 'api/v2/assistant/watch':
      _requireAuth(auth);
      if (method == 'GET') {
        return _jsonResponse({
          'tasks': _assistantWatches[auth.userId] ?? const [],
        });
      }
      _requireMethod(method, 'POST');
      return _jsonResponse({
        'task': _createWatch(auth.userId, body ?? const {}),
      });
    case 'api/v2/assistant/recommend/feedback':
      _requireMethod(method, 'POST');
      _requireAuth(auth);
      final postId = body?['postId'];
      final reason = body?['reason']?.toString().trim() ?? '';
      if (!_isPositiveId(postId) || reason.isEmpty) {
        throw const _MockBiz(400, 2, '参数错误');
      }
      return _jsonResponse(const {});
    case 'api/v2/me/personalization':
      _requireAuth(auth);
      if (method == 'GET') {
        final enabled = _personalizationEnabled[auth.userId] ?? true;
        return _jsonResponse({
          'enabled': enabled,
          'optedOutAt': enabled
              ? 0
              : DateTime.now().millisecondsSinceEpoch ~/ 1000,
        });
      }
      if (method == 'PUT') {
        _personalizationEnabled[auth.userId] = body?['enabled'] == true;
        return _jsonResponse(const {});
      }
      throw const _MockBiz(405, 1, '未知错误');
    case 'api/v2/post':
      _requireMethod(method, 'POST');
      _requireAuth(auth);
      return _jsonResponse(_createPost(auth.userId, body ?? const {}));
    case 'api/v2/messages':
      _requireMethod(method, 'POST');
      _requireAuth(auth);
      return _jsonResponse(_sendMessage(auth.userId, body ?? const {}));
    case 'api/v2/messages/conversations':
      _requireMethod(method, 'GET');
      _requireAuth(auth);
      return _jsonResponse(_conversationList(query));
    case 'api/v2/messages/unread':
      _requireMethod(method, 'GET');
      _requireAuth(auth);
      return _jsonResponse(_unreadSummary());
  }

  if (segments.length == 4 && segments[2] == 'post') {
    _requireAuth(auth);
    final postId = _pathId(segments[3]);
    if (method == 'PUT') {
      return _jsonResponse(_updatePost(auth.userId, postId, body ?? const {}));
    }
    if (method == 'DELETE') {
      _deletePost(auth.userId, postId, body ?? const {});
      return _jsonResponse(const {});
    }
    throw const _MockBiz(405, 1, '未知错误');
  }

  if (segments.length >= 5 &&
      segments[2] == 'messages' &&
      segments[3] == 'conversations') {
    _requireAuth(auth);
    final conversationId = _pathId(segments[4]);
    if (segments.length == 5 && method == 'GET') {
      return _jsonResponse(_conversationMessages(conversationId, query));
    }
    if (segments.length == 6 && segments[5] == 'read' && method == 'POST') {
      return _markRead(conversationId);
    }
  }

  if (segments.length == 6 &&
      segments[2] == 'assistant' &&
      segments[3] == 'runs') {
    _requireAuth(auth);
    final runId = _pathId(segments[4]);
    if (segments[5] == 'events' && method == 'GET') {
      return _streamAssistantRunEvents(auth.userId, runId, query, headers);
    }
    if (segments[5] == 'cancel' && method == 'POST') {
      _cancelAssistantRun(auth.userId, runId);
      return _jsonResponse(const {});
    }
    if (segments[5] == 'confirm' && method == 'POST') {
      _confirmAssistantRun(auth.userId, runId, body ?? const {});
      return _jsonResponse(const {});
    }
    throw const _MockBiz(405, 1, '未知错误');
  }

  if (segments.length == 6 &&
      segments[2] == 'assistant' &&
      segments[3] == 'memory' &&
      segments[4] == 'changes' &&
      method == 'POST') {
    _requireAuth(auth);
    return _jsonResponse({
      'entry': _undoMemory(auth.userId, _pathId(segments[5])),
    });
  }

  if (segments.length == 5 &&
      segments[2] == 'assistant' &&
      segments[3] == 'memory') {
    _requireAuth(auth);
    final id = _pathId(segments[4]);
    if (method == 'PATCH') {
      return _jsonResponse(_replaceMemory(auth.userId, id, body ?? const {}));
    }
    if (method == 'DELETE') {
      return _jsonResponse(
        _removeMemory(auth.userId, id, query, body ?? const {}),
      );
    }
    throw const _MockBiz(405, 1, '未知错误');
  }

  if (segments.length == 5 &&
      segments[2] == 'assistant' &&
      segments[3] == 'watch') {
    _requireAuth(auth);
    if (!RegExp(r'^\d+$').hasMatch(segments[4])) {
      throw const _MockBiz(404, 4, '资源不存在');
    }
    final id = _pathId(segments[4]);
    if (method == 'PATCH') {
      return _jsonResponse({
        'task': _updateWatch(auth.userId, id, body ?? const {}),
      });
    }
    if (method == 'DELETE') {
      _deleteWatch(auth.userId, id, body ?? const {});
      return _jsonResponse(const {});
    }
    throw const _MockBiz(405, 1, '未知错误');
  }

  throw const _MockBiz(404, 4, '资源不存在');
}

Map<String, dynamic> _login(Map<String, dynamic> body) {
  final loginType = (body['loginType'] as num?)?.toInt() ?? 0;
  if (loginType == 2) {
    final phone = body['phone']?.toString() ?? '';
    final code = body['verifyCode']?.toString() ?? '';
    if (!_isPhone(phone) || code.isEmpty) {
      throw const _MockBiz(400, 2, '参数错误');
    }
    return {...mockTokenPairForUser(1), 'userId': 1};
  }
  final username = body['username']?.toString() ?? '';
  final password = body['password']?.toString() ?? '';
  if (username.isEmpty || password.isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final lookup = username == 'admin' ? 'xiaobaige' : username;
  Map<String, dynamic>? user;
  for (final candidate in _users.values) {
    if (candidate['username'] == lookup) {
      user = candidate;
      break;
    }
  }
  if (user == null) throw const _MockBiz(404, 1001, '用户不存在');
  if (_passwords[lookup] != password) {
    throw const _MockBiz(401, 1003, '密码错误');
  }
  return {
    ...mockTokenPairForUser((user['id'] as num).toInt()),
    'userId': user['id'],
  };
}

Map<String, dynamic> _register(Map<String, dynamic> body) {
  final username = body['username']?.toString() ?? '';
  final password = body['password']?.toString() ?? '';
  final phone = body['phone']?.toString() ?? '';
  if (username.isEmpty && phone.isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  if (username.isNotEmpty) {
    final length = username.runes.length;
    if (length < 6 || length > 50) {
      throw const _MockBiz(400, 2, '用户名长度应在6~50之间');
    }
    _assertPasswordStrength(password);
  }
  if (phone.isNotEmpty && !_isPhone(phone)) {
    throw const _MockBiz(400, 2, '非法的手机号');
  }
  if (username.isNotEmpty && _passwords.containsKey(username)) {
    throw const _MockBiz(409, 1002, '用户已存在');
  }
  final id = _nextUserId++;
  final resolvedName = username.isEmpty ? 'user$id' : username;
  _users[id] = {
    'id': id,
    'username': resolvedName,
    'nickname': resolvedName,
    'avatarUrl': '',
    'bio': '',
    'level': 1,
    'followerCount': 0,
    'followingCount': 0,
    'postCount': 0,
    'favoritesVisible': true,
  };
  _passwords[resolvedName] = password.isEmpty ? mockDevPassword : password;
  _personalizationEnabled[id] = true;
  return {...mockTokenPairForUser(id), 'userId': id};
}

/// 凭 refreshToken 换取全新令牌对；一次性轮换，重放已用令牌按无效处理。
Map<String, dynamic> _refreshTokens(Map<String, dynamic> body) {
  final refreshToken = body['refreshToken']?.toString() ?? '';
  if (refreshToken.isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  if (_usedRefreshTokens.contains(refreshToken)) {
    throw const _MockBiz(401, 1005, '登录状态无效，请重新登录');
  }
  final payload = _decodeJwtPayload(refreshToken);
  if (payload == null) {
    throw const _MockBiz(401, 1005, '登录状态无效，请重新登录');
  }
  final exp = payload['exp'];
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if (exp is num && exp.toInt() > 0 && exp.toInt() < nowSec) {
    throw const _MockBiz(401, 1004, '登录已过期，请重新登录');
  }
  final userId = payload['userId'];
  if (userId is! num || userId.toInt() <= 0) {
    throw const _MockBiz(401, 1005, '登录状态无效，请重新登录');
  }
  _usedRefreshTokens.add(refreshToken);
  return mockTokenPairForUser(userId.toInt());
}

MockRouterResponse _sendVerifyCode(Map<String, dynamic> body) {
  final phone = body['phone']?.toString() ?? '';
  final type = (body['type'] as num?)?.toInt() ?? 0;
  if (!_isPhone(phone) || type < 1 || type > 3) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  return _jsonResponse(const {});
}

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
      [
          ...(_comments[postId] ?? const <Map<String, dynamic>>[]),
        ].where((c) => (c['parentId'] as num).toInt() == 0).toList()
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

Map<String, dynamic> _conversationList(Map<String, String> query) {
  final page = _queryInt(query, 'page', defaultValue: 1);
  final pageSize = _queryInt(query, 'pageSize', defaultValue: 20);
  if (page <= 0 || pageSize <= 0 || pageSize > 100) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final sorted = [..._conversations]
    ..sort(
      (a, b) =>
          (b['lastMessageTime'] as int).compareTo(a['lastMessageTime'] as int),
    );
  final offset = (page - 1) * pageSize;
  return {
    'conversations': sorted.skip(offset).take(pageSize).toList(),
    'total': sorted.length,
  };
}

Map<String, dynamic> _conversationMessages(
  int conversationId,
  Map<String, String> query,
) {
  _conversation(conversationId);
  final lastId = _queryInt(query, 'lastId', defaultValue: 0);
  final pageSize = _queryInt(query, 'pageSize', defaultValue: 20);
  if (lastId < 0 || pageSize <= 0 || pageSize > 100) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final all =
      (_messages[conversationId] ?? const [])
          .where((message) => lastId == 0 || (message['id'] as int) < lastId)
          .map(_copyMap)
          .toList()
        ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
  return {
    'messages': all.take(pageSize).toList(growable: false),
    'hasMore': all.length > pageSize,
  };
}

MockRouterResponse _markRead(int conversationId) {
  _conversation(conversationId)['unreadCount'] = 0;
  return _jsonResponse(const {});
}

Map<String, dynamic> _unreadSummary() {
  final messageUnread = _conversations.fold<int>(
    0,
    (total, conversation) =>
        total + ((conversation['unreadCount'] as num?)?.toInt() ?? 0),
  );
  return {'messageUnread': messageUnread, 'notificationUnread': 0};
}

Map<String, dynamic> _sendMessage(int userId, Map<String, dynamic> body) {
  final receiverId = (body['receiverId'] as num?)?.toInt();
  final content = body['content']?.toString().trim() ?? '';
  final msgType = (body['msgType'] as num?)?.toInt() ?? 0;
  final idempotencyKey = body['idempotencyKey']?.toString().trim() ?? '';
  if (receiverId == null ||
      receiverId <= 0 ||
      content.isEmpty ||
      content.length > 1000 ||
      msgType < 1 ||
      msgType > 4 ||
      idempotencyKey.isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  if (!_users.containsKey(receiverId)) {
    throw const _MockBiz(404, 1001, '用户不存在');
  }
  final existing = _messageIdempotencyKeys[idempotencyKey];
  if (existing != null) return {'messageId': existing};
  Map<String, dynamic>? conversation;
  for (final item in _conversations) {
    if (item['targetUserId'] == receiverId) {
      conversation = item;
      break;
    }
  }
  if (conversation == null) {
    final user = _users[receiverId]!;
    conversation = {
      'id': _nextConversationId++,
      'targetUserId': receiverId,
      'targetUserName': user['nickname'],
      'targetUserAvatar': user['avatarUrl'] ?? '',
      'lastMessage': '',
      'lastMessageTime': 0,
      'unreadCount': 0,
    };
    _conversations.add(conversation);
  }
  final messageId = _nextMessageId++;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final conversationId = conversation['id'] as int;
  _messages.putIfAbsent(conversationId, () => []).add({
    'id': messageId,
    'conversationId': conversationId,
    'senderId': userId,
    'receiverId': receiverId,
    'content': content,
    'msgType': msgType,
    'status': 1,
    'createdAt': now,
  });
  conversation['lastMessage'] = content;
  conversation['lastMessageTime'] = now;
  _messageIdempotencyKeys[idempotencyKey] = messageId;
  return {'messageId': messageId};
}

Map<String, dynamic> _threadOf(int userId) {
  return _copyMap(
    _assistantThreads[userId] ??
        {
          'sessionId': 1,
          'unreadCount': 0,
          'lastMessageId': 0,
          'lastMessagePreview': '',
          'lastMessageAtMs': 0,
          'activeRunId': 0,
          'activeRunStatus': '',
          'activeRunPhase': '',
        },
  );
}

Map<String, dynamic> _markAssistantRead(int userId) {
  final thread = _assistantThreads.putIfAbsent(userId, _emptyThread);
  thread['unreadCount'] = 0;
  return {'unreadCount': 0};
}

Map<String, dynamic> _listAssistantMessages(
  int userId,
  Map<String, String> query,
) {
  final sessionId = query['sessionId'];
  final afterId = int.tryParse(query['afterId'] ?? '') ?? 0;
  final beforeId = int.tryParse(query['beforeId'] ?? '') ?? 0;
  if (afterId > 0 && beforeId > 0) {
    throw const _MockBiz(400, 2, '消息游标不能同时向前和向后');
  }
  final requestedLimit = int.tryParse(query['limit'] ?? '') ?? 50;
  final limit = requestedLimit <= 0 || requestedLimit > 100
      ? 50
      : requestedLimit;
  final filtered = [
    for (final item
        in _assistantMessages[userId] ?? const <Map<String, dynamic>>[])
      if (sessionId == null ||
          sessionId.isEmpty ||
          '${item['sessionId']}' == sessionId)
        if (afterId <= 0 || ((item['id'] as num).toInt() > afterId))
          if (beforeId <= 0 || ((item['id'] as num).toInt() < beforeId))
            _copyMap(item),
  ];
  final hasMore = filtered.length > limit;
  final items = afterId > 0
      ? filtered.take(limit).toList()
      : filtered
            .skip((filtered.length - limit).clamp(0, filtered.length))
            .toList();
  return {
    'messages': items,
    'hasMore': hasMore,
    'nextBeforeId': afterId > 0 || items.isEmpty ? 0 : items.first['id'],
  };
}

Map<String, dynamic> _postAssistantMessage(
  int userId,
  Map<String, dynamic> body,
) {
  final message = body['message']?.toString().trim() ?? '';
  if (message.isEmpty || message.length > 2000) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final attachments = (body['attachments'] as List<dynamic>? ?? const []);
  if (attachments.length > 9) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final thread = _assistantThreads.putIfAbsent(userId, _emptyThread);
  final sessionId = (thread['sessionId'] as num?)?.toInt() ?? 1;
  final activeRunId = (thread['activeRunId'] as num?)?.toInt() ?? 0;
  final phase = thread['activeRunPhase']?.toString() ?? '';
  final queue = _assistantQueue.putIfAbsent(userId, () => []);
  var disposition = 'started';
  if (activeRunId > 0) {
    if (phase == 'tool_executing' || message.contains('steer-me')) {
      disposition = 'steered';
    } else if (phase == 'compact' ||
        phase == 'attachment' ||
        attachments.isNotEmpty ||
        message.contains('queue-me')) {
      if (queue.length >= 32) {
        throw const _MockBiz(429, 2, '排队已满');
      }
      disposition = 'queued';
    } else {
      disposition = 'redirected';
      _completeRun(activeRunId);
    }
  }
  final messageId = _nextAssistantMessageId++;
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final stored = {
    'id': messageId,
    'sessionId': sessionId,
    'runId': 0,
    'role': 'user',
    'kind': 'message',
    'content': message,
    'unread': false,
    'createdAtMs': nowMs,
    'changeId': 0,
  };
  _assistantMessages.putIfAbsent(userId, () => []).add(stored);
  var runId = activeRunId;
  if (disposition == 'queued') {
    runId = _nextAssistantRunId++;
    stored['runId'] = runId;
    queue.add({'runId': runId, 'messageId': messageId, 'message': message});
  } else if (disposition != 'steered') {
    runId = _nextAssistantRunId++;
    stored['runId'] = runId;
    _startRun(userId, runId, sessionId, message);
  } else {
    stored['runId'] = runId;
    thread['activeRunPhase'] = 'tool_executing';
  }
  thread['lastMessageId'] = messageId;
  thread['lastMessagePreview'] = message;
  thread['lastMessageAtMs'] = nowMs;
  if (disposition != 'queued') {
    thread['activeRunId'] = runId;
    thread['activeRunStatus'] = 'running';
    thread['activeRunPhase'] = disposition == 'steered'
        ? 'tool_executing'
        : 'model_request';
  }
  return {
    'messageId': messageId,
    'sessionId': sessionId,
    'runId': runId,
    'disposition': disposition,
  };
}

void _startRun(int userId, int runId, int sessionId, String message) {
  final sourcePost = _publishedPosts().isEmpty
      ? <String, dynamic>{'id': 1, 'title': '示例帖', 'revision': 1, 'authorId': 2}
      : _publishedPosts().first;
  final events = <Map<String, dynamic>>[
    {'seq': 1, 'type': 'run_started', 'runId': runId, 'sessionId': sessionId},
  ];
  const chunkSize = 6;
  const streamId = 'mock-stream';
  final answer = '我根据社区内容找到了与“$message”相关的信息。';
  final pending = StringBuffer();
  var pendingCount = 0;
  void flushToken() {
    if (pending.isEmpty) return;
    events.add({
      'seq': events.length + 1,
      'type': 'token',
      'text': pending.toString(),
      'streamId': streamId,
      'runId': runId,
      'sessionId': sessionId,
    });
    pending.clear();
    pendingCount = 0;
  }

  for (final grapheme in answer.characters) {
    pending.write(grapheme);
    pendingCount++;
    if (pendingCount >= chunkSize) flushToken();
  }
  flushToken();
  events.add({
    'seq': events.length + 1,
    'type': 'source_card',
    'runId': runId,
    'sessionId': sessionId,
    'sourceCard': {
      'handle': 'src-${sourcePost['id']}',
      'kind': 'post',
      'authorityId': '${sourcePost['id']}',
      'title': sourcePost['title'] ?? '',
      'revision': sourcePost['revision'] ?? 1,
    },
  });
  if (message.contains('删除') || message.contains('delete')) {
    events.addAll([
      {
        'seq': events.length + 1,
        'type': 'tool_call',
        'runId': runId,
        'sessionId': sessionId,
        'toolCall': {
          'callId': 'mock-call-search',
          'tool': 'search_posts',
          'summary': '搜索帖子',
        },
      },
      {
        'seq': events.length + 1,
        'type': 'confirm_required',
        'runId': runId,
        'sessionId': sessionId,
        'toolCall': {
          'callId': 'mock-call-delete',
          'tool': 'delete_post',
          'summary': '请求删除帖子 #${sourcePost['id']}',
        },
      },
    ]);
  } else if (message.contains('memory')) {
    events.add({
      'seq': events.length + 1,
      'type': 'memory_changed',
      'runId': runId,
      'sessionId': sessionId,
      'text': '已更新记忆',
      'changeId': 1,
    });
  }
  if (!message.contains('steer-me') && !message.contains('hang')) {
    events.add({
      'seq': events.length + 1,
      'type': 'done',
      'runId': runId,
      'sessionId': sessionId,
    });
  }
  _assistantRunEvents[runId] = events;
  _assistantRuns[runId] = {
    'userId': userId,
    'sessionId': sessionId,
    'status': message.contains('hang') ? 'running' : 'completed',
    'phase': message.contains('steer-me') ? 'tool_executing' : 'model_request',
  };
}

MockRouterResponse _streamAssistantRunEvents(
  int userId,
  int runId,
  Map<String, String> query,
  Map<String, String> headers,
) {
  final run = _assistantRuns[runId];
  if (run == null || run['userId'] != userId) {
    throw const _MockBiz(404, 4, '资源不存在');
  }
  final lastHeader = headers['last-event-id'] ?? headers['Last-Event-ID'] ?? '';
  final afterSeq = int.tryParse(query['afterSeq'] ?? lastHeader) ?? 0;
  final events = [
    for (final event
        in _assistantRunEvents[runId] ?? const <Map<String, dynamic>>[])
      if (((event['seq'] as num?)?.toInt() ?? 0) > afterSeq) event,
  ];
  final body = events.map((event) {
    final seq = event['seq'];
    return 'id: $seq\ndata: ${jsonEncode(event)}\n\n';
  }).join();
  return MockRouterResponse(
    body: body,
    statusCode: 200,
    headers: {
      'content-type': 'text/event-stream',
      'cache-control': 'no-cache',
      'x-auth-state': 'authenticated',
    },
  );
}

void _cancelAssistantRun(int userId, int runId) {
  final run = _assistantRuns[runId];
  if (run == null || run['userId'] != userId) {
    throw const _MockBiz(404, 4, '资源不存在');
  }
  run['status'] = 'cancelled';
  _completeRun(runId);
}

void _confirmAssistantRun(int userId, int runId, Map<String, dynamic> body) {
  final callId = body['callId']?.toString() ?? '';
  if (callId.isEmpty) throw const _MockBiz(400, 2, '参数错误');
  final run = _assistantRuns[runId];
  if (run == null || run['userId'] != userId) {
    throw const _MockBiz(404, 4, '资源不存在');
  }
}

void _completeRun(int runId) {
  final run = _assistantRuns[runId];
  if (run == null) return;
  run['status'] = 'completed';
  final userId = run['userId'] as int;
  final thread = _assistantThreads[userId];
  if (thread != null && thread['activeRunId'] == runId) {
    thread['activeRunId'] = 0;
    thread['activeRunStatus'] = '';
    thread['activeRunPhase'] = '';
  }
}

void _deleteAssistantHistory(int userId) {
  _assistantMessages[userId] = [];
  final thread = _assistantThreads.putIfAbsent(userId, _emptyThread);
  thread['lastMessageId'] = 0;
  thread['lastMessagePreview'] = '';
  thread['unreadCount'] = 0;
  thread['activeRunId'] = 0;
}

Map<String, dynamic> _emptyThread() => {
  'sessionId': 1,
  'unreadCount': 0,
  'lastMessageId': 0,
  'lastMessagePreview': '',
  'lastMessageAtMs': 0,
  'activeRunId': 0,
  'activeRunStatus': '',
  'activeRunPhase': '',
};

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

Map<String, dynamic> _conversation(int conversationId) {
  return _conversations.firstWhere(
    (item) => item['id'] == conversationId,
    orElse: () => throw const _MockBiz(404, 4, '资源不存在'),
  );
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

void _assertPasswordStrength(String password) {
  if (password.length < 8 || password.length > 64) {
    throw const _MockBiz(400, 2, '密码过长或过短');
  }
  var hasUpper = false;
  var hasLower = false;
  var hasDigit = false;
  for (final code in password.codeUnits) {
    final char = String.fromCharCode(code);
    if (char == char.toUpperCase() && char != char.toLowerCase()) {
      hasUpper = true;
    } else if (char == char.toLowerCase() && char != char.toUpperCase()) {
      hasLower = true;
    } else if (code >= 48 && code <= 57) {
      hasDigit = true;
    }
  }
  if (!(hasUpper && hasLower && hasDigit)) {
    throw const _MockBiz(400, 2, '密码强度过弱，至少需要包含大小写字母和数字');
  }
}

bool _isPhone(String phone) => RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);

int _queryInt(
  Map<String, String> query,
  String key, {
  required int defaultValue,
}) {
  if (!query.containsKey(key) || query[key]!.isEmpty) return defaultValue;
  final value = int.tryParse(query[key]!);
  if (value == null) throw const _MockBiz(400, 2, '参数错误');
  return value;
}

int _clampPage(int page) => page <= 0 ? 1 : page;

int _clampPageSize(int pageSize) => _clampPageSizeTo(pageSize, 20, 50);

int _clampPageSizeTo(int pageSize, int fallback, int max) {
  if (pageSize <= 0) return fallback;
  if (pageSize > max) return max;
  return pageSize;
}

int _pathId(String raw) {
  final value = int.tryParse(raw);
  if (value == null) throw const _MockBiz(400, 2, '参数错误');
  return value;
}

void _requireMethod(String actual, String expected) {
  if (actual != expected) throw const _MockBiz(405, 1, '未知错误');
}

void _requireAuth(_Auth auth) {
  if (!auth.isAuthenticated) throw const _MockBiz(401, 1006, '请先登录');
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

Map<String, dynamic> _copyMap(Map<String, dynamic> source) =>
    Map<String, dynamic>.from(source);

_Auth _parseAuth(Map<String, String> headers) {
  var authorization = '';
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == 'authorization') {
      authorization = entry.value.trim();
      break;
    }
  }
  if (authorization.isEmpty) return const _Auth('anonymous', 0);
  if (!authorization.startsWith('Bearer ')) return const _Auth('invalid', 0);
  final token = authorization.substring(7).trim();
  if (token.isEmpty) return const _Auth('invalid', 0);
  final payload = _decodeJwtPayload(token);
  if (payload == null) return const _Auth('invalid', 0);
  final exp = payload['exp'];
  if (exp is num &&
      exp.toInt() > 0 &&
      exp.toInt() < DateTime.now().millisecondsSinceEpoch ~/ 1000) {
    return const _Auth('expired', 0);
  }
  final userId = payload['userId'];
  if (userId is! num || userId.toInt() <= 0) return const _Auth('invalid', 0);
  return _Auth('authenticated', userId.toInt());
}

Map<String, dynamic>? _decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final decoded = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final json = jsonDecode(decoded);
    return json is Map<String, dynamic> ? json : null;
  } catch (_) {
    return null;
  }
}

String mockAccessTokenForUser(int userId) => _buildFakeJwt(userId);

String mockExpiredTokenForUser(int userId) => _buildFakeJwt(
  userId,
  exp: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 10,
);

/// 与真实网关对齐的令牌对：access 短时效、refresh 7 天。
Map<String, String> mockTokenPairForUser(int userId) {
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return {
    'token': _buildFakeJwt(userId, exp: nowSec + _mockAccessTtlSeconds),
    'refreshToken': _buildFakeJwt(userId, exp: nowSec + _mockRefreshTtlSeconds),
  };
}

String mockRefreshTokenForUser(int userId) =>
    mockTokenPairForUser(userId)['refreshToken']!;

String _buildFakeJwt(int userId, {int? exp}) {
  // 唯一 jti 模拟真实网关的一次性令牌：同秒内轮换也产出不同字符串。
  final nonce = ++_mockJwtNonce;
  final header = base64Url
      .encode(utf8.encode('{"alg":"none","typ":"JWT"}'))
      .replaceAll('=', '');
  final claims = exp == null
      ? '{"userId":$userId,"jti":"n$nonce"}'
      : '{"userId":$userId,"exp":$exp,"jti":"n$nonce"}';
  final payload = base64Url.encode(utf8.encode(claims)).replaceAll('=', '');
  return '$header.$payload.fake-sig';
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

MockRouterResponse _withAuthState(_Auth auth, MockRouterResponse response) {
  return MockRouterResponse(
    body: response.body,
    statusCode: response.statusCode,
    headers: {...response.headers, 'x-auth-state': auth.state},
  );
}

MockRouterResponse _errorResponse(
  int statusCode,
  int code,
  String message,
  _Auth auth,
) {
  return MockRouterResponse(
    body: jsonEncode({'code': code, 'message': message}),
    statusCode: statusCode,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      if (auth.state.isNotEmpty) 'x-auth-state': auth.state,
    },
  );
}

MockRouterResponse _jsonResponse(
  Map<String, dynamic> payload, {
  int statusCode = 200,
}) {
  return MockRouterResponse(
    body: jsonEncode(payload),
    statusCode: statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, dynamic> _consentOf(int userId) {
  return _copyMap(
    _agentConsent[userId] ??
        {
          'granted': false,
          'grantedAt': 0,
          'revokedAt': 0,
          'consentVersion': 0,
          'currentVersion': 2,
        },
  );
}

Map<String, dynamic> _listMemory(int userId, String? target) {
  final items = [
    for (final item
        in _assistantMemories[userId] ?? const <Map<String, dynamic>>[])
      if (target == null || target.isEmpty || item['target'] == target)
        _copyMap(item),
  ];
  return {'items': items, 'capacities': _memoryCapacities(userId)};
}

List<Map<String, dynamic>> _memoryCapacities(int userId) {
  final items = _assistantMemories[userId] ?? const <Map<String, dynamic>>[];
  int used(String target) => items
      .where((item) => item['target'] == target)
      .fold<int>(0, (total, item) => total + '${item['content']}'.length);
  return [
    {'target': 'memory', 'used': used('memory'), 'limit': 2200},
    {'target': 'user', 'used': used('user'), 'limit': 1375},
  ];
}

Map<String, dynamic> _addMemory(int userId, Map<String, dynamic> body) {
  final target = body['target']?.toString() ?? '';
  final content = body['content']?.toString().trim() ?? '';
  if (target != 'memory' && target != 'user') {
    throw const _MockBiz(400, 2, '参数错误');
  }
  if (content.isEmpty) throw const _MockBiz(400, 2, '参数错误');
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final entry = {
    'id': _nextMemoryId++,
    'target': target,
    'content': content,
    'version': 1,
    'createdAtMs': nowMs,
    'updatedAtMs': nowMs,
  };
  _assistantMemories.putIfAbsent(userId, () => []).add(entry);
  final changeId = _recordMemoryChange(userId, null, entry);
  return {'entry': _copyMap(entry), 'changeId': changeId};
}

Map<String, dynamic> _replaceMemory(
  int userId,
  int id,
  Map<String, dynamic> body,
) {
  final items = _assistantMemories[userId];
  if (items == null) throw const _MockBiz(404, 4, '资源不存在');
  final index = items.indexWhere((item) => (item['id'] as num).toInt() == id);
  if (index < 0) throw const _MockBiz(404, 4, '资源不存在');
  final current = items[index];
  final expected = (body['version'] as num?)?.toInt();
  if (expected != null && expected != (current['version'] as num).toInt()) {
    throw const _MockBiz(409, 2008, '版本冲突');
  }
  final before = _copyMap(current);
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  items[index] = {
    ...current,
    'content': body['content']?.toString() ?? current['content'],
    'version': (current['version'] as num).toInt() + 1,
    'updatedAtMs': nowMs,
  };
  final changeId = _recordMemoryChange(userId, before, items[index]);
  return {'entry': _copyMap(items[index]), 'changeId': changeId};
}

Map<String, dynamic> _removeMemory(
  int userId,
  int id,
  Map<String, String> query,
  Map<String, dynamic> body,
) {
  final items = _assistantMemories[userId];
  if (items == null) throw const _MockBiz(404, 4, '资源不存在');
  final index = items.indexWhere((item) => (item['id'] as num).toInt() == id);
  if (index < 0) throw const _MockBiz(404, 4, '资源不存在');
  final expected =
      int.tryParse(query['version'] ?? '') ??
      (body['version'] as num?)?.toInt();
  final current = items[index];
  if (expected != null && expected != (current['version'] as num).toInt()) {
    throw const _MockBiz(409, 2008, '版本冲突');
  }
  final before = items.removeAt(index);
  final changeId = _recordMemoryChange(userId, before, null);
  return {'changeId': changeId};
}

Map<String, dynamic> _batchMemory(int userId, Map<String, dynamic> body) {
  final ops = body['ops'];
  if (ops is! List || ops.isEmpty) throw const _MockBiz(400, 2, '参数错误');
  final entries = <Map<String, dynamic>>[];
  final changeIds = <int>[];
  for (final raw in ops) {
    if (raw is! Map) continue;
    final op = Map<String, dynamic>.from(raw);
    switch (op['op']?.toString()) {
      case 'add':
        final result = _addMemory(userId, op);
        entries.add(result['entry'] as Map<String, dynamic>);
        changeIds.add(result['changeId'] as int);
      case 'replace':
        final result = _replaceMemory(userId, (op['id'] as num).toInt(), op);
        entries.add(result['entry'] as Map<String, dynamic>);
        changeIds.add(result['changeId'] as int);
      case 'remove':
        final result = _removeMemory(userId, (op['id'] as num).toInt(), {}, op);
        changeIds.add(result['changeId'] as int);
      default:
        throw const _MockBiz(400, 2, '参数错误');
    }
  }
  return {'entries': entries, 'changeIds': changeIds};
}

int _recordMemoryChange(
  int userId,
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
) {
  final changeId = _nextChangeId++;
  _assistantMemoryChanges.putIfAbsent(userId, () => []).add({
    'id': changeId,
    'before': before == null ? null : _copyMap(before),
    'after': after == null ? null : _copyMap(after),
  });
  return changeId;
}

Map<String, dynamic> _undoMemory(int userId, int changeId) {
  final changes = _assistantMemoryChanges[userId];
  if (changes == null) throw const _MockBiz(404, 4, '资源不存在');
  final index = changes.indexWhere(
    (item) => (item['id'] as num).toInt() == changeId,
  );
  if (index < 0) throw const _MockBiz(404, 4, '资源不存在');
  final change = changes.removeAt(index);
  final before = change['before'] is Map
      ? Map<String, dynamic>.from(change['before'] as Map)
      : null;
  final after = change['after'] is Map
      ? Map<String, dynamic>.from(change['after'] as Map)
      : null;
  final items = _assistantMemories.putIfAbsent(userId, () => []);
  if (after != null) {
    final id = (after['id'] as num).toInt();
    items.removeWhere((item) => (item['id'] as num).toInt() == id);
    if (before != null) items.add(_copyMap(before));
  } else if (before != null) {
    items.add(_copyMap(before));
  }
  if (before != null) return _copyMap(before);
  if (after != null) return _copyMap(after);
  throw const _MockBiz(404, 4, '资源不存在');
}

const _watchConditions = {
  'author_new_post': 'author',
  'tag_new_post': 'tag',
  'keyword_new_post': 'keyword',
  'post_revised': 'post',
};

Map<String, dynamic> _createWatch(int userId, Map<String, dynamic> body) {
  final condition = body['conditionType']?.toString() ?? '';
  final targetType = body['targetType']?.toString() ?? '';
  final expected = _watchConditions[condition];
  if (expected == null || expected != targetType) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final targetId = body['targetId'];
  final targetText = body['targetText']?.toString() ?? '';
  if ((condition == 'author_new_post' || condition == 'post_revised') &&
      !_isPositiveId(targetId)) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  if ((condition == 'tag_new_post' || condition == 'keyword_new_post') &&
      targetText.trim().isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final tasks = _assistantWatches.putIfAbsent(userId, () => []);
  for (final existing in tasks) {
    if (existing['conditionType'] == condition &&
        existing['targetType'] == targetType &&
        '${existing['targetId']}' == '${targetId ?? 0}' &&
        existing['targetText'] == targetText) {
      throw const _MockBiz(409, 2008, '追踪任务已存在');
    }
  }
  final task = {
    'id': _nextWatchId++,
    'conditionType': condition,
    'targetType': targetType,
    'targetId': _isPositiveId(targetId) ? int.parse(jsonInt64Id(targetId)) : 0,
    'targetText': targetText,
    'enabled': true,
    'version': 1,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };
  tasks.add(task);
  return task;
}

Map<String, dynamic> _updateWatch(
  int userId,
  int id,
  Map<String, dynamic> body,
) {
  final tasks = _assistantWatches[userId];
  if (tasks == null) throw const _MockBiz(404, 4, '资源不存在');
  final index = tasks.indexWhere((item) => (item['id'] as num).toInt() == id);
  if (index < 0) throw const _MockBiz(404, 4, '资源不存在');
  final expectedVersion = (body['expectedVersion'] as num?)?.toInt() ?? 0;
  final currentVersion = (tasks[index]['version'] as num?)?.toInt() ?? 0;
  if (expectedVersion <= 0 || expectedVersion != currentVersion) {
    throw const _MockBiz(409, 2007, '内容版本冲突');
  }
  tasks[index] = {
    ...tasks[index],
    'enabled': body['enabled'] == true,
    'version': currentVersion + 1,
  };
  return tasks[index];
}

void _deleteWatch(int userId, int id, Map<String, dynamic> body) {
  final tasks = _assistantWatches[userId];
  if (tasks == null) throw const _MockBiz(404, 4, '资源不存在');
  final index = tasks.indexWhere((item) => (item['id'] as num).toInt() == id);
  if (index < 0) throw const _MockBiz(404, 4, '资源不存在');
  final expectedVersion = (body['expectedVersion'] as num?)?.toInt() ?? 0;
  final currentVersion = (tasks[index]['version'] as num?)?.toInt() ?? 0;
  if (expectedVersion <= 0 || expectedVersion != currentVersion) {
    throw const _MockBiz(409, 2007, '内容版本冲突');
  }
  tasks.removeAt(index);
}

bool _isPositiveId(Object? value) => jsonInt64IsPositive(value);
