import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'mock_router.dart' as router;

/// Cross-platform HTTP client used by the standalone mock entry point.
class MockHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final uri = request.url;
    final path = uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
    final body = switch (request) {
      http.Request request => request.body,
      http.MultipartRequest request =>
        '<multipart-${request.files.length}-files>',
      _ => '',
    };

    debugPrint('[Mock] ${request.method} $path');
    if (body.isNotEmpty) debugPrint('[Mock] body: $body');

    final response = router.dispatchResponse(
      request.method,
      path,
      body,
      headers: request.headers,
    );
    debugPrint('[Mock] response: ${response.body}\n');

    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}
