part of 'assistant_notifier.dart';

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

int _exactMessageIndex(List<AssistantMessage> messages, String responseId) {
  return messages.indexWhere((message) => message.id == responseId);
}

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

List<AssistantMessage> _updateAll(
  List<AssistantMessage> messages,
  String id,
  AssistantMessage Function(AssistantMessage) update,
) {
  return [
    for (final message in messages)
      if (message.id == id) update(message) else message,
  ];
}

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

bool _isTerminalAssistantResponse(AssistantMessage message) {
  return message.role == AssistantMessageRole.assistant &&
      (message.kind.isEmpty ||
          message.kind == 'message' ||
          message.kind == 'watch');
}

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

bool _idIsAfter(Object candidate, Object current) {
  final next = BigInt.tryParse(jsonInt64Id(candidate));
  final previous = BigInt.tryParse(jsonInt64Id(current));
  if (next == null) return false;
  return previous == null || next > previous;
}

bool _sameRun(Object left, Object right) {
  return jsonInt64Id(left) == jsonInt64Id(right);
}

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

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _defaultRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(12, (_) => random.nextInt(256));
  final suffix = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'assistant-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$suffix';
}
