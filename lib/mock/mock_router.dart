import 'dart:convert';

import 'package:characters/characters.dart';

import '../core/api/json_int64.dart';
import 'mock_data.dart';

part 'mock_ads.dart';
part 'seeds/mock_ads_seed.dart';
part 'mock_assistant_research.dart';

part 'mock_state.dart';
part 'mock_auth.dart';
part 'mock_content.dart';
part 'mock_profile.dart';
part 'mock_discovery.dart';
part 'mock_messaging.dart';
part 'mock_assistant.dart';
part 'mock_capabilities.dart';
part 'mock_helpers.dart';

/// Mock 网关的一次响应，由 [MockHttpClient] 转成 `http.StreamedResponse`。
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

// 处理函数抛出的业务错误，由 [dispatchResponse] 统一转成 `{code, message}` 错误响应。
class _MockBiz implements Exception {
  final int statusCode;
  final int code;
  final String message;

  const _MockBiz(this.statusCode, this.code, this.message);
}

// 从 Authorization 头解析出的身份；[state] 取 anonymous/invalid/expired/authenticated，
// 并像网关 OptionalAuth 一样回写到 `x-auth-state` 响应头。
class _Auth {
  final String state;
  final int userId;

  const _Auth(this.state, this.userId);

  bool get isAuthenticated => state == 'authenticated' && userId > 0;
}

/// 只取响应体的便捷入口，供只关心 JSON 内容的测试使用。
String dispatch(
  String method,
  String path,
  String requestBody, {
  Map<String, String> headers = const {},
}) {
  return dispatchResponse(method, path, requestBody, headers: headers).body;
}

/// Mock 网关总入口：首次调用时播种内存状态，解析鉴权与 JSON 请求体后按 `/api/v1`、
/// `/api/v2` 分派到各处理函数；业务错误与未预期异常都转成网关格式的错误响应。
///
/// multipart 请求体由 [MockHttpClient] 替换为 `<multipart-N-files>` 占位串，不做 JSON 解析。
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

  // 先拒绝非对象 JSON，再按版本前缀分派；其余路径一律 404。
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

// v1 路由：认证、帖子/评论读取、用户资料、点赞收藏关注与图片上传。
// 先按完整路径精确匹配，再处理带路径 ID 的路由。
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

  // 带路径 ID 的读取与删除：帖子详情、评论列表/回复、删除评论、用户资料与用户帖子/收藏。
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
    return _withAuthState(
      auth,
      _jsonResponse(_getUser(_pathId(segments[3]), auth)),
    );
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

// v2 路由：Feed、行为上报、搜索、Agent、个性化、发帖与私信，
// 精确路径之后依次尝试广告、审核子路由，最后匹配带路径 ID 的路由。
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
        'consentVersion': granted ? 3 : 0,
        'currentVersion': 3,
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

  // 广告与审核子路由不匹配时返回 null，继续向下匹配。
  final ads = _routeAds(method, segments, query, body, auth, headers);
  if (ads != null) return ads;
  final review = _routeReview(method, segments, body, auth);
  if (review != null) return review;

  // 带路径 ID 的路由：编辑/删除帖子、会话消息与已读、Agent 运行控制、记忆撤销与修改。
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
    if (segments[5] == 'answers' && method == 'POST') {
      return _jsonResponse(
        _answerResearchQuestions(auth.userId, runId, body ?? const {}),
      );
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

  throw const _MockBiz(404, 4, '资源不存在');
}

// 为可选鉴权的公开接口附上 `x-auth-state`，与网关 OptionalAuth 的行为一致。
MockRouterResponse _withAuthState(_Auth auth, MockRouterResponse response) {
  return MockRouterResponse(
    body: response.body,
    statusCode: response.statusCode,
    headers: {...response.headers, 'x-auth-state': auth.state},
  );
}

// 网关格式的错误响应；同时带上鉴权状态，便于测试区分匿名与令牌失效。
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

// 成功响应直接返回业务载荷，不套 `{code, data}` 信封。
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
