import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../../sdk/vars/kv.dart';
import '../../sdk/vars/vars.dart';
import 'api_exceptions.dart';

typedef AuthErrorCallback = Future<void> Function();
AuthErrorCallback? onAuthError;

/// 将 SDK 的 ok/fail/eventually 回调模式转换为 Future<T>
///
/// 用法示例:
///   final resp = await apiCall<LoginResp>(
///     (ok, fail, eventually) => login(
///       LoginReq(...),
///       ok: ok, fail: fail, eventually: eventually,
///     ),
///   );
Future<T> apiCall<T>(
  void Function(
    Function(T) ok,
    Function(String) fail,
    Function eventually,
  ) caller,
) {
  final completer = Completer<T>();
  caller(
    (data) {
      if (!completer.isCompleted) completer.complete(data);
    },
    (error) {
      if (!completer.isCompleted) {
        final exception = ApiException.parse(error);
        if (exception.isAuthError) {
          onAuthError?.call();
        }
        completer.completeError(exception);
      }
    },
    () {
      if (!completer.isCompleted) {
        completer.completeError(const ApiException('请求未返回结果'));
      }
    },
  );
  return completer.future;
}

/// 带超时的 API 调用
Future<T> apiCallWithTimeout<T>(
  void Function(
    Function(T) ok,
    Function(String) fail,
    Function eventually,
  ) caller, {
  Duration timeout = const Duration(seconds: 15),
}) {
  return apiCall<T>(caller).timeout(
    timeout,
    onTimeout: () => throw const ApiException('请求超时'),
  );
}

/// Multipart POST 上传，用于文件上传场景。
///
/// [contentType] 为该 part 的 MIME，如 `image/jpeg`；服务端常对此做白名单校验。
Future<T> apiPostMultipart<T>({
  required String path,
  required String fieldName,
  required String filename,
  required List<int> bytes,
  required T Function(Map<String, dynamic>) decodeData,
  String contentType = 'application/octet-stream',
  Duration timeout = const Duration(seconds: 60),
}) async {
  final boundary = '----dart-xiaobaihe-${_randomBoundary()}';
  final body = _buildMultipartBody(
    boundary: boundary,
    fieldName: fieldName,
    filename: filename,
    bytes: bytes,
    contentType: contentType,
  );

  final tokens = await getTokens();
  final client = HttpClient();
  client.connectionTimeout = timeout;

  try {
    final req = await client.postUrl(Uri.parse(serverHost + path));
    req.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');
    req.headers.set('Content-Length', body.length);
    if (tokens != null) {
      req.headers.set('Authorization', tokens.accessToken);
    }
    req.add(body);

    final rp = await req.close().timeout(timeout);
    final respBody = await rp.transform(utf8.decoder).join();

    dynamic decoded;
    try {
      decoded = respBody.isEmpty ? null : jsonDecode(respBody);
    } catch (_) {
      decoded = null;
    }

    if (rp.statusCode == 404) {
      int? code;
      if (decoded is Map<String, dynamic>) {
        code = decoded['code'] as int?;
      }
      final ex = ApiException('404 not found', code: code);
      if (ex.isAuthError) onAuthError?.call();
      throw ex;
    }

    if (rp.statusCode < 200 || rp.statusCode >= 300) {
      int? code;
      String msg = 'http ${rp.statusCode}';
      if (decoded is Map<String, dynamic>) {
        code = decoded['code'] as int?;
        final errMsg = decoded['message'] ??
            decoded['msg'] ??
            decoded['desc'] ??
            decoded['error'];
        if (errMsg != null) msg = errMsg.toString();
      }
      final ex = ApiException(msg, code: code);
      if (ex.isAuthError) onAuthError?.call();
      throw ex;
    }
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    return decodeData(data);
  } on ApiException {
    rethrow;
  } catch (e) {
    throw ApiException(e.toString());
  } finally {
    client.close(force: true);
  }
}

String _randomBoundary() {
  final rnd = Random();
  return List.generate(16, (_) => rnd.nextInt(36).toRadixString(36)).join();
}

List<int> _buildMultipartBody({
  required String boundary,
  required String fieldName,
  required String filename,
  required List<int> bytes,
  required String contentType,
}) {
  final crlf = '\r\n';
  final head = '--$boundary$crlf'
      'Content-Disposition: form-data; name="$fieldName"; filename="$filename"$crlf'
      'Content-Type: $contentType$crlf'
      '$crlf';
  final tail = '$crlf--$boundary--$crlf';
  return [
    ...utf8.encode(head),
    ...bytes,
    ...utf8.encode(tail),
  ];
}
