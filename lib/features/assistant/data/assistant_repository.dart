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

/// Agent consent as returned by the Gateway `getAgentConsent` SDK call;
/// versions compare the user's granted disclosure with the current one.
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

  /// Granted against an older disclosure version; the user must re-consent.
  bool get needsUpgrade =>
      granted && currentVersion > 0 && consentVersion < currentVersion;

  /// Memory features require a consent that matches the current disclosure.
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

/// Assistant backend contract used by the notifiers; tests inject fakes here.
abstract interface class AssistantDataSource {
  /// Answers a still-pending question request inside its run.
  Future<AssistantQuestionRequest> answerQuestions({
    required AssistantQuestionRequest question,
    required String requestId,
    required List<AssistantQuestionAnswer> answers,
  });

  /// Resubmits answers to an expired question as a new message.
  Future<AssistantPostResult> continueQuestions({
    required AssistantQuestionRequest question,
    required String requestId,
    required List<AssistantQuestionAnswer> answers,
  });

  /// Reads the current agent consent and disclosure versions.
  Future<AgentConsentStatus> loadAgentConsent();

  /// Grants or revokes agent consent.
  Future<void> setAgentConsent({required bool granted});

  /// Loads the user's single assistant thread summary (unread, active run).
  Future<AssistantThreadSummary> getThread();

  /// Pages history: [afterId] fetches newer messages, [beforeId] older ones;
  /// the two cursors are mutually exclusive.
  Future<AssistantMessagePage> listMessages({
    Object sessionId = 0,
    Object afterId = 0,
    Object beforeId = 0,
    int limit = 50,
  });

  /// Posts a user message; [requestId] makes retries idempotent.
  Future<AssistantPostResult> postMessage({
    required String message,
    required String requestId,
    List<AssistantAttachment> attachments = const [],
    Object contextPostId = 0,
  });

  /// Streams run events after [afterSeq] for resume after a disconnect.
  Stream<AssistantRunEvent> runEvents({
    required Object runId,
    Object afterSeq = 0,
  });

  /// Marks the thread read and returns the remaining unread count.
  Future<int> markThreadRead();

  /// Deletes the whole conversation history.
  Future<void> deleteHistory();

  /// Asks the server to cancel an active run.
  Future<void> cancelRun(Object runId);

  /// Approves or declines a tool call that is awaiting confirmation.
  Future<void> confirmRun({
    required Object runId,
    required String callId,
    required bool approved,
  });

  /// Lists memory records and per-target capacity; an empty [target] means all.
  Future<(List<MemoryRecord>, List<MemoryCapacity>)> listMemory({
    String target = '',
  });

  /// Adds a memory record; the returned change id enables undo.
  Future<MemoryWriteResult> addMemory({
    required String target,
    required String content,
    String requestId = '',
  });

  /// Replaces a record's content; [version] guards against concurrent edits.
  Future<MemoryWriteResult> replaceMemory({
    required Object id,
    required String content,
    required int version,
    String requestId = '',
  });

  /// Removes a record at [version]; only the change id is returned.
  Future<MemoryWriteResult> removeMemory({
    required Object id,
    required int version,
    String requestId = '',
  });

  /// Reverts one memory change and returns the restored record.
  Future<MemoryRecord> undoMemoryChange(Object changeId);

  /// Sends feedback with a reason on a recommended post.
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

  // SDK getAgentConsent; int64 fields are narrowed to Dart ints.
  @override
  Future<AgentConsentStatus> loadAgentConsent() async {
    final resp = await apiCall<GetAgentConsentResp>(
      (ok, fail, eventually) =>
          gw.getAgentConsent(ok: ok, fail: fail, eventually: eventually),
    );
    return AgentConsentStatus.fromSdk(resp);
  }

  // SDK setAgentConsent; callers reload consent afterwards.
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

  // GET /api/v2/assistant/thread; the summary is wrapped in `thread`.
  @override
  Future<AssistantThreadSummary> getThread() async {
    final response = await _api.get('/api/v2/assistant/thread');
    final raw = response['thread'];
    if (raw is! Map) {
      throw const ApiException('Assistant 线程响应格式无效');
    }
    return AssistantThreadSummary.fromJson(Map<String, dynamic>.from(raw));
  }

  // GET /api/v2/assistant/messages; only positive ids are sent as cursors.
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

  // POST /api/v2/assistant/messages; length and request id are validated
  // locally so a request that cannot succeed is never sent.
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

  // POST /api/v2/assistant/runs/{runId}/answers; returns the updated request.
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

  // POST /api/v2/assistant/messages with a fixed prompt and `questionContext`,
  // letting the server pick up the expired question in a new message.
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

  // POST /api/v2/assistant/thread/read; a missing or negative count is a
  // protocol error.
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

  // DELETE /api/v2/assistant/history.
  @override
  Future<void> deleteHistory() async {
    await _api.delete('/api/v2/assistant/history');
  }

  // POST /api/v2/assistant/runs/{runId}/cancel.
  @override
  Future<void> cancelRun(Object runId) async {
    if (!jsonInt64IsPositive(runId)) {
      throw const ApiException('Assistant run 标识无效');
    }
    await _api.post('/api/v2/assistant/runs/${jsonInt64Id(runId)}/cancel', {});
  }

  // POST /api/v2/assistant/runs/{runId}/confirm.
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

  // GET /api/v2/assistant/memory.
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

  // POST /api/v2/assistant/memory; unknown targets are rejected client-side.
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

  // PATCH /api/v2/assistant/memory/{id}.
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

  // DELETE /api/v2/assistant/memory/{id}; version and request id travel in
  // the query string.
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

  // POST /api/v2/assistant/memory/changes/{changeId}/undo.
  @override
  Future<MemoryRecord> undoMemoryChange(Object changeId) async {
    final response = await _api.post(
      '/api/v2/assistant/memory/changes/${jsonInt64Id(changeId)}/undo',
      {},
    );
    return _undoneMemoryFromResponse(response);
  }

  // POST /api/v2/assistant/recommend/feedback.
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
