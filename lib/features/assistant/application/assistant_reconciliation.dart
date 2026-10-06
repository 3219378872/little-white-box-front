part of 'assistant_notifier.dart';

// 确保 run 有流式回复占位（run-<runId>）；已有占位或已有持久化终态回复时不动。
List<AssistantMessage> _ensureAssistantIn(
  List<AssistantMessage> messages,
  String id,
  Object runId,
) {
  if (_exactMessageIndex(messages, id) >= 0 ||
      _hasPersistedTerminalResponseForRun(messages, runId)) {
    return messages;
  }
  return [
    ...messages,
    AssistantMessage(
      id: id,
      runId: runId,
      role: AssistantMessageRole.assistant,
      text: '',
      isStreaming: true,
    ),
  ];
}

// 按消息 ID 精确定位，找不到为 -1。
int _exactMessageIndex(List<AssistantMessage> messages, String responseId) {
  return messages.indexWhere((message) => message.id == responseId);
}

// 定位该 run 已持久化（数字 ID）的终态回复，找不到为 -1。
int _persistedTerminalResponseIndex(
  List<AssistantMessage> messages,
  Object runId,
) {
  if (!jsonInt64IsPositive(runId)) return -1;
  return messages.indexWhere(
    (message) =>
        _isTerminalAssistantResponse(message) &&
        _sameRun(message.runId, runId) &&
        BigInt.tryParse(message.id) != null,
  );
}

// run 结束时结算未完成的工具步骤：运行中按 [terminal] 成功或失败，
// 待确认与确认中一律过期。
List<AssistantToolStep> _settleSteps(
  List<AssistantToolStep> steps,
  AssistantToolStatus terminal,
) {
  return [
    for (final step in steps)
      switch (step.status) {
        AssistantToolStatus.running => step.copyWith(
          status: terminal == AssistantToolStatus.completed
              ? AssistantToolStatus.completed
              : AssistantToolStatus.failed,
        ),
        AssistantToolStatus.awaitingConfirmation => step.copyWith(
          status: AssistantToolStatus.expired,
        ),
        AssistantToolStatus.confirming => step.copyWith(
          status: AssistantToolStatus.expired,
        ),
        _ => step,
      },
  ];
}

// 按数字 ID 顺序插入；非数字 ID 的占位直接追加到末尾。
void _insertNumericMessage(
  List<AssistantMessage> messages,
  AssistantMessage message,
) {
  final messageId = BigInt.tryParse(message.id);
  final firstLaterMessage = messageId == null
      ? -1
      : messages.indexWhere((existing) {
          final existingId = BigInt.tryParse(existing.id);
          return existingId != null && existingId > messageId;
        });
  if (firstLaterMessage < 0) {
    messages.add(message);
  } else {
    messages.insert(firstLaterMessage, message);
  }
}

// 历史中已有该 run 的终态回复（数字 ID），说明 run 已结束、无需再跟随。
bool _hasPersistedTerminalResponseForRun(
  List<AssistantMessage> messages,
  Object runId,
) {
  if (!jsonInt64IsPositive(runId)) return false;
  return messages.any(
    (message) =>
        _isTerminalAssistantResponse(message) &&
        _sameRun(message.runId, runId) &&
        BigInt.tryParse(message.id) != null,
  );
}

// 该 run 的回复已收到终止事件或被本地取消（可能尚未持久化）。
bool _hasTerminalEventResponseForRun(
  List<AssistantMessage> messages,
  Object runId,
) {
  if (!jsonInt64IsPositive(runId)) return false;
  return messages.any(
    (message) =>
        message.role == AssistantMessageRole.assistant &&
        message.terminalEventReceived &&
        _sameRun(message.runId, runId),
  );
}

// 助手的正式回复（kind 为空或 message），区别于提问卡与系统提示。
bool _isTerminalAssistantResponse(AssistantMessage message) {
  return message.role == AssistantMessageRole.assistant &&
      (message.kind.isEmpty || message.kind == 'message');
}

// 发送受理后把乐观消息换成服务端 ID：历史刷新已先带回该消息时停在它的位置，
// 否则按数字 ID 插入。
List<AssistantMessage> _reconcileAcceptedUserMessage(
  List<AssistantMessage> messages, {
  required String optimisticId,
  required String acceptedMessageId,
  required Object acceptedRunId,
}) {
  final optimisticIndex = messages.indexWhere(
    (item) => item.id == optimisticId,
  );
  if (optimisticIndex < 0) return [...messages];

  final acceptedIndex = messages.indexWhere(
    (item) => item.id == acceptedMessageId,
  );
  final acceptedMessage = messages[optimisticIndex].copyWith(
    id: acceptedMessageId,
    runId: acceptedRunId,
  );
  final result = [
    for (final item in messages)
      if (item.id != optimisticId && item.id != acceptedMessageId) item,
  ];

  // A history refresh can observe the accepted write before POST returns.
  if (acceptedIndex >= 0) {
    final insertionIndex = messages
        .take(acceptedIndex)
        .where(
          (item) => item.id != optimisticId && item.id != acceptedMessageId,
        )
        .length;
    result.insert(insertionIndex, acceptedMessage);
    return result;
  }

  final acceptedNumericId = BigInt.parse(acceptedMessageId);
  final firstLaterMessage = result.indexWhere((item) {
    final itemId = BigInt.tryParse(item.id);
    return itemId != null && itemId > acceptedNumericId;
  });
  if (firstLaterMessage < 0) {
    result.add(acceptedMessage);
  } else {
    result.insert(firstLaterMessage, acceptedMessage);
  }
  return result;
}

// int64 ID 比较：[candidate] 严格大于 [current]；[current] 无效时视为最小。
bool _idIsAfter(Object candidate, Object current) {
  final next = BigInt.tryParse(jsonInt64Id(candidate));
  final previous = BigInt.tryParse(jsonInt64Id(current));
  if (next == null) return false;
  return previous == null || next > previous;
}

// 按 int64 文本比较两个 ID（run、会话、变更 ID 通用）。
bool _sameRun(Object left, Object right) {
  return jsonInt64Id(left) == jsonInt64Id(right);
}

// 历史消息转为界面消息；未知角色按助手处理。
AssistantMessage _fromHistory(AssistantHistoryMessage item) {
  final role = switch (item.role) {
    'user' => AssistantMessageRole.user,
    'system' => AssistantMessageRole.system,
    _ => AssistantMessageRole.assistant,
  };
  return AssistantMessage(
    id: jsonInt64Id(item.id),
    runId: item.runId,
    questionRequest: item.questionRequest,
    answerPresentation: item.answerPresentation,
    role: role,
    kind: item.kind,
    text: item.content,
    changeId: item.changeId,
  );
}

// 宽松解析 seq 游标。
int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

// 助手运行的默认请求 ID：12 字节随机段，保持既有格式。
String _defaultRequestId() =>
    newPrefixedRequestId('assistant', randomBytes: 12);
