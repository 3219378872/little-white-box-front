import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api/error_codes.dart';
import '../../core/api/json_int64.dart';
import '../../core/auth/session_tokens.dart';
import '../vars/kv.dart';
import '../vars/vars.dart';

http.Client _apiClient = http.Client();

const String _refreshPath = '/api/v1/auth/refresh';

/// 传输层仅携带发生失败时的会话快照通知宿主。宿主必须按 revision
/// 条件更新内存态，不能让迟到的旧请求清除后来登录的账号。
Future<void> Function(SessionTokenSnapshot expired)? onSessionInvalid;

enum SessionRefreshResult { refreshed, unavailable, rejected, stale }

final Map<_RefreshKey, Future<SessionRefreshResult>> _pendingRefreshes = {};

/// Overrides the shared client, primarily for local mock mode and tests.
void setApiClient(http.Client client) {
  _apiClient.close();
  _apiClient = client;
}

http.Client get apiClient => _apiClient;

/// Supports the gateway envelope used by both the real API and Mock router.
Map<String, dynamic> apiResponseData(dynamic decoded) {
  if (decoded is! Map<String, dynamic>) return <String, dynamic>{};
  final nested = decoded['data'];
  return nested is Map<String, dynamic> ? nested : decoded;
}

/// Compatibility wrapper for callers that only need success/failure.
Future<bool> refreshSessionTokens([SessionTokenSnapshot? expected]) async {
  final snapshot = expected ?? await getTokenSnapshot();
  if (snapshot == null) return false;
  return await refreshSessionTokensFor(snapshot) ==
      SessionRefreshResult.refreshed;
}

/// Refresh single-flight is scoped to one session revision and refresh token.
/// A different login never joins or waits for an older account's refresh.
Future<SessionRefreshResult> refreshSessionTokensFor(
  SessionTokenSnapshot expected,
) async {
  final refreshToken = expected.tokens.refreshToken.trim();
  if (refreshToken.isEmpty) return SessionRefreshResult.unavailable;
  final current = await getTokenSnapshot();
  if (current == null || !current.hasSameRefreshCredential(expected)) {
    return SessionRefreshResult.stale;
  }
  final key = _RefreshKey(expected.revision, refreshToken);
  return _pendingRefreshes.putIfAbsent(
    key,
    () => _doRefreshTokens(expected).whenComplete(() {
      _pendingRefreshes.remove(key);
    }),
  );
}

Future<SessionRefreshResult> _doRefreshTokens(
  SessionTokenSnapshot expected,
) async {
  final refreshToken = expected.tokens.refreshToken.trim();
  try {
    final rp = await _apiClient.post(
      apiUri(_refreshPath),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: encodeApiJson({'refreshToken': refreshToken}),
    );
    final body = utf8.decode(rp.bodyBytes);
    dynamic decoded;
    try {
      decoded = body.isEmpty ? null : decodeApiJson(body);
    } catch (_) {
      decoded = null;
    }
    if (rp.statusCode < 200 || rp.statusCode >= 300) {
      if (_isAuthFailure(rp.statusCode, decoded)) {
        final removed = await removeTokensIfRefreshCredentialMatches(expected);
        if (removed) await onSessionInvalid?.call(expected);
        return removed
            ? SessionRefreshResult.rejected
            : SessionRefreshResult.stale;
      }
      return SessionRefreshResult.unavailable;
    }
    final data = apiResponseData(decoded);
    final accessToken = data['token']?.toString() ?? '';
    final nextRefreshToken = data['refreshToken']?.toString() ?? '';
    if (accessToken.isEmpty || nextRefreshToken.isEmpty) {
      return SessionRefreshResult.unavailable;
    }
    final replaced = await replaceTokensIfRefreshCredentialMatches(
      expected,
      buildStoredTokens(
        accessToken: accessToken,
        refreshToken: nextRefreshToken,
      ),
    );
    return replaced == null
        ? SessionRefreshResult.stale
        : SessionRefreshResult.refreshed;
  } catch (_) {
    // 网络/解码失败不代表会话被拒，保留令牌让下一次请求再试。
    return SessionRefreshResult.unavailable;
  }
}

Future<bool> invalidateSessionIfCredentialsMatch(
  SessionTokenSnapshot expected,
) async {
  final removed = await removeTokensIfCredentialsMatch(expected);
  if (removed) await onSessionInvalid?.call(expected);
  return removed;
}

bool _isAuthFailure(int statusCode, dynamic decoded) {
  if (decoded is Map<String, dynamic>) {
    final code = decoded['code'];
    final parsed = code is int ? code : int.tryParse('$code');
    // 带业务码的错误（如密码错误 1003）不触发刷新，只认认证类码。
    return parsed == null ? statusCode == 401 : ErrorCodes.isAuthError(parsed);
  }
  return statusCode == 401;
}

