import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'mock_router.dart' as router;

/// Cross-platform HTTP client used by the standalone mock entry point.
class MockHttpClient extends http.BaseClient {
  /// 控制台日志截断长度；mock 是新人默认入口，完整 body 会把密码等敏感
  /// 字段打进终端，这里只保留前缀并打码已知敏感键。
  static const _maxLoggedBodyLength = 300;
  static final _sensitiveFields = RegExp(
    r'("(?:password|passwordConfirm|oldPassword|newPassword|token|'
    r'refreshToken|accessToken|secret|verifyCode)"\s*:\s*)"[^"]*"',
    caseSensitive: false,
  );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // 模拟网络延迟，让加载态在 mock 下也能看到。
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final uri = request.url;
    final path = uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
    // multipart 不展开文件内容，只传占位串给路由识别。
    final body = switch (request) {
      http.Request request => request.body,
      http.MultipartRequest request =>
        '<multipart-${request.files.length}-files>',
      _ => '',
    };

    debugPrint('[Mock] ${request.method} $path');
    if (body.isNotEmpty) debugPrint('[Mock] body: ${_sanitize(body)}');

    final response = router.dispatchResponse(
      request.method,
      path,
      body,
      headers: request.headers,
    );
    debugPrint('[Mock] response: ${_sanitize(response.body)}\n');

    // SSE 响应按帧逐个下发，其余一次性返回。
    final contentType = response.headers['content-type'] ?? '';
    final bodyBytes = utf8.encode(response.body);
    final stream = contentType.contains('text/event-stream')
        ? _sseFrameStream(response.body)
        : Stream<List<int>>.value(bodyBytes);
    return http.StreamedResponse(
      stream,
      response.statusCode,
      headers: response.headers,
    );
  }

  // 把整段 SSE 文本拆成帧，帧间间隔 100ms，模拟服务端流式推送。
  static Stream<List<int>> _sseFrameStream(String body) async* {
    final frames = body.split('\n\n');
    var emitted = false;
    for (final frame in frames) {
      if (frame.isEmpty) continue;
      if (emitted) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      emitted = true;
      yield utf8.encode('$frame\n\n');
    }
  }

  // 打码敏感字段并截断过长内容，只用于控制台日志。
  String _sanitize(String raw) {
    var text = raw.replaceAllMapped(
      _sensitiveFields,
      (m) => '${m.group(1)}"***"',
    );
    if (text.length > _maxLoggedBodyLength) {
      text = '${text.substring(0, _maxLoggedBodyLength)}…<${raw.length} bytes>';
    }
    return text;
  }
}
