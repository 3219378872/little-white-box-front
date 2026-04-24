import 'dart:io';
import 'dart:convert';
import '../vars/kv.dart';
import '../vars/vars.dart';

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
    var client = HttpClient();
    HttpClientRequest r;
    if (method == 'POST') {
      r = await client.postUrl(Uri.parse(serverHost + path));
    } else {
      r = await client.getUrl(Uri.parse(serverHost + path));
    }

    var strData = '';
    if (data != null) {
      strData = jsonEncode(data);
    }
    if (method == 'POST') {
      r.headers.set('Content-Type', 'application/json; charset=utf-8');
      r.headers.set('Content-Length', utf8.encode(strData).length);
    }
    if (tokens != null) {
      r.headers.set('Authorization', tokens.accessToken);
    }
    if (header != null) {
      header.forEach((k, v) {
        r.headers.set(k, v);
      });
    }

    r.write(strData);
    var rp = await r.close();
    var body = await rp.transform(utf8.decoder).join();
    print('${rp.statusCode} - $path');
    print('-- request --');
    print(strData);
    print('-- response --');
    print('$body \n');
    dynamic decoded;
    try {
      decoded = body.isEmpty ? null : jsonDecode(body);
    } catch (_) {
      decoded = null;
    }
    if (rp.statusCode == 404) {
      final (code, msg) = _extractError(decoded, body, 404);
      if (fail != null) {
        fail(jsonEncode({'code': code, 'message': msg}));
      }
    } else if (rp.statusCode >= 200 && rp.statusCode < 300) {
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
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

(int?, String) _extractError(dynamic decoded, String body, int statusCode) {
  if (decoded is Map<String, dynamic>) {
    final code = decoded['code'];
    final errMsg = decoded['message'] ??
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
