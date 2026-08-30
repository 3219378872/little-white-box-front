import 'dart:async';

import 'package:xiaobaihe_app/core/api/json_int64.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';

class FakeAssistantSource implements AssistantDataSource {
  Stream<AssistantRunEvent> Function({
    required Object runId,
    required Object afterSeq,
  })?
  eventsHandler;

  Future<AssistantThreadSummary> Function()? threadHandler;

  Future<AssistantPostResult> Function({
    required String message,
    required String requestId,
    required List<AssistantAttachment> attachments,
    required Object contextPostId,
  })?
  postHandler;

  bool granted = true;
  int consentVersion = 2;
  int currentVersion = 2;
  AssistantThreadSummary thread = const AssistantThreadSummary(sessionId: 1);
  List<AssistantHistoryMessage> messages = const [];
  List<MemoryRecord> memories = const [];
  List<MemoryCapacity> capacities = const [];
  List<WatchTask> watches = const [];
  Object? lastError;
  Object? cancelError;
  Object? confirmError;
  Object? undoError;
  Object? consentError;
  int confirmCalls = 0;
  bool? lastApproved;
  Object? lastCancelRunId;
  List<AssistantAttachment> lastAttachments = const [];
  String? lastFeedbackReason;
  Object? lastFeedbackPostId;
  String? lastCreateCondition;
  String? lastPostedMessage;
  Object lastEventsAfterSeq = 0;
  Object lastEventsRunId = 0;
  int sessionCreates = 0;
  int historyDeletes = 0;
  int threadReads = 0;
  Object? lastUndoChangeId;
  List<int> eventCalls = [];
  int listMessageCalls = 0;
  List<String> postedRequestIds = [];
  List<Object> postedContextPostIds = [];

  @override
  Future<AgentConsentStatus> loadAgentConsent() async => AgentConsentStatus(
    granted: granted,
    consentVersion: granted ? consentVersion : 0,
    currentVersion: currentVersion,
  );

  @override
  Future<void> setAgentConsent({required bool granted}) async {
    if (consentError != null) throw consentError!;
    this.granted = granted;
    consentVersion = granted ? currentVersion : 0;
  }

  @override
  Future<AssistantThreadSummary> getThread() async {
    if (lastError != null) throw lastError!;
    if (threadHandler != null) return threadHandler!();
    return thread;
  }

  @override
  Future<AssistantMessagePage> listMessages({
    Object sessionId = 0,
    Object afterId = 0,
    Object beforeId = 0,
    int limit = 50,
  }) async {
    listMessageCalls++;
    if (lastError != null) throw lastError!;
    var filtered = [
      for (final item in messages)
        if ((!jsonInt64IsPositive(sessionId) ||
                jsonInt64Id(item.sessionId) == jsonInt64Id(sessionId)) &&
            (!jsonInt64IsPositive(afterId) || _isAfter(item.id, afterId)) &&
            (!jsonInt64IsPositive(beforeId) || _isAfter(beforeId, item.id)))
          item,
    ];
    filtered.sort((left, right) => _compareIds(left.id, right.id));
    final hasMore = filtered.length > limit;
    if (hasMore) {
      filtered = jsonInt64IsPositive(afterId)
          ? filtered.take(limit).toList()
          : filtered.sublist(filtered.length - limit);
    }
    return AssistantMessagePage(
      messages: filtered,
      hasMore: hasMore,
      nextBeforeId: jsonInt64IsPositive(afterId) || filtered.isEmpty
          ? 0
          : filtered.first.id,
    );
  }

  @override
  Future<AssistantPostResult> postMessage({
    required String message,
    required String requestId,
    List<AssistantAttachment> attachments = const [],
    Object contextPostId = 0,
  }) async {
    lastPostedMessage = message;
    lastAttachments = attachments;
    postedRequestIds.add(requestId);
    postedContextPostIds.add(contextPostId);
    if (postHandler != null) {
      return postHandler!(
        message: message,
        requestId: requestId,
        attachments: attachments,
        contextPostId: contextPostId,
      );
    }
    return const AssistantPostResult(
      messageId: 11,
      sessionId: 1,
      runId: 21,
      disposition: AssistantDisposition.started,
    );
  }

  @override
  Stream<AssistantRunEvent> runEvents({
    required Object runId,
    Object afterSeq = 0,
  }) {
    lastEventsRunId = runId;
    lastEventsAfterSeq = afterSeq;
    eventCalls.add(_asInt(afterSeq));
    return eventsHandler?.call(runId: runId, afterSeq: afterSeq) ??
        const Stream.empty();
  }

  @override
  Future<Object> createSession() async {
    sessionCreates++;
    thread = AssistantThreadSummary(
      sessionId: sessionCreates + 1,
      unreadCount: thread.unreadCount,
    );
    return thread.sessionId;
  }

