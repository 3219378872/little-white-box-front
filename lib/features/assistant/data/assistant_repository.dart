import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_adapter.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../sdk/api/api.dart' as sdk_api;
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart' hide AssistantChatEvent;
import '../../../sdk/vars/kv.dart';
import '../../../sdk/vars/vars.dart';
import 'assistant_models.dart';

class AssistantStreamException implements Exception {
  final String message;

  const AssistantStreamException(this.message);

  @override
  String toString() => message;
}

/// Agent 能力授权状态（AGNT-004/006/007）。
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
  Stream<AssistantChatEvent> chat({
    required String message,
    required String requestId,
    String conversationId = '',
    AssistantMode mode = AssistantMode.enhancedSearch,
    List<AssistantAttachment> attachments = const [],
  });

  Future<AgentConsentStatus> loadAgentConsent();

  Future<void> setAgentConsent({required bool granted});

  /// 高危操作确认回调（AGNT-020~022）。
  Future<void> confirmTool({
    required String requestId,
    required String callId,
    required bool approved,
  });

  Future<List<MemoryRecord>> listMemory();

  Future<void> updateMemory({
    required Object id,
    required String value,
    required double score,
    required bool suppressed,
  });

  Future<void> deleteMemory(Object id);

  Future<List<WatchTask>> listWatches();

  Future<WatchTask> createWatch({
    required String conditionType,
    required String targetType,
    Object targetId = 0,
    String targetText = '',
  });

  Future<void> updateWatch({required Object id, required bool enabled});

  Future<void> deleteWatch(Object id);

  Future<List<WatchHit>> listWatchHits({bool unreadOnly = false});

  Future<void> markWatchHitsRead(List<Object> hitIds);

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
    AssistantMode mode = AssistantMode.enhancedSearch,
    List<AssistantAttachment> attachments = const [],
  }) async* {
    final normalized = message.trim();
    final normalizedRequestId = requestId.trim();
    if (normalized.isEmpty || normalized.length > 2000) {
      throw const ApiException('消息长度应为 1 到 2000 个字符');
    }
    if (normalizedRequestId.isEmpty) {
      throw const ApiException('Assistant 请求标识不能为空');
    }

    // 认证失败时换发令牌并恰好重试一次，与传输层行为一致。
    late http.StreamedResponse response;
    for (var attempt = 1; ; attempt++) {
      final request = await _buildChatRequest(
        conversationId: conversationId,
        normalized: normalized,
        normalizedRequestId: normalizedRequestId,
        mode: mode,
        attachments: attachments,
      );
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
      if (exception.isAuthError) await onAuthError?.call();
      throw exception;
    }

    var terminal = false;
    try {
      await for (final data in _sseData(response.stream)) {
        if (data.trim().isEmpty) continue;
        final decoded = decodeApiJson(data);
        if (decoded is! Map) {
          throw const FormatException('assistant event is not an object');
        }
        final event = AssistantChatEvent.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        // FX-059：未知事件类型跳过，不作为错误终止。
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
  Future<void> confirmTool({
    required String requestId,
    required String callId,
    required bool approved,
  }) async {
    await apiCall<AssistantToolConfirmResp>(
      (ok, fail, eventually) => gw.confirmAssistantTool(
        AssistantToolConfirmReq(
          requestId: requestId,
          callId: callId,
          approved: approved,
        ),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  @override
  Future<List<MemoryRecord>> listMemory() async {
    final resp = await apiCall<ListAssistantMemoryResp>(
      (ok, fail, eventually) =>
          gw.listAssistantMemory(ok: ok, fail: fail, eventually: eventually),
    );
    return [
      for (final item in resp.items)
        if (memoryListLayers.contains(item.layer))
          MemoryRecord(
            id: item.id,
            layer: item.layer,
            dimension: item.dimension,
            value: item.value,
            score: item.score.toDouble(),
            source: item.source,
            confidence: item.confidence.toDouble(),
            confirmed: item.confirmed,
            suppressed: item.suppressed,
            updatedAt: item.updatedAt.toInt(),
          ),
    ];
  }

  @override
  Future<void> updateMemory({
    required Object id,
    required String value,
    required double score,
    required bool suppressed,
  }) async {
    await apiCall<UpdateAssistantMemoryResp>(
      (ok, fail, eventually) => gw.updateAssistantMemory(
        jsonInt64Id(id),
        UpdateAssistantMemoryReq(
          id: jsonInt64Id(id),
          value: value,
          score: score,
          suppressed: suppressed,
        ),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  @override
  Future<void> deleteMemory(Object id) async {
    await apiCall<DeleteAssistantMemoryResp>(
      (ok, fail, eventually) => gw.deleteAssistantMemory(
        jsonInt64Id(id),
        DeleteAssistantMemoryReq(id: jsonInt64Id(id)),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  @override
  Future<List<WatchTask>> listWatches() async {
    final resp = await apiCall<ListAssistantWatchResp>(
      (ok, fail, eventually) =>
          gw.listAssistantWatch(ok: ok, fail: fail, eventually: eventually),
    );
    return [
      for (final task in resp.tasks)
        WatchTask(
          id: task.id,
          conditionType: task.conditionType,
          targetType: task.targetType,
          targetId: task.targetId,
          targetText: task.targetText,
          enabled: task.enabled,
          createdAt: task.createdAt.toInt(),
        ),
    ];
  }

  @override
  Future<WatchTask> createWatch({
    required String conditionType,
    required String targetType,
    Object targetId = 0,
    String targetText = '',
  }) async {
    _requireKnownWatchCondition(
      conditionType,
      targetType,
      targetId,
      targetText,
    );
    final resp = await apiCall<CreateAssistantWatchResp>(
      (ok, fail, eventually) => gw.createAssistantWatch(
        CreateAssistantWatchReq(
          conditionType: conditionType,
          targetType: targetType,
          targetId: jsonInt64IsPositive(targetId) ? jsonInt64Id(targetId) : 0,
          targetText: targetText,
        ),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
    final task = resp.task;
    return WatchTask(
      id: task.id,
      conditionType: task.conditionType,
      targetType: task.targetType,
      targetId: task.targetId,
      targetText: task.targetText,
      enabled: task.enabled,
      createdAt: task.createdAt.toInt(),
    );
  }

  @override
  Future<void> updateWatch({required Object id, required bool enabled}) async {
    await apiCall<UpdateAssistantWatchResp>(
      (ok, fail, eventually) => gw.updateAssistantWatch(
        jsonInt64Id(id),
        UpdateAssistantWatchReq(id: jsonInt64Id(id), enabled: enabled),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  @override
  Future<void> deleteWatch(Object id) async {
    await apiCall<DeleteAssistantWatchResp>(
      (ok, fail, eventually) => gw.deleteAssistantWatch(
        jsonInt64Id(id),
        DeleteAssistantWatchReq(id: jsonInt64Id(id)),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  @override
  Future<List<WatchHit>> listWatchHits({bool unreadOnly = false}) async {
    final resp = await apiCall<ListAssistantWatchHitsResp>(
      (ok, fail, eventually) =>
          gw.listAssistantWatchHits(ok: ok, fail: fail, eventually: eventually),
    );
    return [
      for (final hit in resp.hits)
        if (!unreadOnly || !hit.read)
          WatchHit(
            id: hit.id,
            taskId: hit.taskId,
            postId: hit.postId,
            title: hit.title,
            summary: hit.summary,
            createdAt: hit.createdAt.toInt(),
            read: hit.read,
          ),
    ];
  }

  @override
  Future<void> markWatchHitsRead(List<Object> hitIds) async {
    if (hitIds.isEmpty) return;
    await apiCall<MarkAssistantWatchHitsReadResp>(
      (ok, fail, eventually) => gw.markAssistantWatchHitsRead(
        MarkAssistantWatchHitsReadReq(
          hitIds: [for (final id in hitIds) jsonInt64Id(id)],
        ),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
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
    await apiCall<AssistantRecommendFeedbackResp>(
      (ok, fail, eventually) => gw.submitAssistantRecommendFeedback(
        AssistantRecommendFeedbackReq(
          requestId: requestId,
          postId: jsonInt64Id(postId),
          reason: normalizedReason,
        ),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
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

  Future<http.Request> _buildChatRequest({
    required String conversationId,
    required String normalized,
    required String normalizedRequestId,
    required AssistantMode mode,
    required List<AssistantAttachment> attachments,
  }) async {
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
    request.body = encodeApiJson({
      if (conversationId.trim().isNotEmpty)
        'conversationId': conversationId.trim(),
      'message': normalized,
      'requestId': normalizedRequestId,
      'mode': mode.wireValue,
      if (attachments.isNotEmpty)
        'attachments': [
          for (final attachment in attachments)
            {'mediaId': attachment.mediaId, 'url': attachment.url},
        ],
    });
    return request;
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

  static Future<String?> _defaultAccessToken() async {
    return (await getTokens())?.accessToken;
  }
}
