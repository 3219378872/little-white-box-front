import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../sdk/api/api.dart' as sdk_api;
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/vars/kv.dart';
import '../../../sdk/vars/vars.dart';
import 'assistant_models.dart';

/// Assistant 事件流的连接/协议错误；[retryable] 告诉连接层能否原地续订。
class AssistantStreamException extends ApiException {
  final bool retryable;

  const AssistantStreamException(
    super.message, {
    this.retryable = true,
    super.code,
  });

  @override
  String toString() => message;
}

/// Assistant run 的 SSE 客户端：负责鉴权握手、一次会话刷新重试与事件帧解码，
/// 供 [AssistantRepository.runEvents] 委托；续传游标与去重留给上层连接。
class AssistantEventStreamClient {
  final http.Client? _client;
  final String _baseUrl;
  final Future<String?> Function() _loadAccessToken;
  // 未注入 token 加载器时走 SDK 会话存储，才能做会话版本校验与刷新。
  final bool _usesStoredAccessToken;

  AssistantEventStreamClient({
    http.Client? client,
    String baseUrl = serverHost,
    Future<String?> Function()? loadAccessToken,
  }) : _client = client,
       _baseUrl = baseUrl,
       _loadAccessToken = loadAccessToken ?? _defaultAccessToken,
       _usesStoredAccessToken = loadAccessToken == null;

  // 每次发送时再取 SDK 客户端，测试或登录切换替换后立即生效。
  http.Client get _httpClient => _client ?? sdk_api.apiClient;

  /// 订阅 [runId] 在 [afterSeq] 之后的事件；流在终止事件或待答问题处正常结束，
  /// 其余提前断开都以 [AssistantStreamException] 报告。
  Stream<AssistantRunEvent> runEvents({
    required Object runId,
    Object afterSeq = 0,
  }) async* {
    if (!jsonInt64IsPositive(runId)) {
      throw const ApiException('Assistant run 标识无效');
    }
    // 握手：首个会话版本贯穿重试，期间会话被替换则放弃而不是串号。
    late http.StreamedResponse response;
    final initialContext = _usesStoredAccessToken
        ? await getTokenSessionContext()
        : null;
    for (var attempt = 1; ; attempt++) {
      final requestContext = await _buildEventsRequest(
        runId: runId,
        afterSeq: afterSeq,
        expectedSessionRevision: initialContext?.revision,
      );
      final request = requestContext.$1;
      final session = requestContext.$2;
      try {
        response = await _httpClient.send(request);
      } catch (error) {
        throw AssistantStreamException('无法连接 Assistant: $error');
      }
      if (response.statusCode >= 200 && response.statusCode < 300) break;

      // 鉴权失败只在首轮尝试刷新一次；刷新成功后用新 token 重发。
      final body = await response.stream.bytesToString();
      final exception = _httpError(response.statusCode, body);
      final canRetry =
          attempt == 1 &&
          session != null &&
          (exception.isAuthError || response.statusCode == 401) &&
          session.tokens.refreshToken.trim().isNotEmpty;
      if (canRetry) {
        final refreshResult = await sdk_api.refreshSessionTokensFor(session);
        if (refreshResult == sdk_api.SessionRefreshResult.refreshed) continue;
        if (refreshResult == sdk_api.SessionRefreshResult.unavailable) {
          throw const ApiException('会话刷新失败，请重试');
        }
        if (refreshResult == sdk_api.SessionRefreshResult.stale) {
          throw const ApiException('请求会话已变化，请重试');
        }
      }
      if (session != null &&
          (exception.isAuthError || response.statusCode == 401)) {
        await sdk_api.invalidateSessionIfCredentialsMatch(session);
      }
      // 服务端过载可重试；其余 4xx 是确定性失败，禁止自动重连。
      if (response.statusCode >= 500 || response.statusCode == 429) {
        throw const AssistantStreamException('Assistant 服务暂时不可用');
      }
      throw AssistantStreamException(
        exception.message,
        code: exception.code,
        retryable: false,
      );
    }

    // 解码：逐帧转为事件，记录是否以终止事件或待答问题合法结束。
    var terminal = false;
    var waiting = false;
    // 已离开 pending 的问题 ID：同一问题迟到的 pending 副本不能让流合法挂起。
    final settledQuestionIds = <String>{};
    try {
      await for (final frame in _sseFrames(response.stream)) {
        if (frame.data.trim().isEmpty) continue;
        final decoded = decodeApiJson(frame.data);
        if (decoded is! Map) {
          throw const FormatException('assistant event is not an object');
        }
        final json = Map<String, dynamic>.from(decoded);
        // 连接失败不是持久化的 run 事件：不推进 seq，也不因订阅失败把 run 判为失败。
        if (json['type'] == 'transport_error') {
          final error = json['error'];
          if (error is! Map ||
              error['message'] is! String ||
              json['retryable'] is! bool) {
            throw const FormatException('invalid assistant transport error');
          }
          throw AssistantStreamException(
            error['message'] as String,
            retryable: json['retryable'] as bool,
          );
        }
        // 事件体缺 seq 时以 SSE id 补齐，保证断线续传游标前进。
        if (frame.id.isNotEmpty && json['seq'] == null) {
          json['seq'] = int.tryParse(frame.id) ?? 0;
        }
        final event = AssistantRunEvent.fromJson(json);
        if (event.type == AssistantEventType.unknown) continue;
        final question = event.questionRequest;
        // 已结清问题的迟到副本完全不改动 waiting，以免覆盖另一个仍待回答的问题。
        if (event.type == AssistantEventType.questionsRequired &&
            !(question != null && settledQuestionIds.contains(question.id))) {
          waiting = question?.isPending == true;
        }
        if (event.type == AssistantEventType.questionsResolved) {
          waiting = false;
        }
        if ((event.type == AssistantEventType.questionsRequired ||
                event.type == AssistantEventType.questionsResolved) &&
            question != null &&
            !question.isPending) {
          settledQuestionIds.add(question.id);
        }
        yield event;
        if (event.isTerminal) {
          terminal = true;
          break;
        }
      }
    } on FormatException {
      throw const AssistantStreamException(
        'Assistant 返回了无效事件',
        retryable: false,
      );
    } on JsonUnsupportedObjectError {
      throw const AssistantStreamException(
        'Assistant 返回了无效事件',
        retryable: false,
      );
    } on AssistantStreamException {
      rethrow;
    } catch (error) {
      throw AssistantStreamException('Assistant 连接中断: $error');
    }

    // 既没终止也没等待用户回答就断开，交给连接层按可重试处理。
    if (!terminal && !waiting) {
      throw const AssistantStreamException('Assistant 连接意外中断');
    }
  }

