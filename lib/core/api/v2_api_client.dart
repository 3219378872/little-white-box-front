import '../../sdk/api/api.dart';
import 'api_adapter.dart';

/// 面向 feature 仓储的轻量 REST 客户端：按路径直接调用 SDK 通用请求函数，
/// 返回网关信封里的 `data` 对象，错误统一为 [ApiException]。
class V2ApiClient {
  const V2ApiClient();

  /// GET 请求；[query] 中的 null 与空串参数会被省略。
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    final requestPath = _withQuery(path, query);
    return apiCall<Map<String, dynamic>>(
      (ok, fail, eventually) =>
          apiGet(requestPath, ok: ok, fail: fail, eventually: eventually),
    );
  }

  /// POST 请求；[expectedSessionRevision] 用于把请求绑定到调用方读取到的会话版本，
  /// 发送前会话已变化时直接失败，避免以其他账号身份提交。
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    int? expectedSessionRevision,
  }) async {
    return apiCall<Map<String, dynamic>>(
      (ok, fail, eventually) => apiPost(
        path,
        body,
        ok: ok,
        fail: fail,
        eventually: eventually,
        expectedSessionRevision: expectedSessionRevision,
      ),
    );
  }

  /// PATCH 请求，用于部分更新。
  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    return apiCall<Map<String, dynamic>>(
      (ok, fail, eventually) =>
          apiPatch(path, body, ok: ok, fail: fail, eventually: eventually),
    );
  }

  /// DELETE 请求；[body] 为可选请求体，查询参数的省略规则同 [get]。
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic> body = const {},
    Map<String, Object?> query = const {},
  }) async {
    return apiCall<Map<String, dynamic>>(
      (ok, fail, eventually) => apiDelete(
        _withQuery(path, query),
        body,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  // 拼接查询串并丢弃 null/空值，让可选筛选条件不必在调用处逐个判断。
  String _withQuery(String path, Map<String, Object?> query) {
    final values = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      final stringValue = value.toString();
      if (stringValue.isEmpty) continue;
      values[entry.key] = stringValue;
    }
    if (values.isEmpty) return path;
    return '$path?${Uri(queryParameters: values).query}';
  }
}
