part of 'assistant_notifier.dart';

// Pure message-list transforms shared by the run reducer and the commands;
// each takes the current list and returns the next one without touching state.

// Inserts or refreshes the question card; a late pending copy never reopens a
// request that has already left pending.
List<AssistantMessage> _questionMessages(
  List<AssistantMessage> messages,
  AssistantQuestionRequest question,
) {
  final id = jsonInt64Id(question.messageId);
  final existing = messages
      .where((message) => message.questionRequest?.id == question.id)
      .firstOrNull;
  if (existing?.questionRequest?.status != 'pending' &&
      existing?.questionRequest != null &&
      question.isPending) {
    return messages;
  }
  if (existing != null) {
    return [
      for (final message in messages)
        if (message.questionRequest?.id == question.id)
          message.copyWith(questionRequest: question)
        else
          message,
    ];
  }
  return [
    ...messages,
    AssistantMessage(
      id: id,
      runId: question.runId,
      role: AssistantMessageRole.assistant,
      kind: 'question',
      text: '',
      questionRequest: question,
    ),
  ];
}

// Replaces the streamed draft with the committed answer, adopting the persisted
// message id when history already delivered it.
List<AssistantMessage> _answerMessages(
  List<AssistantMessage> messages,
  String responseId,
  AssistantAnswerPresentation answer,
  String text,
) {
  final messageId = jsonInt64Id(answer.messageId);
  final persisted = messages
      .where((message) => message.id == messageId)
      .firstOrNull;
  final existing =
      persisted ??
      messages.where((message) => message.id == responseId).firstOrNull;
  final result = [
    for (final message in messages)
      if (message.id != responseId && message.id != messageId) message,
  ];
  final updated =
      (existing ??
              AssistantMessage(
                id: responseId,
                runId: answer.runId,
                role: AssistantMessageRole.assistant,
                text: '',
              ))
          .copyWith(
            id: persisted == null ? responseId : messageId,
            runId: answer.runId,
            text: text,
            answerPresentation: answer,
            isStreaming: false,
          );
  if (persisted == null) {
    result.add(updated);
  } else {
    _insertNumericMessage(result, updated);
  }
  return result;
}

// Adds a tool step to the run response or moves an existing step to [status].
List<AssistantMessage> _upsertTool(
  List<AssistantMessage> messages,
  String responseId,
  Object runId,
  AssistantToolCall call,
  AssistantToolStatus status,
) {
  return _updateResponseMessage(
    messages,
    responseId,
    runId,
    (message) {
      final existing = message.toolSteps.indexWhere(
        (step) => step.callId == call.callId,
      );
      final steps = [...message.toolSteps];
      final step = AssistantToolStep(
        callId: call.callId,
        tool: call.tool,
        summary: call.summary,
        status: status,
      );
      if (existing >= 0) {
        steps[existing] = steps[existing].copyWith(
          status: status,
          summary: call.summary.isEmpty ? null : call.summary,
        );
      } else {
        steps.add(step);
      }
      return message.copyWith(toolSteps: steps);
    },
    createIfMissing: true,
    matchPersistedTerminal: true,
  );
}

// Moves one confirmation step between states after the confirm call settles.
List<AssistantMessage> _setToolStatus(
  List<AssistantMessage> messages,
  Object runId,
  String callId, {
  required Set<AssistantToolStatus> from,
  required AssistantToolStatus to,
}) {
  return _updateResponseMessage(
    messages,
    'run-${jsonInt64Id(runId)}',
    runId,
    (message) => message.copyWith(
      toolSteps: [
        for (final step in message.toolSteps)
          if (step.callId == callId && from.contains(step.status))
            step.copyWith(status: to)
          else
            step,
      ],
    ),
    matchPersistedTerminal: true,
  );
}

// Applies [update] to the memory notice for [changeId] (undo progress flags).
List<AssistantMessage> _updateMemoryChange(
  List<AssistantMessage> messages,
  Object changeId,
  AssistantMessage Function(AssistantMessage) update,
) {
  return [
    for (final message in messages)
      if (message.isMemoryChanged &&
          jsonInt64Id(message.changeId) == jsonInt64Id(changeId))
        update(message)
      else
        message,
  ];
}

// Appends one system notice per memory change; replays of the same change are
// ignored.
List<AssistantMessage> _upsertMemoryChangedEvent(
  List<AssistantMessage> messages,
  Object runId,
  AssistantRunEvent event,
) {
  if (jsonInt64IsPositive(event.changeId) &&
      messages.any(
        (message) =>
            message.isMemoryChanged &&
            _sameRun(message.changeId, event.changeId),
      )) {
    return messages;
  }
  return [
    ...messages,
    AssistantMessage(
      id: 'memory-${jsonInt64Id(event.changeId)}-${event.seq}',
      runId: runId,
      role: AssistantMessageRole.system,
      kind: 'memory_changed',
      text: event.text.isEmpty ? '记忆已更新' : event.text,
      changeId: event.changeId,
    ),
  ];
}

// Drops the superseded draft text after a response_reset.
List<AssistantMessage> _clearResetResponse(
  List<AssistantMessage> messages,
  String responseId,
  Object runId,
) {
  return _updateResponseMessage(
    messages,
    responseId,
    runId,
    (message) => message.copyWith(text: ''),
    createIfMissing: true,
  );
}

// Updates the run's response message, falling back to the persisted terminal
// response when requested, and creating a streaming placeholder only while no
// persisted answer exists for the run.
List<AssistantMessage> _updateResponseMessage(
  List<AssistantMessage> messages,
  String id,
  Object runId,
  AssistantMessage Function(AssistantMessage) update, {
  bool createIfMissing = false,
  bool matchPersistedTerminal = false,
}) {
  final next = [...messages];
  var index = _exactMessageIndex(next, id);
  if (index < 0 && matchPersistedTerminal) {
    index = _persistedTerminalResponseIndex(next, runId);
  }
  if (index >= 0) {
    next[index] = update(next[index]);
    return next;
  }
  if (!createIfMissing || _hasPersistedTerminalResponseForRun(next, runId)) {
    return next;
  }
  next.add(
    update(
      AssistantMessage(
        id: id,
        runId: runId,
        role: AssistantMessageRole.assistant,
        text: '',
        isStreaming: true,
      ),
    ),
  );
  return next;
}
