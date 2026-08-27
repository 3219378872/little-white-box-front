import 'dart:async';

import 'package:xiaobaihe_app/core/api/json_int64.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart' hide AssistantChatEvent;

class FakeAssistantSource implements AssistantDataSource {
  Stream<AssistantChatEvent> Function({
    required String message,
    required String requestId,
    required String conversationId,
    required AssistantMode mode,
    required List<AssistantAttachment> attachments,
  })?
  chatHandler;

  bool granted = false;
  int consentVersion = 0;
  int currentVersion = 2;
  List<MemoryRecord> memories = const [];
  List<WatchTask> watches = const [];
  List<WatchHit> hits = const [];
  Object? lastError;
  int confirmCalls = 0;
  bool? lastApproved;
  AssistantMode? lastMode;
  List<AssistantAttachment> lastAttachments = const [];
  String? lastFeedbackReason;
  Object? lastFeedbackPostId;
  String? lastCreateCondition;

  @override
  Stream<AssistantChatEvent> chat({
    required String message,
    required String requestId,
    String conversationId = '',
    AssistantMode mode = AssistantMode.enhancedSearch,
    List<AssistantAttachment> attachments = const [],
  }) {
    lastMode = mode;
    lastAttachments = attachments;
    return chatHandler?.call(
          message: message,
          requestId: requestId,
          conversationId: conversationId,
          mode: mode,
          attachments: attachments,
        ) ??
        const Stream.empty();
  }

  @override
  Future<AgentConsentStatus> loadAgentConsent() async => AgentConsentStatus(
    granted: granted,
    consentVersion: granted ? consentVersion : 0,
    currentVersion: currentVersion,
  );

  @override
  Future<void> setAgentConsent({required bool granted}) async {
    this.granted = granted;
    consentVersion = granted ? currentVersion : 0;
  }

  @override
  Future<void> confirmTool({
    required String requestId,
    required String callId,
    required bool approved,
  }) async {
    confirmCalls++;
    lastApproved = approved;
  }

  @override
  Future<List<MemoryRecord>> listMemory() async {
    if (lastError != null) throw lastError!;
    return memories;
  }

  @override
  Future<void> updateMemory({
    required Object id,
    required String value,
    required double score,
    required bool suppressed,
  }) async {
    if (lastError != null) throw lastError!;
    memories = [
      for (final item in memories)
        if (jsonInt64Id(item.id) == jsonInt64Id(id))
          MemoryRecord(
            id: item.id,
            layer: item.layer,
            dimension: item.dimension,
            value: value,
            score: score,
            source: item.source,
            confidence: item.confidence,
            confirmed: item.confirmed,
            suppressed: suppressed,
            updatedAt: item.updatedAt,
          )
        else
          item,
    ];
  }

  @override
  Future<void> deleteMemory(Object id) async {
    if (lastError != null) throw lastError!;
    memories = [
      for (final item in memories)
        if (jsonInt64Id(item.id) != jsonInt64Id(id)) item,
    ];
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
  Future<List<WatchHit>> listWatchHits({bool unreadOnly = false}) async {
    if (lastError != null) throw lastError!;
    return [
      for (final hit in hits)
        if (!unreadOnly || !hit.read) hit,
    ];
  }

  @override
  Future<void> markWatchHitsRead(List<Object> hitIds) async {
    if (lastError != null) throw lastError!;
    final ids = {for (final id in hitIds) jsonInt64Id(id)};
    hits = [
      for (final hit in hits)
        if (ids.contains(jsonInt64Id(hit.id)))
          WatchHit(
            id: hit.id,
            taskId: hit.taskId,
            postId: hit.postId,
            title: hit.title,
            summary: hit.summary,
            createdAt: hit.createdAt,
            read: true,
          )
        else
          hit,
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
}
