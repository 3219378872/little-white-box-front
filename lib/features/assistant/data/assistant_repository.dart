import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_adapter.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/api/v2_api_client.dart';
import '../../../sdk/api/api.dart' as sdk_api;
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart'
    show GetAgentConsentResp, SetAgentConsentReq, SetAgentConsentResp;
import '../../../sdk/vars/kv.dart';
import '../../../sdk/vars/vars.dart';
import 'assistant_models.dart';

class AssistantStreamException implements Exception {
  final String message;

  const AssistantStreamException(this.message);

  @override
  String toString() => message;
}

class AgentConsentStatus {
  final bool granted;
  final int grantedAt;
  final int revokedAt;
  final int consentVersion;
  final int currentVersion;

  const AgentConsentStatus({
    required this.granted,
    this.grantedAt = 0,
    this.revokedAt = 0,
    this.consentVersion = 0,
    this.currentVersion = 0,
  });

  bool get needsUpgrade =>
      granted && currentVersion > 0 && consentVersion < currentVersion;

  bool get canUseMemoryWatch => granted && !needsUpgrade;

  factory AgentConsentStatus.fromSdk(GetAgentConsentResp resp) {
    return AgentConsentStatus(
      granted: resp.granted,
      grantedAt: resp.grantedAt.toInt(),
      revokedAt: resp.revokedAt.toInt(),
      consentVersion: resp.consentVersion.toInt(),
      currentVersion: resp.currentVersion.toInt(),
    );
  }
}

abstract interface class AssistantDataSource {
  Future<AgentConsentStatus> loadAgentConsent();

  Future<void> setAgentConsent({required bool granted});

  Future<AssistantThreadSummary> getThread();

  Future<List<AssistantHistoryMessage>> listMessages({
    Object sessionId = 0,
    Object afterId = 0,
    int limit = 50,
  });

  Future<AssistantPostResult> postMessage({
    required String message,
    required String requestId,
    List<AssistantAttachment> attachments = const [],
  });

  Stream<AssistantRunEvent> runEvents({
    required Object runId,
    Object afterSeq = 0,
  });

  Future<Object> createSession();

  Future<int> markThreadRead();

  Future<void> deleteHistory();

  Future<void> cancelRun(Object runId);

  Future<void> confirmRun({
    required Object runId,
    required String callId,
    required bool approved,
  });

  Future<(List<MemoryRecord>, List<MemoryCapacity>)> listMemory({
    String target = '',
  });

  Future<MemoryWriteResult> addMemory({
    required String target,
    required String content,
    String requestId = '',
  });

  Future<MemoryWriteResult> replaceMemory({
    required Object id,
    required String content,
    required int version,
    String requestId = '',
  });

  Future<MemoryWriteResult> removeMemory({
    required Object id,
    required int version,
    String requestId = '',
  });

  Future<MemoryRecord> undoMemoryChange(Object changeId);

  Future<List<WatchTask>> listWatches();

  Future<WatchTask> createWatch({
    required String conditionType,
    required String targetType,
    Object targetId = 0,
    String targetText = '',
  });

  Future<void> updateWatch({required Object id, required bool enabled});

  Future<void> deleteWatch(Object id);

  Future<void> submitRecommendFeedback({
    required Object postId,
    required String reason,
    String requestId = '',
  });
}

class AssistantRepository implements AssistantDataSource {
  final http.Client? _client;
  final String _baseUrl;
  final Future<String?> Function() _loadAccessToken;
  final V2ApiClient _api;

  AssistantRepository({
    http.Client? client,
    String baseUrl = serverHost,
    Future<String?> Function()? loadAccessToken,
    V2ApiClient api = const V2ApiClient(),
  }) : _client = client,
       _baseUrl = baseUrl,
       _loadAccessToken = loadAccessToken ?? _defaultAccessToken,
       _api = api;

  http.Client get _httpClient => _client ?? sdk_api.apiClient;

  @override
  Future<AgentConsentStatus> loadAgentConsent() async {
    final resp = await apiCall<GetAgentConsentResp>(
      (ok, fail, eventually) =>
          gw.getAgentConsent(ok: ok, fail: fail, eventually: eventually),
    );
    return AgentConsentStatus.fromSdk(resp);
  }

