import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xiaobaihe_app/core/api/json_int64.dart';

/// 记录请求并按脚本应答的假网关传输层，供走 SDK apiCall 的仓储测试复用。
class ScriptedGatewayClient extends http.BaseClient {
  ScriptedGatewayClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  /// 按发送顺序记录的所有请求。
  final List<http.BaseRequest> requests = [];

  /// 对所有请求返回同一成功信封。
  factory ScriptedGatewayClient.always(
    Map<String, dynamic> data, {
    int statusCode = 200,
  }) =>
      ScriptedGatewayClient(
        (_) async => jsonResponse(okEnvelope(data), statusCode),
      );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close() {}
}

/// 网关统一成功信封；apiResponseData 会剥出 data 字段。
Map<String, dynamic> okEnvelope(Map<String, dynamic> data) =>
    {'code': 0, 'message': 'ok', 'data': data};

http.Response jsonResponse(Map<String, dynamic> body, [int statusCode = 200]) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// 取回 JSON 请求体；multipart 请求返回空 map。
///
/// 用应用的 int64 安全解码器，让 16 位以上雪花 id 以字符串形式参与断言，
/// 与模型层看到的形态一致（线上传输时它们是裸 JSON number）。
Map<String, dynamic> jsonBodyOf(http.BaseRequest request) {
  if (request is! http.Request) return <String, dynamic>{};
  if (request.body.isEmpty) return <String, dynamic>{};
  return (decodeApiJson(request.body) ?? <String, dynamic>{})
      as Map<String, dynamic>;
}
