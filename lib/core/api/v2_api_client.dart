import '../../sdk/api/api.dart';
import 'api_adapter.dart';

class V2ApiClient {
  const V2ApiClient();

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    final requestPath = _withQuery(path, query);
    return apiCall<Map<String, dynamic>>(
      (ok, fail, eventually) => apiGet(
        requestPath,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    return apiCall<Map<String, dynamic>>(
      (ok, fail, eventually) => apiPost(
        path,
        body,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

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