/// send request with post method
///
/// data: any request class that will be converted to json automatically
/// ok: is called when request succeeds
/// fail: is called when request fails
/// eventually: is always called after the nearby function returns
Future apiPost(
  String path,
  dynamic data, {
  Map<String, String>? header,
  Function(Map<String, dynamic>)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await _apiRequest(
    'POST',
    path,
    data,
    header: header,
    ok: ok,
    fail: fail,
    eventually: eventually,
  );
}

/// send request with get method
///
/// ok: is called when request succeeds
/// fail: is called when request fails
/// eventually: is always called after the nearby function returns
Future apiGet(
  String path, {
  Map<String, String>? header,
  Function(Map<String, dynamic>)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await _apiRequest(
    'GET',
    path,
    null,
    header: header,
    ok: ok,
    fail: fail,
    eventually: eventually,
  );
}

/// send request with put method
Future apiPut(
  String path,
  dynamic data, {
  Map<String, String>? header,
  Function(Map<String, dynamic>)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await _apiRequest(
    'PUT',
    path,
    data,
    header: header,
    ok: ok,
    fail: fail,
    eventually: eventually,
  );
}

/// send request with delete method
Future apiDelete(
  String path,
  dynamic data, {
  Map<String, String>? header,
  Function(Map<String, dynamic>)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await _apiRequest(
    'DELETE',
    path,
    data,
    header: header,
    ok: ok,
    fail: fail,
    eventually: eventually,
  );
}

/// send request with patch method
Future apiPatch(
  String path,
  dynamic data, {
  Map<String, String>? header,
  Function(Map<String, dynamic>)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await _apiRequest(
    'PATCH',
    path,
    data,
    header: header,
    ok: ok,
    fail: fail,
    eventually: eventually,
  );
}

Future _apiRequest(
  String method,
  String path,
  dynamic data, {
  Map<String, String>? header,
  Function(Map<String, dynamic>)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  try {
    for (var attempt = 1; ; attempt++) {
      final session = await getTokenSnapshot();
      final tokens = session?.tokens;
      var strData = '';
      if (data != null) {
        strData = encodeApiJson(data);
      }
      final headers = <String, String>{};
      if (method != 'GET') {
        headers['Content-Type'] = 'application/json; charset=utf-8';
      }
      if (header != null) {
        headers.addAll(header);
      }
      // 当前令牌必须最后写入，避免调用方缓存的 Authorization 盖掉换发结果。
      if (tokens != null) {
        headers['Authorization'] = _bearerAuthorization(tokens.accessToken);
      }

      final uri = apiUri(path);
      final rp = switch (method) {
        'POST' => await _apiClient.post(uri, headers: headers, body: strData),
        'PUT' => await _apiClient.put(uri, headers: headers, body: strData),
        'DELETE' => await _apiClient.delete(
          uri,
          headers: headers,
          body: strData,
        ),
        'PATCH' => await _apiClient.patch(uri, headers: headers, body: strData),
        _ => await _apiClient.get(uri, headers: headers),
      };
      final body = utf8.decode(rp.bodyBytes);
      dynamic decoded;
      try {
        decoded = body.isEmpty ? null : decodeApiJson(body);
      } catch (_) {
        decoded = null;
      }

      // 认证失败且还有 refreshToken 时，换发新令牌并恰好重试一次。
      final canRetry =
          attempt == 1 &&
          path != _refreshPath &&
          (tokens?.refreshToken.trim().isNotEmpty ?? false) &&
          _isAuthFailure(rp.statusCode, decoded);
      if (canRetry) {
        final refreshResult = await refreshSessionTokensFor(session!);
        if (refreshResult == SessionRefreshResult.refreshed) {
          continue;
        }
        if (refreshResult == SessionRefreshResult.unavailable) {
          if (fail != null) {
            fail(jsonEncode({'message': '会话刷新失败，请重试'}));
          }
          break;
        }
        if (refreshResult == SessionRefreshResult.stale) {
          if (fail != null) {
            fail(jsonEncode({'message': '请求会话已变化，请重试'}));
          }
          break;
        }
      }

      if (session != null && _isAuthFailure(rp.statusCode, decoded)) {
        await invalidateSessionIfCredentialsMatch(session);
      }

      if (rp.statusCode == 404) {
        final (code, msg) = _extractError(decoded, body, 404);
        if (fail != null) {
          fail(jsonEncode({'code': code, 'message': msg}));
        }
      } else if (rp.statusCode >= 200 && rp.statusCode < 300) {
        final data = apiResponseData(decoded);
        if (ok != null) ok(data);
      } else {
        final (code, msg) = _extractError(decoded, body, rp.statusCode);
        if (fail != null) {
          fail(jsonEncode({'code': code, 'message': msg}));
        }
      }
      break;
    }
  } catch (e) {
    if (fail != null) fail(e.toString());
  }
  if (eventually != null) eventually();
}

class _RefreshKey {
  final int revision;
  final String refreshToken;

  const _RefreshKey(this.revision, this.refreshToken);

  @override
  bool operator ==(Object other) {
    return other is _RefreshKey &&
        other.revision == revision &&
        other.refreshToken == refreshToken;
  }

  @override
  int get hashCode => Object.hash(revision, refreshToken);
}

String _bearerAuthorization(String token) {
  final trimmed = token.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed.toLowerCase().startsWith('bearer ')
      ? trimmed
      : 'Bearer $trimmed';
}

(int?, String) _extractError(dynamic decoded, String body, int statusCode) {
  if (decoded is Map<String, dynamic>) {
    final code = decoded['code'];
    final errMsg =
        decoded['message'] ??
        decoded['msg'] ??
        decoded['desc'] ??
        decoded['error'];
    if (errMsg != null && errMsg.toString().trim().isNotEmpty) {
      return (code is int ? code : null, errMsg.toString());
    }
  }
  final trimmed = body.trim();
  if (trimmed.isNotEmpty) {
    return (null, trimmed.length > 200 ? trimmed.substring(0, 200) : trimmed);
  }
  return (null, 'http $statusCode');
}
