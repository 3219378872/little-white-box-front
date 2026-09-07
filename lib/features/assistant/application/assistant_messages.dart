part of 'assistant_notifier.dart';

extension _AssistantMessages on AssistantNotifier {
  List<AssistantMessage> _questionMessages(AssistantQuestionRequest question) {
    final id = jsonInt64Id(question.messageId);
    final existing = _value.messages
        .where((message) => message.questionRequest?.id == question.id)
        .firstOrNull;
    if (existing?.questionRequest?.status != 'pending' &&
        existing?.questionRequest != null &&
        question.isPending) {
      return _value.messages;
    }
    if (existing != null) {
      return [
        for (final message in _value.messages)
          if (message.questionRequest?.id == question.id)
            message.copyWith(questionRequest: question)
          else
            message,
      ];
    }
    return [
      ..._value.messages,
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

  List<AssistantMessage> _answerMessages(
    String responseId,
    AssistantAnswerPresentation answer,
    String text,
  ) {
    final messageId = jsonInt64Id(answer.messageId);
    final persisted = _value.messages
        .where((message) => message.id == messageId)
        .firstOrNull;
    final existing =
        persisted ??
        _value.messages
            .where((message) => message.id == responseId)
            .firstOrNull;
    final result = [
      for (final message in _value.messages)
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

  List<AssistantMessage> _ensureAssistant(String id, Object runId) {
    if (_exactMessageIndex(_value.messages, id) >= 0 ||
        _hasPersistedTerminalResponseForRun(_value.messages, runId)) {
      return _value.messages;
    }
    return [
      ..._value.messages,
      AssistantMessage(
        id: id,
        runId: runId,
        role: AssistantMessageRole.assistant,
        text: '',
        isStreaming: true,
      ),
    ];
  }

  List<AssistantMessage> _upsertTool(
    String responseId,
    Object runId,
    AssistantToolCall call,
    AssistantToolStatus status,
  ) {
    return _updateResponseMessage(
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

  List<AssistantMessage> _setToolStatus(
    Object runId,
    String callId, {
    required Set<AssistantToolStatus> from,
    required AssistantToolStatus to,
  }) {
    return _updateResponseMessage(
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

  List<AssistantMessage> _updateMemoryChange(
    Object changeId,
    AssistantMessage Function(AssistantMessage) update,
  ) {
    return [
      for (final message in _value.messages)
        if (message.isMemoryChanged &&
            jsonInt64Id(message.changeId) == jsonInt64Id(changeId))
          update(message)
        else
          message,
    ];
  }

  List<AssistantMessage> _upsertMemoryChangedEvent(
    Object runId,
    AssistantRunEvent event,
  ) {
    if (jsonInt64IsPositive(event.changeId) &&
        _value.messages.any(
          (message) =>
              message.isMemoryChanged &&
              _sameRun(message.changeId, event.changeId),
        )) {
      return _value.messages;
    }
    return [
      ..._value.messages,
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

  List<AssistantMessage> _clearResetResponse(String responseId, Object runId) {
    return _updateResponseMessage(
      responseId,
      runId,
      (message) => message.copyWith(text: ''),
      createIfMissing: true,
    );
  }

  List<AssistantMessage> _updateResponseMessage(
    String id,
    Object runId,
    AssistantMessage Function(AssistantMessage) update, {
    bool createIfMissing = false,
    bool matchPersistedTerminal = false,
  }) {
    final messages = [..._value.messages];
    var index = _exactMessageIndex(messages, id);
    if (index < 0 && matchPersistedTerminal) {
      index = _persistedTerminalResponseIndex(messages, runId);
    }
    if (index >= 0) {
      messages[index] = update(messages[index]);
      return messages;
    }
    if (!createIfMissing ||
        _hasPersistedTerminalResponseForRun(messages, runId)) {
      return messages;
    }
    messages.add(
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
    return messages;
  }
}