  @override
  Future<int> markThreadRead() async {
    threadReads++;
    thread = AssistantThreadSummary(
      sessionId: thread.sessionId,
      lastMessageId: thread.lastMessageId,
      lastMessagePreview: thread.lastMessagePreview,
      lastMessageAtMs: thread.lastMessageAtMs,
      activeRunId: thread.activeRunId,
      activeRunStatus: thread.activeRunStatus,
      activeRunPhase: thread.activeRunPhase,
    );
    return 0;
  }

  @override
  Future<void> deleteHistory() async {
    historyDeletes++;
    messages = const [];
  }

  @override
  Future<void> cancelRun(Object runId) async {
    if (cancelError != null) throw cancelError!;
    lastCancelRunId = runId;
  }

  @override
  Future<void> confirmRun({
    required Object runId,
    required String callId,
    required bool approved,
  }) async {
    confirmCalls++;
    if (confirmError != null) throw confirmError!;
    lastApproved = approved;
  }

  @override
  Future<(List<MemoryRecord>, List<MemoryCapacity>)> listMemory({
    String target = '',
  }) async {
    if (lastError != null) throw lastError!;
    final items = [
      for (final item in memories)
        if (target.isEmpty || item.target == target) item,
    ];
    return (items, capacities);
  }

  @override
  Future<MemoryWriteResult> addMemory({
    required String target,
    required String content,
    String requestId = '',
  }) async {
    if (lastError != null) throw lastError!;
    final record = MemoryRecord(
      id: memories.length + 1,
      target: target,
      content: content,
      version: 1,
    );
    memories = [...memories, record];
    return MemoryWriteResult(entry: record, changeId: memories.length);
  }

  @override
  Future<MemoryWriteResult> replaceMemory({
    required Object id,
    required String content,
    required int version,
    String requestId = '',
  }) async {
    if (lastError != null) throw lastError!;
    memories = [
      for (final item in memories)
        if (jsonInt64Id(item.id) == jsonInt64Id(id))
          MemoryRecord(
            id: item.id,
            target: item.target,
            content: content,
            version: item.version + 1,
            createdAtMs: item.createdAtMs,
            updatedAtMs: item.updatedAtMs,
          )
        else
          item,
    ];
    return MemoryWriteResult(changeId: 1);
  }

  @override
  Future<MemoryWriteResult> removeMemory({
    required Object id,
    required int version,
    String requestId = '',
  }) async {
    if (lastError != null) throw lastError!;
    memories = [
      for (final item in memories)
        if (jsonInt64Id(item.id) != jsonInt64Id(id)) item,
    ];
    return const MemoryWriteResult(changeId: 1);
  }

  @override
  Future<MemoryRecord> undoMemoryChange(Object changeId) async {
    lastUndoChangeId = changeId;
    if (undoError != null) throw undoError!;
    if (lastError != null) throw lastError!;
    return memories.isEmpty
        ? const MemoryRecord(id: 0, target: 'memory', content: '')
        : memories.first;
  }

  @override
  Future<List<WatchTask>> listWatches() async {
    if (lastError != null) throw lastError!;
    return watches;
  }

  @override
  Future<WatchTask> createWatch({
    required String conditionType,
    required String targetType,
    Object targetId = 0,
    String targetText = '',
  }) async {
    lastCreateCondition = conditionType;
    if (lastError != null) throw lastError!;
    if (!watchConditionTargetTypes.containsKey(conditionType)) {
      throw const FormatException('unknown watch');
    }
    final task = WatchTask(
      id: watches.length + 1,
      conditionType: conditionType,
      targetType: targetType,
      targetId: targetId,
      targetText: targetText,
    );
    watches = [...watches, task];
    return task;
  }

  @override
  Future<void> updateWatch({required Object id, required bool enabled}) async {
    if (lastError != null) throw lastError!;
    watches = [
      for (final task in watches)
        if (jsonInt64Id(task.id) == jsonInt64Id(id))
          WatchTask(
            id: task.id,
            conditionType: task.conditionType,
            targetType: task.targetType,
            targetId: task.targetId,
            targetText: task.targetText,
            enabled: enabled,
            version: task.version,
            createdAt: task.createdAt,
          )
        else
          task,
    ];
  }

  @override
  Future<void> deleteWatch(Object id) async {
    if (lastError != null) throw lastError!;
    watches = [
      for (final task in watches)
        if (jsonInt64Id(task.id) != jsonInt64Id(id)) task,
    ];
  }

  @override
  Future<void> submitRecommendFeedback({
    required Object postId,
    required String reason,
    String requestId = '',
  }) async {
    if (lastError != null) throw lastError!;
    lastFeedbackPostId = postId;
    lastFeedbackReason = reason;
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _compareIds(Object left, Object right) {
    final leftId = BigInt.tryParse(jsonInt64Id(left)) ?? BigInt.zero;
    final rightId = BigInt.tryParse(jsonInt64Id(right)) ?? BigInt.zero;
    return leftId.compareTo(rightId);
  }

  static bool _isAfter(Object candidate, Object cursor) {
    return _compareIds(candidate, cursor) > 0;
  }
}