  @override
  Future<void> setAgentConsent({required bool granted}) async {
    await apiCall<SetAgentConsentResp>(
      (ok, fail, eventually) => gw.setAgentConsent(
        SetAgentConsentReq(granted: granted),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  @override
  Future<AssistantThreadSummary> getThread() async {
    final response = await _api.get('/api/v2/assistant/thread');
    final raw = response['thread'];
    if (raw is! Map) {
      throw const ApiException('Assistant 线程响应格式无效');
    }
    return AssistantThreadSummary.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<List<AssistantHistoryMessage>> listMessages({
    Object sessionId = 0,
    Object afterId = 0,
    int limit = 50,
  }) async {
    final response = await _api.get(
      '/api/v2/assistant/messages',
      query: {
        if (jsonInt64IsPositive(sessionId)) 'sessionId': jsonInt64Id(sessionId),
        if (jsonInt64IsPositive(afterId)) 'afterId': jsonInt64Id(afterId),
        'limit': limit,
      },
    );
    final raw = response['messages'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          AssistantHistoryMessage.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<AssistantPostResult> postMessage({
    required String message,
    required String requestId,
    List<AssistantAttachment> attachments = const [],
  }) async {
    final normalized = message.trim();
    final normalizedRequestId = requestId.trim();
    if (normalized.isEmpty || normalized.length > 2000) {
      throw const ApiException('消息长度应为 1 到 2000 个字符');
    }
    if (normalizedRequestId.isEmpty) {
      throw const ApiException('Assistant 请求标识不能为空');
    }
    final response = await _api.post('/api/v2/assistant/messages', {
      'message': normalized,
      'requestId': normalizedRequestId,
      if (attachments.isNotEmpty)
        'attachments': [for (final item in attachments) item.toJson()],
    });
    return AssistantPostResult.fromJson(response);
  }

  @override
  Stream<AssistantRunEvent> runEvents({
    required Object runId,
    Object afterSeq = 0,
  }) async* {
    if (!jsonInt64IsPositive(runId)) {
      throw const ApiException('Assistant run 标识无效');
    }
    late http.StreamedResponse response;
    for (var attempt = 1; ; attempt++) {
      final request = await _buildEventsRequest(runId: runId, afterSeq: afterSeq);
      try {
        response = await _httpClient.send(request);
      } catch (error) {
        throw AssistantStreamException('无法连接 Assistant: $error');
      }
      if (response.statusCode >= 200 && response.statusCode < 300) break;

      final body = await response.stream.bytesToString();
      final exception = _httpError(response.statusCode, body);
      final canRetry =
          attempt == 1 &&
          exception.isAuthError &&
          ((await getTokens())?.refreshToken.trim().isNotEmpty ?? false);
      if (canRetry && await sdk_api.refreshSessionTokens()) {
        continue;
      }
      if (exception.isAuthError) {
        final leftover = await getTokens();
        if (leftover?.refreshToken.trim().isNotEmpty ?? false) {
          throw const ApiException('会话刷新失败，请重试');
        }
        await onAuthError?.call();
      }
      throw exception;
    }

    var terminal = false;
    try {
      await for (final frame in _sseFrames(response.stream)) {
        if (frame.data.trim().isEmpty) continue;
        final decoded = decodeApiJson(frame.data);
        if (decoded is! Map) {
          throw const FormatException('assistant event is not an object');
        }
        final json = Map<String, dynamic>.from(decoded);
        if (frame.id.isNotEmpty && json['seq'] == null) {
          json['seq'] = int.tryParse(frame.id) ?? 0;
        }
        final event = AssistantRunEvent.fromJson(json);
        if (event.type == AssistantEventType.unknown) continue;
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

  @override
  Future<Object> createSession() async {
    final response = await _api.post('/api/v2/assistant/sessions', {});
    return response['sessionId'] ?? 0;
  }

  @override
  Future<int> markThreadRead() async {
    final response = await _api.post('/api/v2/assistant/thread/read', {});
    final unread = response['unreadCount'];
    if (unread is num) return unread.toInt();
    return int.tryParse(unread?.toString() ?? '') ?? 0;
  }

  @override
  Future<void> deleteHistory() async {
    await _api.delete('/api/v2/assistant/history');
  }

  @override
  Future<void> cancelRun(Object runId) async {
    if (!jsonInt64IsPositive(runId)) {
      throw const ApiException('Assistant run 标识无效');
    }
    await _api.post('/api/v2/assistant/runs/${jsonInt64Id(runId)}/cancel', {});
  }

  @override
  Future<void> confirmRun({
    required Object runId,
    required String callId,
    required bool approved,
  }) async {
    if (!jsonInt64IsPositive(runId) || callId.trim().isEmpty) {
      throw const ApiException('确认参数无效');
    }
    await _api.post('/api/v2/assistant/runs/${jsonInt64Id(runId)}/confirm', {
      'callId': callId.trim(),
      'approved': approved,
    });
  }

  @override
  Future<(List<MemoryRecord>, List<MemoryCapacity>)> listMemory({
    String target = '',
  }) async {
    final response = await _api.get(
      '/api/v2/assistant/memory',
      query: {if (target.isNotEmpty) 'target': target},
    );
    final items = <MemoryRecord>[];
    final rawItems = response['items'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final entryTarget = map['target']?.toString() ?? '';
        if (!memoryTargets.contains(entryTarget)) continue;
        items.add(
          MemoryRecord(
            id: map['id'] ?? 0,
            target: entryTarget,
            content: map['content']?.toString() ?? '',
            version: _asInt(map['version']),
            createdAtMs: _asInt(map['createdAtMs']),
            updatedAtMs: _asInt(map['updatedAtMs']),
          ),
        );
      }
    }
    final capacities = <MemoryCapacity>[];
    final rawCaps = response['capacities'];
    if (rawCaps is List) {
      for (final item in rawCaps) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        capacities.add(
          MemoryCapacity(
            target: map['target']?.toString() ?? '',
            used: _asInt(map['used']),
            limit: _asInt(map['limit']),
          ),
        );
      }
    }
    return (items, capacities);
  }

  @override
  Future<MemoryWriteResult> addMemory({
    required String target,
    required String content,
    String requestId = '',
  }) async {
    _requireMemoryTarget(target);
    final response = await _api.post('/api/v2/assistant/memory', {
      'target': target,
      'content': content,
      if (requestId.isNotEmpty) 'requestId': requestId,
    });
    return _memoryWrite(response);
  }

  @override
  Future<MemoryWriteResult> replaceMemory({
    required Object id,
    required String content,
    required int version,
    String requestId = '',
  }) async {
    final response = await _api.patch(
      '/api/v2/assistant/memory/${jsonInt64Id(id)}',
      {
        'content': content,
        'version': version,
        if (requestId.isNotEmpty) 'requestId': requestId,
      },
    );
    return _memoryWrite(response);
  }

  @override
  Future<MemoryWriteResult> removeMemory({
    required Object id,
    required int version,
    String requestId = '',
  }) async {
    final response = await _api.delete(
      '/api/v2/assistant/memory/${jsonInt64Id(id)}',
      query: {
        'version': version,
        if (requestId.isNotEmpty) 'requestId': requestId,
      },
    );
    return MemoryWriteResult(changeId: response['changeId'] ?? 0);
  }

  @override
  Future<MemoryRecord> undoMemoryChange(Object changeId) async {
    final response = await _api.post(
      '/api/v2/assistant/memory/changes/${jsonInt64Id(changeId)}/undo',
      {},
    );
    final raw = response['entry'];
    if (raw is! Map) {
      throw const ApiException('撤销记忆响应格式无效');
    }
    final map = Map<String, dynamic>.from(raw);
    return MemoryRecord(
      id: map['id'] ?? 0,
      target: map['target']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      version: _asInt(map['version']),
      createdAtMs: _asInt(map['createdAtMs']),
      updatedAtMs: _asInt(map['updatedAtMs']),
    );
  }

  @override
  Future<List<WatchTask>> listWatches() async {
    final response = await _api.get('/api/v2/assistant/watch');
    final raw = response['tasks'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) _watchFromJson(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<WatchTask> createWatch({
    required String conditionType,
    required String targetType,
    Object targetId = 0,
    String targetText = '',
  }) async {
    _requireKnownWatchCondition(conditionType, targetType, targetId, targetText);
    final response = await _api.post('/api/v2/assistant/watch', {
      'conditionType': conditionType,
      'targetType': targetType,
      if (jsonInt64IsPositive(targetId)) 'targetId': jsonInt64Id(targetId),
      if (targetText.trim().isNotEmpty) 'targetText': targetText,
    });
    final raw = response['task'];
    if (raw is! Map) {
      throw const ApiException('创建追踪响应格式无效');
    }
    return _watchFromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<void> updateWatch({required Object id, required bool enabled}) async {
    await _api.patch('/api/v2/assistant/watch/${jsonInt64Id(id)}', {
      'enabled': enabled,
    });
  }

  @override
  Future<void> deleteWatch(Object id) async {
    await _api.delete('/api/v2/assistant/watch/${jsonInt64Id(id)}');
  }

  @override
  Future<void> submitRecommendFeedback({
    required Object postId,
    required String reason,
    String requestId = '',
  }) async {
    final normalizedReason = reason.trim();
    if (!jsonInt64IsPositive(postId) || normalizedReason.isEmpty) {
      throw const ApiException('推荐反馈参数无效');
    }
    await _api.post('/api/v2/assistant/recommend/feedback', {
      if (requestId.isNotEmpty) 'requestId': requestId,
      'postId': jsonInt64Id(postId),
      'reason': normalizedReason,
    });
  }

  static void _requireMemoryTarget(String target) {
    if (!memoryTargets.contains(target)) {
      throw const ApiException('未知的记忆目标');
    }
  }

  static void _requireKnownWatchCondition(
    String conditionType,
    String targetType,
    Object targetId,
    String targetText,
  ) {
    final expected = watchConditionTargetTypes[conditionType];
    if (expected == null) {
      throw const ApiException('未知的追踪条件类型');
    }
    if (targetType != expected) {
      throw const ApiException('追踪目标类型与条件不匹配');
    }
    switch (conditionType) {
      case 'author_new_post':
      case 'post_revised':
        if (!jsonInt64IsPositive(targetId)) {
          throw const ApiException('追踪目标标识无效');
        }
      case 'tag_new_post':
      case 'keyword_new_post':
        if (targetText.trim().isEmpty) {
          throw const ApiException('追踪关键词或标签不能为空');
        }
    }
  }

  static WatchTask _watchFromJson(Map<String, dynamic> json) {
    return WatchTask(
      id: json['id'] ?? 0,
      conditionType: json['conditionType']?.toString() ?? '',
      targetType: json['targetType']?.toString() ?? '',
      targetId: json['targetId'] ?? 0,
      targetText: json['targetText']?.toString() ?? '',
      enabled: json['enabled'] == true,
      version: _asInt(json['version']),
      createdAt: _asInt(json['createdAt']),
    );
  }

  static MemoryWriteResult _memoryWrite(Map<String, dynamic> response) {
    final raw = response['entry'];
    MemoryRecord? entry;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      entry = MemoryRecord(
        id: map['id'] ?? 0,
        target: map['target']?.toString() ?? '',
        content: map['content']?.toString() ?? '',
        version: _asInt(map['version']),
        createdAtMs: _asInt(map['createdAtMs']),
        updatedAtMs: _asInt(map['updatedAtMs']),
      );
    }
    return MemoryWriteResult(
      entry: entry,
      changeId: response['changeId'] ?? 0,
    );
  }

  Future<http.Request> _buildEventsRequest({
    required Object runId,
    required Object afterSeq,
  }) async {
    final seq = _asInt(afterSeq);
    final path = '/api/v2/assistant/runs/${jsonInt64Id(runId)}/events';
    final uri = apiUri(
      seq > 0 ? '$path?afterSeq=$seq' : path,
      host: _baseUrl,
    );
    final request = http.Request('GET', uri);
    request.headers.addAll({
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
    });
    if (seq > 0) {
      request.headers['Last-Event-ID'] = '$seq';
    }
    final token = (await _loadAccessToken())?.trim() ?? '';
    if (token.isNotEmpty) {
      request.headers['Authorization'] =
          token.toLowerCase().startsWith('bearer ') ? token : 'Bearer $token';
    }
    return request;
  }

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
    if (dataLines.isNotEmpty) yield _SseFrame(id: id, data: dataLines.join('\n'));
  }

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
      // Fall back to a bounded plain-text error below.
    }
    final normalized = body.trim();
    return ApiException(
      normalized.isEmpty
          ? 'Assistant 请求失败 (HTTP $statusCode)'
          : normalized.substring(0, normalized.length.clamp(0, 200)),
    );
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Future<String?> _defaultAccessToken() async {
    return (await getTokens())?.accessToken;
  }
}

class _SseFrame {
  final String id;
  final String data;

  const _SseFrame({required this.id, required this.data});
}
