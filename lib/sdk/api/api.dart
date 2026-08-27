import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api/error_codes.dart';
import '../../core/api/json_int64.dart';
import '../../core/auth/session_tokens.dart';
import '../vars/kv.dart';
import '../vars/vars.dart';

http.Client _apiClient = http.Client();

const String _refreshPath = '/api/v1/auth/refresh';

/// 会话彻底失效（刷新令牌缺失或被网关拒绝）后由传输层触发，
/// 宿主用它同步内存中的认证状态（如 AuthNotifier），驱动路由跳登录页。
void Function()? onSessionInvalid;

Future<bool>? _pendingRefresh;

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

/// 用存储的 refreshToken 换取全新令牌对（single-flight）。
///
/// 并发调用共享同一次请求；服务端拒绝（非 2xx）视为会话不可恢复，
/// 清空本地令牌并触发 [onSessionInvalid]。网络异常不清会话，仅返回 false。
Future<bool> refreshSessionTokens() {
  return _pendingRefresh ??= _doRefreshTokens().whenComplete(() {
    _pendingRefresh = null;
  });
}

Future<bool> _doRefreshTokens() async {
  final tokens = await getTokens();
  final refreshToken = tokens?.refreshToken.trim() ?? '';
  if (refreshToken.isEmpty) return false;
  try {
    final rp = await _apiClient.post(
      apiUri(_refreshPath),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: encodeApiJson({'refreshToken': refreshToken}),
    );
    if (rp.statusCode < 200 || rp.statusCode >= 300) {
      await _expireSession();
      return false;
    }
    final body = utf8.decode(rp.bodyBytes);
    dynamic decoded;
    try {
      decoded = body.isEmpty ? null : decodeApiJson(body);
    } catch (_) {
      decoded = null;
    }
    final data = apiResponseData(decoded);
    final accessToken = data['token']?.toString() ?? '';
    final nextRefreshToken = data['refreshToken']?.toString() ?? '';
    if (accessToken.isEmpty || nextRefreshToken.isEmpty) {
      await _expireSession();
      return false;
    }
    await setTokens(buildStoredTokens(
      accessToken: accessToken,
      refreshToken: nextRefreshToken,
    ));
    return true;
  } catch (_) {
    // 网络/解码失败不代表会话被拒，保留令牌让下一次请求再试。
    return false;
  }
}

Future<void> _expireSession() async {
  await removeTokens();
  onSessionInvalid?.call();
}

bool _isAuthFailure(int statusCode, dynamic decoded) {
  if (decoded is Map<String, dynamic>) {
    final code = decoded['code'];
    final parsed = code is int ? code : int.tryParse('$code');
    // 带业务码的错误（如密码错误 1003）不触发刷新，只认认证类码。
    return parsed == null
        ? statusCode == 401
        : ErrorCodes.isAuthError(parsed);
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
    for (var attempt = 1;; attempt++) {
      final tokens = await getTokens();
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
        'DELETE' =>
          await _apiClient.delete(uri, headers: headers, body: strData),
        'PATCH' =>
          await _apiClient.patch(uri, headers: headers, body: strData),
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
      final canRetry = attempt == 1 &&
          path != _refreshPath &&
          (tokens?.refreshToken.trim().isNotEmpty ?? false) &&
          _isAuthFailure(rp.statusCode, decoded);
      if (canRetry) {
        if (await refreshSessionTokens()) {
          continue;
        }
        // 换发网络失败会保留 refreshToken；不要把原始 401 交给 onAuthError。
        final leftover = await getTokens();
        if (leftover?.refreshToken.trim().isNotEmpty ?? false) {
          if (fail != null) {
            fail(jsonEncode({'message': '会话刷新失败，请重试'}));
          }
          break;
        }
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