  // 组装带续传游标与鉴权头的 GET；同时返回所用会话快照供失败时刷新。
  Future<(http.Request, SessionTokenSnapshot?)> _buildEventsRequest({
    required Object runId,
    required Object afterSeq,
    int? expectedSessionRevision,
  }) async {
    final seq = _asInt(afterSeq);
    final path = gw.assistantRunEventsPath(jsonInt64Id(runId));
    final uri = apiUri(seq > 0 ? '$path?afterSeq=$seq' : path, host: _baseUrl);
    final request = http.Request('GET', uri);
    request.headers.addAll({
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
    });
    if (seq > 0) {
      request.headers['Last-Event-ID'] = '$seq';
    }
    final context = _usesStoredAccessToken
        ? await getTokenSessionContext()
        : null;
    if (context != null && context.revision != expectedSessionRevision) {
      throw const ApiException('请求会话已变化，请重试');
    }
    final session = context?.snapshot;
    final token =
        (_usesStoredAccessToken
                ? session?.tokens.accessToken
                : await _loadAccessToken())
            ?.trim() ??
        '';
    if (token.isNotEmpty) {
      request.headers['Authorization'] =
          token.toLowerCase().startsWith('bearer ') ? token : 'Bearer $token';
    }
    return (request, session);
  }

  // 最小 SSE 分帧：只认 id/data 字段，忽略注释行，空行结束一帧。
  static Stream<_SseFrame> _sseFrames(Stream<List<int>> bytes) async* {
    final dataLines = <String>[];
    var id = '';
    await for (final line
        in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          yield _SseFrame(id: id, data: dataLines.join('\n'));
          dataLines.clear();
          id = '';
        }
        continue;
      }
      if (line.startsWith(':')) continue;
      if (line.startsWith('id:')) {
        id = line.substring(3).trim();
        continue;
      }
      if (!line.startsWith('data:')) continue;
      var value = line.substring(5);
      if (value.startsWith(' ')) value = value.substring(1);
      dataLines.add(value);
    }
    // 流尾缺少空行时仍交付最后一帧。
    if (dataLines.isNotEmpty) {
      yield _SseFrame(id: id, data: dataLines.join('\n'));
    }
  }

  // 把握手失败的响应体转成 ApiException，非 JSON 时截断为有限长度文本。
  static ApiException _httpError(int statusCode, String body) {
    try {
      final decoded = decodeApiJson(body);
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
      // 解析失败时落到下方的有界纯文本错误。
    }
    final normalized = body.trim();
    return ApiException(
      normalized.isEmpty
          ? 'Assistant 请求失败 (HTTP $statusCode)'
          : normalized.substring(0, normalized.length.clamp(0, 200)),
    );
  }

  // 续传游标可能是 int 或字符串编码的 int64，统一解析为 int。
  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // 未注入加载器时的默认 token 来源：SDK 持久化的会话。
  static Future<String?> _defaultAccessToken() async {
    return (await getTokens())?.accessToken;
  }
}

// 一个已拼好多行 data 的 SSE 帧及其 id。
class _SseFrame {
  final String id;
  final String data;

  const _SseFrame({required this.id, required this.data});
}
