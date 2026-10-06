import 'package:http/http.dart' as http;

import '../../../core/api/api_adapter.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/api/v2_api_client.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart'
    show GetAgentConsentResp, SetAgentConsentReq, SetAgentConsentResp;
import '../../../sdk/vars/vars.dart';
import 'assistant_event_stream.dart';
import 'assistant_models.dart';

export 'assistant_event_stream.dart' show AssistantStreamException;

part 'assistant_memory_mapping.dart';

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

  bool get canUseMemory => granted && !needsUpgrade;

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
  Future<AssistantQuestionRequest> answerQuestions({
    required AssistantQuestionRequest question,
    required String requestId,
    required List<AssistantQuestionAnswer> answers,
  });
  Future<AssistantPostResult> continueQuestions({
    required AssistantQuestionRequest question,
    required String requestId,
    required List<AssistantQuestionAnswer> answers,
  });
  Future<AgentConsentStatus> loadAgentConsent();

  Future<void> setAgentConsent({required bool granted});

  Future<AssistantThreadSummary> getThread();

  Future<AssistantMessagePage> listMessages({
    Object sessionId = 0,
    Object afterId = 0,
    Object beforeId = 0,
    int limit = 50,
  });

  Future<AssistantPostResult> postMessage({
    required String message,
    required String requestId,
    List<AssistantAttachment> attachments = const [],
    Object contextPostId = 0,
  });

  Stream<AssistantRunEvent> runEvents({
    required Object runId,
    Object afterSeq = 0,
  });

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

  Future<void> submitRecommendFeedback({
    required Object postId,
    required String reason,
    String requestId = '',
  });
}

/// Gateway-backed [AssistantDataSource]: REST calls go through [V2ApiClient],
/// run events are delegated to [AssistantEventStreamClient], and memory
/// response parsing lives in assistant_memory_mapping.dart.
class AssistantRepository implements AssistantDataSource {
  final AssistantEventStreamClient _events;
  final V2ApiClient _api;

  AssistantRepository({
    http.Client? client,
    String baseUrl = serverHost,
    Future<String?> Function()? loadAccessToken,
    V2ApiClient api = const V2ApiClient(),
  }) : _events = AssistantEventStreamClient(
         client: client,
         baseUrl: baseUrl,
         loadAccessToken: loadAccessToken,
       ),
       _api = api;

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
  Future<AssistantMessagePage> listMessages({
    Object sessionId = 0,
    Object afterId = 0,
    Object beforeId = 0,
    int limit = 50,
  }) async {
    if (jsonInt64IsPositive(afterId) && jsonInt64IsPositive(beforeId)) {
      throw const ApiException('Assistant 消息游标不能同时向前和向后');
    }
    final response = await _api.get(
      '/api/v2/assistant/messages',
      query: {
        if (jsonInt64IsPositive(sessionId)) 'sessionId': jsonInt64Id(sessionId),
        if (jsonInt64IsPositive(afterId)) 'afterId': jsonInt64Id(afterId),
        if (jsonInt64IsPositive(beforeId)) 'beforeId': jsonInt64Id(beforeId),
        'limit': limit,
      },
    );
    final raw = _requiredList(response, 'messages');
    final messages = [
      for (final item in raw)
        AssistantHistoryMessage.fromJson(_requiredObject(item)),
    ];
    return AssistantMessagePage(
      messages: messages,
      hasMore: response['hasMore'] == true,
      nextBeforeId: response['nextBeforeId'] ?? 0,
    );
  }

  @override
  Future<AssistantPostResult> postMessage({
    required String message,
    required String requestId,
    List<AssistantAttachment> attachments = const [],
    Object contextPostId = 0,
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
      'clientProtocolVersion': 2,
      'message': normalized,
      'requestId': normalizedRequestId,
      if (attachments.isNotEmpty)
        'attachments': [for (final item in attachments) item.toJson()],
      if (jsonInt64IsPositive(contextPostId))
        'contextPostId': jsonInt64JsonValue(contextPostId),
    });
    return AssistantPostResult.fromJson(response);
  }

  @override
  Future<AssistantQuestionRequest> answerQuestions({
    required AssistantQuestionRequest question,
    required String requestId,
    required List<AssistantQuestionAnswer> answers,
  }) async {
    final response = await _api.post(
      '/api/v2/assistant/runs/${jsonInt64Id(question.runId)}/answers',
      {
        'questionRequestId': question.id,
        'requestId': requestId,
        'answers': [for (final answer in answers) answer.toJson()],
      },
    );
    return AssistantQuestionRequest.fromJson(
      Map<String, dynamic>.from(response['questionRequest'] as Map),
    );
  }

  @override
  Future<AssistantPostResult> continueQuestions({
    required AssistantQuestionRequest question,
    required String requestId,
    required List<AssistantQuestionAnswer> answers,
  }) async {
    final response = await _api.post('/api/v2/assistant/messages', {
      'message': '继续上次的问题。',
      'requestId': requestId,
      'clientProtocolVersion': 2,
      'questionContext': {
        'runId': question.runId,
        'questionRequestId': question.id,
        'answers': [for (final answer in answers) answer.toJson()],
      },
    });
    return AssistantPostResult.fromJson(response);
  }

  @override
  Stream<AssistantRunEvent> runEvents({
    required Object runId,
    Object afterSeq = 0,
  }) => _events.runEvents(runId: runId, afterSeq: afterSeq);

  @override
  Future<int> markThreadRead() async {
    final response = await _api.post('/api/v2/assistant/thread/read', {});
    final unread = response['unreadCount'];
    final count = unread is int ? unread : int.tryParse('$unread');
    if (count == null || count < 0) {
      throw const ApiException('Assistant 未读响应格式无效');
    }
    return count;
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
    return _memoryListFromResponse(response);
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
    return _memoryWriteFromResponse(response);
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
    return _memoryWriteFromResponse(response);
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
    return _undoneMemoryFromResponse(response);
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
      'postId': jsonInt64JsonValue(postId),
      'reason': normalizedReason,
    });
  }
}

// List fields must be present; Go nil slices are encoded as explicit JSON null.
List<dynamic> _requiredList(Map<String, dynamic> response, String key) {
  if (!response.containsKey(key)) {
    throw const ApiException('Assistant 列表响应缺少字段');
  }
  final raw = response[key];
  if (raw == null) return const [];
  if (raw is! List) throw const ApiException('Assistant 列表响应格式无效');
  return raw;
}

// List items must already be JSON objects.
Map<String, dynamic> _requiredObject(Object? raw) {
  if (raw is! Map<String, dynamic>) {
    throw const ApiException('Assistant 列表项格式无效');
  }
  return raw;
}

// Lenient int decoding shared with memory mapping; numeric strings are accepted.
int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
