import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'mock_router.dart' as router;

/// 非侵入式 HTTP 拦截：通过 HttpOverrides 替换 HttpClient
class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

/// Mock HttpClient — 只实现 api.dart 实际调用的方法
class MockHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return MockHttpClientRequest(url, 'GET');
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return MockHttpClientRequest(url, 'POST');
  }

  // api.dart 未使用的方法统一走 noSuchMethod
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Mock HttpClientRequest — 捕获请求体，close() 时路由分发
class MockHttpClientRequest implements HttpClientRequest {
  final Uri url;
  @override
  final String method;
  final MockHttpHeaders _headers = MockHttpHeaders();
  String _body = '';

  MockHttpClientRequest(this.url, this.method);

  @override
  HttpHeaders get headers => _headers;

  @override
  void write(Object? obj) {
    if (obj != null) _body = obj.toString();
  }

  @override
  void add(List<int> data) {
    if (data.isNotEmpty && _body.isEmpty) {
      _body = '<multipart-binary-${data.length}-bytes>';
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 200));

    // 还原请求路径（含 query string）
    final path = url.path + (url.query.isNotEmpty ? '?${url.query}' : '');
    debugPrint('[Mock] $method $path');
    if (_body.isNotEmpty) debugPrint('[Mock] body: $_body');

    final responseJson = router.dispatch(method, path, _body);
    debugPrint('[Mock] response: $responseJson\n');

    return MockHttpClientResponse(200, responseJson);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// Mock HttpClientResponse — 作为 Stream<List<int>> 发射响应体
class MockHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final int _statusCode;
  final String _body;

  MockHttpClientResponse(this._statusCode, this._body);

  @override
  int get statusCode => _statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(_body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Mock HttpHeaders — set() 为空操作
class MockHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    // 不需要存储 header
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
