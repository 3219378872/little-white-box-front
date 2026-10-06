import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../sdk/vars/kv.dart';
import '../../sdk/vars/vars.dart';
import '../../sdk/api/api.dart' as sdk_api;
import 'api_exceptions.dart';
import 'json_int64.dart';

/// 将 SDK 的 ok/fail/eventually 回调模式转换为 `Future<T>`
///
/// 用法示例:
///   `final resp = await apiCall<LoginResp>(`
///     (ok, fail, eventually) => login(
///       LoginReq(...),
///       ok: ok, fail: fail, eventually: eventually,
///     ),
///   );
Future<T> apiCall<T>(
  void Function(Function(T) ok, Function(String) fail, Function eventually)
  caller,
) {
  final completer = Completer<T>();
  // 三个回调都只认第一次完成，SDK 先 ok/fail 再 eventually 时不会重复完成。
  caller(
    (data) {
      if (!completer.isCompleted) completer.complete(data);
    },
    (error) {
      if (!completer.isCompleted) {
        final exception = ApiException.parse(error);
        completer.completeError(exception);
      }
    },
    () {
      // ok/fail 都未触发就收尾时视为失败，避免调用方永远等待。
      if (!completer.isCompleted) {
        completer.completeError(const ApiException('请求未返回结果'));
      }
    },
  );
  return completer.future;
}

/// 带超时的 API 调用；超时统一转成 [ApiException]，便于页面按同一路径展示错误。
Future<T> apiCallWithTimeout<T>(
  void Function(Function(T) ok, Function(String) fail, Function eventually)
  caller, {
  Duration timeout = const Duration(seconds: 15),
}) {
  return apiCall<T>(caller)
      .timeout(timeout, onTimeout: () => throw const ApiException('请求超时'));
}

/// Multipart POST 上传，用于文件上传场景。
///
/// [contentType] 为该 part 的 MIME，如 `image/jpeg`；服务端常对此做白名单校验。
/// 认证失败时尝试换发令牌并恰好重试一次，与传输层行为一致。
///
/// 文件来源二选一：小文件直接给 [bytes]，大文件给 [openRead] 与 [length] 流式发送
/// （每次重试都会重新打开流）。[isCurrent] 由调用方提供，返回 false 时放弃本次上传
/// 且不交付结果；[decodeData] 把网关信封中的 `data` 解成业务类型，缺字段时抛带中文
/// 文案的 [ApiException]，其余解码异常统一按「无法识别的数据」处理。
Future<T> apiPostMultipart<T>({
  required String path,
  required String fieldName,
  required String filename,
  List<int>? bytes,
  Stream<List<int>> Function()? openRead,
  int? length,
  Map<String, String> fields = const {},
  bool Function()? isCurrent,
  required T Function(Map<String, dynamic>) decodeData,
  String contentType = 'application/octet-stream',
  Duration timeout = const Duration(seconds: 60),
}) async {
  if (bytes == null && (openRead == null || length == null)) {
    throw const ApiException('缺少上传文件');
  }
  try {
    // 以发起时的会话 revision 为准：期间登出或换号都中止，不把文件传到别的账号下。
    final initialContext = await getTokenSessionContext();
    for (var attempt = 1; ; attempt++) {
      if (isCurrent != null && !isCurrent()) {
        throw const ApiException('上传已取消');
      }
      final context = attempt == 1
          ? initialContext
          : await getTokenSessionContext();
      if (context.revision != initialContext.revision) {
        throw const ApiException('请求会话已变化，请重试');
      }
      final session = context.snapshot;
      final tokens = session?.tokens;
      // 超时时通过 abortTrigger 真正中断底层连接，而不只是丢弃 Future。
      final abort = Completer<void>();
      final req = http.AbortableMultipartRequest(
        'POST',
        apiUri(path),
        abortTrigger: abort.future,
      );
      // 兼容存储里已带或未带 `Bearer ` 前缀的访问令牌。
      if (tokens != null) {
        final token = tokens.accessToken.trim();
        if (token.isNotEmpty) {
          req.headers['Authorization'] =
              token.toLowerCase().startsWith('bearer ')
              ? token
              : 'Bearer $token';
        }
      }
      req.fields.addAll(fields);
      req.files.add(
        bytes != null
            ? http.MultipartFile.fromBytes(
                fieldName,
                bytes,
                filename: filename,
                contentType: MediaType.parse(contentType),
              )
            : http.MultipartFile(
                fieldName,
                openRead!(),
                length!,
                filename: filename,
                contentType: MediaType.parse(contentType),
              ),
      );

      final rp = await sdk_api.apiClient
          .send(req)
          .then(http.Response.fromStream)
          .timeout(
            timeout,
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('upload deadline exceeded');
            },
          );
      final respBody = utf8.decode(rp.bodyBytes);

      // 错误响应可能不是 JSON（如网关/代理页面），解析失败时按无业务码处理。
      dynamic decoded;
      try {
        decoded = respBody.isEmpty ? null : decodeApiJson(respBody);
      } catch (_) {
        decoded = null;
      }

      if (rp.statusCode < 200 || rp.statusCode >= 300) {
        // 依次兼容网关与中间层常见的错误消息字段。
        int? code;
        String msg = 'http ${rp.statusCode}';
        if (decoded is Map<String, dynamic>) {
          code = decoded['code'] as int?;
          final errMsg =
              decoded['message'] ??
              decoded['msg'] ??
              decoded['desc'] ??
              decoded['error'];
          if (errMsg != null) msg = errMsg.toString();
        }

        // 仅首轮、且持有 refresh token 的认证失败才换发令牌重试一次。
        final canRetry =
            attempt == 1 &&
            session != null &&
            (tokens?.refreshToken.trim().isNotEmpty ?? false) &&
            (ApiException(msg, code: code).isAuthError ||
                (code == null && rp.statusCode == 401));
        if (canRetry) {
          final refreshResult = await sdk_api.refreshSessionTokensFor(session);
          if (refreshResult == sdk_api.SessionRefreshResult.refreshed) {
            continue;
          }
          if (refreshResult == sdk_api.SessionRefreshResult.unavailable) {
            throw const ApiException('会话刷新失败，请重试');
          }
          if (refreshResult == sdk_api.SessionRefreshResult.stale) {
            throw const ApiException('请求会话已变化，请重试');
          }
        }

        // 认证失败且无法刷新：仅当本地凭据仍是发起时那份才清会话，避免误伤新登录。
        // 无业务码的英文文本（裸状态码、代理错误页）由 ApiException.http 换成中文。
        final ex = ApiException.http(msg, code: code);
        if (session != null &&
            (ex.isAuthError || (code == null && rp.statusCode == 401))) {
          await sdk_api.invalidateSessionIfCredentialsMatch(session);
        }
        throw ex;
      }
      // 成功响应也要复核会话与调用方是否仍有效，过期结果按失败处理不交付。
      final latest = await getTokenSessionContext();
      if (latest.revision != initialContext.revision ||
          (isCurrent != null && !isCurrent())) {
        throw const ApiException('请求会话已变化，请重试');
      }
      final data = sdk_api.apiResponseData(decoded);
      return decodeData(data);
    }
  } on TimeoutException {
    throw const ApiException('请求超时，请重试');
  } on ApiException {
    rethrow;
  } catch (e) {
    // 网络异常与响应解码错误按类别转成中文文案，英文原文只留在 detail。
    throw ApiException.fromClientError(e);
  }
}
