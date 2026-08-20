import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api/json_int64.dart';
import '../vars/kv.dart';
import '../vars/vars.dart';

http.Client _apiClient = http.Client();

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
  var tokens = await getTokens();
  try {
    var strData = '';
    if (data != null) {
      strData = encodeApiJson(data);
    }
    final headers = <String, String>{};
    if (method != 'GET') {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }
    if (tokens != null) {
      headers['Authorization'] = _bearerAuthorization(tokens.accessToken);
    }
    if (header != null) {
      headers.addAll(header);
    }

    final uri = apiUri(path);
    final rp = switch (method) {
      'POST' => await _apiClient.post(uri, headers: headers, body: strData),
      'PUT' => await _apiClient.put(uri, headers: headers, body: strData),
      'DELETE' => await _apiClient.delete(uri, headers: headers, body: strData),
      'PATCH' => await _apiClient.patch(uri, headers: headers, body: strData),
      _ => await _apiClient.get(uri, headers: headers),
    };
    final body = utf8.decode(rp.bodyBytes);
    print('${rp.statusCode} - $path');
    print('-- request --');
    print(strData);
    print('-- response --');
    print('$body \n');
    dynamic decoded;
    try {
      decoded = body.isEmpty ? null : decodeApiJson(body);
    } catch (_) {
      decoded = null;
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
