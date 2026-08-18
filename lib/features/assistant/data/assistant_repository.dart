import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_adapter.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../sdk/api/api.dart' as sdk_api;
import '../../../sdk/vars/kv.dart';
import '../../../sdk/vars/vars.dart';
import 'assistant_models.dart';

class AssistantStreamException implements Exception {
  final String message;

  const AssistantStreamException(this.message);

  @override
  String toString() => message;
}

abstract interface class AssistantDataSource {
  Stream<AssistantChatEvent> chat({
    required String message,
    required String requestId,
    String conversationId = '',
  });
}

class AssistantRepository implements AssistantDataSource {
  final http.Client? _client;
  final String _baseUrl;
  final Future<String?> Function() _loadAccessToken;

  AssistantRepository({
    http.Client? client,
    String baseUrl = serverHost,
    Future<String?> Function()? loadAccessToken,
  }) : _client = client,
       _baseUrl = baseUrl,
       _loadAccessToken = loadAccessToken ?? _defaultAccessToken;

  http.Client get _httpClient => _client ?? sdk_api.apiClient;

  @override
  Stream<AssistantChatEvent> chat({
    required String message,
    required String requestId,
    String conversationId = '',
  }) async* {
    final normalized = message.trim();
    final normalizedRequestId = requestId.trim();
    if (normalized.isEmpty || normalized.length > 2000) {
      throw const ApiException('消息长度应为 1 到 2000 个字符');
    }
    if (normalizedRequestId.isEmpty) {
      throw const ApiException('Assistant 请求标识不能为空');
    }

    final request = http.Request(
      'POST',
      apiUri('/api/v2/assistant/chat', host: _baseUrl),
    );
    request.headers.addAll({
      'Accept': 'text/event-stream',
      'Content-Type': 'application/json; charset=utf-8',
    });
    final token = (await _loadAccessToken())?.trim() ?? '';
    if (token.isNotEmpty) {
      request.headers['Authorization'] =
          token.toLowerCase().startsWith('bearer ') ? token : 'Bearer $token';
    }
    request.body = jsonEncode({
      if (conversationId.trim().isNotEmpty)
        'conversationId': conversationId.trim(),
      'message': normalized,
      'requestId': normalizedRequestId,
    });

    late http.StreamedResponse response;
    try {
      response = await _httpClient.send(request);
    } catch (error) {
      throw AssistantStreamException('无法连接 Assistant: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      final exception = _httpError(response.statusCode, body);
      if (exception.isAuthError) await onAuthError?.call();
      throw exception;
    }

    var terminal = false;
    try {
      await for (final data in _sseData(response.stream)) {
        if (data.trim().isEmpty) continue;
        final decoded = jsonDecode(data);
        if (decoded is! Map) {
          throw const FormatException('assistant event is not an object');
        }
        final event = AssistantChatEvent.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        yield event;
        if (event.isTerminal) {
          terminal = true;
          break;
        }
      }
    } on FormatException {
      throw const AssistantStreamException('Assistant 返回了无效事件');
    } on JsonUnsupportedObjectError {
      throw const AssistantStreamException('Assistant 返回了无效事件');
    } on AssistantStreamException {
      rethrow;
    } catch (error) {
      throw AssistantStreamException('Assistant 连接中断: $error');
    }

    if (!terminal) {
      throw const AssistantStreamException('Assistant 连接意外中断');
    }
  }

  static Stream<String> _sseData(Stream<List<int>> bytes) async* {
    final dataLines = <String>[];
    await for (final line
        in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          yield dataLines.join('\n');
          dataLines.clear();
        }
        continue;
      }
      if (line.startsWith(':')) continue;
      if (!line.startsWith('data:')) continue;
      var value = line.substring(5);
      if (value.startsWith(' ')) value = value.substring(1);
      dataLines.add(value);
    }
    if (dataLines.isNotEmpty) yield dataLines.join('\n');
  }

  static ApiException _httpError(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final codeValue = decoded['code'];
        final message =
            decoded['message'] ??
            decoded['msg'] ??
            decoded['error'] ??
            'Assistant 请求失败';
        return ApiException(
          message.toString(),
          code: codeValue is int ? codeValue : null,
        );
      }
    } catch (_) {
      // Fall back to a bounded plain-text error below.
    }
    final normalized = body.trim();
    return ApiException(
      normalized.isEmpty
          ? 'Assistant 请求失败 (HTTP $statusCode)'
          : normalized.substring(0, normalized.length.clamp(0, 200)),
    );
  }

  static Future<String?> _defaultAccessToken() async {
    return (await getTokens())?.accessToken;
  }
}
