import 'dart:convert';
import 'package:http/http.dart' as http;
import '../vars/kv.dart';
import '../vars/vars.dart';

http.Client _apiClient = http.Client();

/// Overrides the shared client, primarily for local mock mode and tests.
void setApiClient(http.Client client) {
  _apiClient.close();
  _apiClient = client;
}

http.Client get apiClient => _apiClient;

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
      strData = jsonEncode(data);
    }
    final headers = <String, String>{};
    if (method == 'POST') {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }
    if (tokens != null) {
      headers['Authorization'] = tokens.accessToken;
    }
    if (header != null) {
      headers.addAll(header);
    }

    final uri = Uri.parse(serverHost + path);
    final rp = method == 'POST'
        ? await _apiClient.post(uri, headers: headers, body: strData)
        : await _apiClient.get(uri, headers: headers);
    final body = utf8.decode(rp.bodyBytes);
    print('${rp.statusCode} - $path');
    print('-- request --');
    print(strData);
    print('-- response --');
    print('$body \n');
    if (rp.statusCode == 404) {
      if (fail != null) fail('404 not found');
    } else {
      dynamic decoded;
      try {
        decoded = body.isEmpty ? null : jsonDecode(body);
      } catch (_) {
        decoded = null;
      }
      if (rp.statusCode >= 200 && rp.statusCode < 300) {
        final data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        if (ok != null) ok(data);
      } else {
        final msg = _extractErrorMessage(decoded, body, rp.statusCode);
        if (fail != null) fail(msg);
      }
    }
  } catch (e) {
    if (fail != null) fail(e.toString());
  }
  if (eventually != null) eventually();
}

/// 从后端错误响应中尽量挖出人类可读的错误文案。
/// 优先级：JSON 常见 error 字段 → body 原文 → http 状态码兜底。
String _extractErrorMessage(dynamic decoded, String body, int statusCode) {
  if (decoded is Map<String, dynamic>) {
    final errMsg = decoded['desc'] ??
        decoded['msg'] ??
        decoded['message'] ??
        decoded['error'];
    if (errMsg != null && errMsg.toString().trim().isNotEmpty) {
      return errMsg.toString();
    }
  }
  final trimmed = body.trim();
  if (trimmed.isNotEmpty) {
    return trimmed.length > 200 ? trimmed.substring(0, 200) : trimmed;
  }
  return 'http $statusCode';
}
