part of 'assistant_notifier.dart';

extension _AssistantConnection on AssistantNotifier {
  bool _reconnectRun() {
    final runId = _value.activeRunId;
    if (_identityKey.isEmpty ||
        !mounted ||
        !jsonInt64IsPositive(runId) ||
        _subscription != null ||
        _hasPersistedTerminalResponseForRun(_value.messages, runId)) {
      return false;
    }
    _value = _value.copyWith(isStreaming: true);
    _ensureSubscribed(runId);
    return true;
  }

  void _ensureSubscribed(Object runId) {
    if (_sameRun(_subscribedRunId, runId) && _subscription != null) return;
    _subscribe(
      runId,
      afterSeq: _sameRun(_subscribedRunId, runId) ? _lastSeq : 0,
    );
  }

  void _subscribe(Object runId, {required Object afterSeq}) {
    _waitingReconnect?.cancel();
    if (!_sameRun(_subscribedRunId, runId)) {
      _resetStreamTracking();
    }
    _generation++;
    final generation = _generation;
    _connectionGeneration++;
    _lastSeq = _asInt(afterSeq);
    _reconnects = 0;
    final previous = _subscription;
    _subscription = null;
    _subscribedRunId = runId;
    unawaited(previous?.cancel());
    _listen(runId, generation);
  }

  void _listen(Object runId, int generation) {
    final connectionGeneration = ++_connectionGeneration;
    final stream = _repository.runEvents(runId: runId, afterSeq: _lastSeq);
    _subscription = stream.listen(
      (event) {
        if (!_isCurrentConnection(generation, connectionGeneration)) return;
        if (event.seq > 0 && event.seq <= _lastSeq) return;
        if (event.seq > _lastSeq) _lastSeq = event.seq;
        _applyEvent(runId, event);
        if (event.isTerminal &&
            _isCurrentConnection(generation, connectionGeneration)) {
          final terminalSubscription = _subscription;
          _subscription = null;
          _subscribedRunId = 0;
          _connectionGeneration++;
          unawaited(terminalSubscription?.cancel());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_isCurrentConnection(generation, connectionGeneration)) return;
        if (error is AssistantStreamException &&
            error.retryable &&
            _value.activeRunPhase == 'waiting_input') {
          _scheduleWaitingReconnect(runId, generation);
          return;
        }
        if (error is AssistantStreamException &&
            error.retryable &&
            _value.hasActiveRun &&
            _reconnects < 1) {
          _reconnects++;
          final previous = _subscription;
          _subscription = null;
          _listen(runId, generation);
          unawaited(previous?.cancel());
          return;
        }
        _finishWithTransportError(
          friendlyErrorMessage(error),
          runId,
          generation,
          connectionGeneration,
        );
      },
      onDone: () {
        if (_isCurrentConnection(generation, connectionGeneration) &&
            _value.activeRunPhase == 'waiting_input') {
          _scheduleWaitingReconnect(runId, generation);
          return;
        }
        if (!_isCurrentConnection(generation, connectionGeneration) ||
            !_value.isStreaming) {
          return;
        }
        if (_value.hasActiveRun && _reconnects < 1) {
          _reconnects++;
          _listen(runId, generation);
          return;
        }
        _finishWithTransportError(
          'Assistant 连接意外中断',
          runId,
          generation,
          connectionGeneration,
        );
      },
      cancelOnError: false,
    );
  }

  bool _isCurrentConnection(int generation, int connectionGeneration) {
    return mounted &&
        generation == _generation &&
        connectionGeneration == _connectionGeneration;
  }

  void _scheduleWaitingReconnect(Object runId, int generation) {
    final ticket = ++_connectionGeneration;
    final previous = _subscription;
    _subscription = null;
    unawaited(previous?.cancel());
    _waitingReconnect?.cancel();
    _waitingReconnect = Timer(const Duration(seconds: 2), () {
      if (_isCurrentConnection(generation, ticket) &&
          _value.hasActiveRun &&
          _value.activeRunPhase == 'waiting_input') {
        _listen(runId, generation);
      }
    });
  }

  void _applyEvent(Object runId, AssistantRunEvent event) {
    if (!_acceptEvent(event)) return;
    final sessionId = jsonInt64IsPositive(event.sessionId)
        ? event.sessionId
        : _value.sessionId;
    final responseId = 'run-${jsonInt64Id(runId)}';
    _clearRecoveredTransportError(responseId, runId, event.isTerminal);
    switch (event.type) {
      case AssistantEventType.runStarted:
        _value = _value.copyWith(
          sessionId: sessionId,
          activeRunId: runId,
          activeRunPhase: 'model_request',
          clearLastDisposition: true,
          isQueued: false,
          isStreaming: true,
          messages: _ensureAssistant(responseId, runId),
        );
      case AssistantEventType.token:
        _value = _value.copyWith(
          sessionId: sessionId,
          activeRunPhase: 'model_request',
          clearLastDisposition: true,
          messages: _updateResponseMessage(
            responseId,
            runId,
            (message) => message.copyWith(text: '${message.text}${event.text}'),
            createIfMissing: true,
          ),
          isStreaming: true,
          isQueued: false,
        );
      case AssistantEventType.responseReset:
        _value = _value.copyWith(
          sessionId: sessionId,
          clearLastDisposition: true,
          messages: _clearResetResponse(responseId, runId),
          isStreaming: true,
          isQueued: false,
        );
      case AssistantEventType.toolCall:
        _value = _value.copyWith(
          sessionId: sessionId,
          activeRunPhase: 'tool_executing',
          clearLastDisposition: true,
          messages: _upsertTool(
            responseId,
            runId,
            event.toolCall!,
            AssistantToolStatus.running,
          ),
        );
      case AssistantEventType.toolResult:
        _value = _value.copyWith(
          sessionId: sessionId,
          messages: _upsertTool(
            responseId,
            runId,
            event.toolCall!,
            AssistantToolStatus.completed,
          ),
        );
      case AssistantEventType.confirmRequired:
        _value = _value.copyWith(
          sessionId: sessionId,
          messages: _upsertTool(
            responseId,
            runId,
            event.toolCall!,
            AssistantToolStatus.awaitingConfirmation,
          ),
        );
      case AssistantEventType.sourceCard:
        _value = _value.copyWith(
          sessionId: sessionId,
          messages: _updateResponseMessage(
            responseId,
            runId,
            (message) {
              final source = event.sourceCard!;
              return message.sources.contains(source)
                  ? message
                  : message.copyWith(sources: [...message.sources, source]);
            },
            createIfMissing: true,
            matchPersistedTerminal: true,
          ),
        );
      case AssistantEventType.memoryChanged:
        _value = _value.copyWith(
          sessionId: sessionId,
          messages: _upsertMemoryChangedEvent(runId, event),
        );
      case AssistantEventType.questionsRequired:
      case AssistantEventType.questionsResolved:
        final question = event.questionRequest;
        if (question == null || !_sameRun(question.runId, runId)) return;
        var messages = _questionMessages(question);
        final resumes =
            question.status == 'answered' || question.status == 'superseded';
        if (question.isPending) {
          messages = [
            for (final message in messages)
              if (!(message.id == responseId &&
                  message.text.isEmpty &&
                  message.sources.isEmpty &&
                  message.toolSteps.every(
                    (step) => step.tool == 'ask_questions',
                  )))
                message.id == responseId
                    ? message.copyWith(isStreaming: false)
                    : message,
          ];
        } else if (resumes) {
          messages = _ensureAssistantIn(messages, responseId, runId);
        }
        _value = _value.copyWith(
          sessionId: sessionId,
          messages: messages,
          isStreaming: resumes,
          activeRunPhase: resumes ? 'queued' : 'waiting_input',
        );
      case AssistantEventType.answerCommitted:
        final answer = event.answerPresentation;
        if (answer == null || !_sameRun(answer.runId, runId)) return;
        _resetStreamTracking();
        _value = _value.copyWith(
          sessionId: sessionId,
          messages: _answerMessages(responseId, answer, event.text),
        );
      case AssistantEventType.unknown:
        return;
      case AssistantEventType.done:
        _resetStreamTracking();
        _activeCommand = null;
        _activeRunFloorMessageId = 0;
        _value = _value.copyWith(
          sessionId: sessionId,
          messages: _updateResponseMessage(
            responseId,
            runId,
            (message) => message.copyWith(
              isStreaming: false,
              degraded: event.degraded,
              terminalEventReceived: true,
              toolSteps: _settleSteps(
                message.toolSteps,
                AssistantToolStatus.completed,
              ),
            ),
            createIfMissing: true,
            matchPersistedTerminal: true,
          ),
          isStreaming: false,
          isQueued: false,
          clearConnectionError: _value.pendingRetryCommand == null,
          clearActiveRun: true,
          clearLastDisposition: true,
        );
      case AssistantEventType.error:
        _resetStreamTracking();
        final needsAuthorization = event.errorCode == 'AGENT_NOT_AUTHORIZED';
        final retryCommand = needsAuthorization ? _activeCommand : null;
        _activeCommand = null;
        _activeRunFloorMessageId = 0;
        _value = _value.copyWith(
          sessionId: sessionId,
          agentAuthorizationRequired: needsAuthorization,
          messages: _updateResponseMessage(
            responseId,
            runId,
            (message) => message.copyWith(
              text: message.text.isEmpty ? event.text : message.text,
              isStreaming: false,
              degraded: true,
              errorCode: event.errorCode,
              terminalEventReceived: true,
              toolSteps: _settleSteps(
                message.toolSteps,
                AssistantToolStatus.failed,
              ),
            ),
            createIfMissing: true,
            matchPersistedTerminal: true,
          ),
          isStreaming: false,
          isQueued: false,
          connectionError: event.text,
          pendingRetryCommand: retryCommand,
          clearActiveRun: true,
          clearLastDisposition: true,
        );
    }
  }

  bool _acceptEvent(AssistantRunEvent event) {
    return switch (event.type) {
      AssistantEventType.token => _acceptToken(event),
      AssistantEventType.responseReset => _acceptReset(event),
      AssistantEventType.sourceCard => event.sourceCard != null,
      AssistantEventType.unknown => false,
      _ => true,
    };
  }

  void _clearRecoveredTransportError(
    String responseId,
    Object runId,
    bool terminal,
  ) {
    var recovered = false;
    final messages = _updateResponseMessage(responseId, runId, (message) {
      if (message.errorCode != 'STREAM_DISCONNECTED') return message;
      recovered = true;
      return message.copyWith(
        text: message.text == '响应中断' ? '' : message.text,
        isStreaming: !terminal,
        degraded: false,
        errorCode: '',
      );
    }, matchPersistedTerminal: true);
    if (recovered) {
      _value = _value.copyWith(messages: messages, clearConnectionError: true);
    }
  }

  bool _acceptToken(AssistantRunEvent event) {
    final streamId = event.streamId.trim();
    if (streamId.isEmpty) {
      return !_usesStreamIds;
    }
    _usesStreamIds = true;
    if (_retiredStreamIds.contains(streamId)) return false;
    if (_activeStreamId.isEmpty) {
      _activeStreamId = streamId;
      return true;
    }
    return _activeStreamId == streamId;
  }

  bool _acceptReset(AssistantRunEvent event) {
    final streamId = event.streamId.trim();
    if (streamId.isEmpty || _activeStreamId != streamId) return false;
    _retiredStreamIds.add(streamId);
    _activeStreamId = '';
    _usesStreamIds = true;
    return true;
  }

  void _resetStreamTracking() {
    _activeStreamId = '';
    _retiredStreamIds.clear();
    _usesStreamIds = false;
  }

  void _finishWithTransportError(
    String error,
    Object runId,
    int generation,
    int connectionGeneration,
  ) {
    if (!_isCurrentConnection(generation, connectionGeneration)) return;
    final subscription = _subscription;
    _subscription = null;
    _connectionGeneration++;
    unawaited(subscription?.cancel());
    if (_hasPersistedTerminalResponseForRun(_value.messages, runId)) {
      _subscribedRunId = 0;
      _resetStreamTracking();
      _activeCommand = null;
      _activeRunFloorMessageId = 0;
      _value = _value.copyWith(
        isStreaming: false,
        isQueued: false,
        clearActiveRun: true,
        clearLastDisposition: true,
        clearConnectionError: _value.pendingRetryCommand == null,
      );
      return;
    }
    final responseId = 'run-${jsonInt64Id(runId)}';
    _value = _value.copyWith(
      messages: _updateResponseMessage(
        responseId,
        runId,
        (message) => message.copyWith(
          text: message.text.isEmpty ? '响应中断' : message.text,
          isStreaming: false,
          degraded: true,
          errorCode: 'STREAM_DISCONNECTED',
        ),
        createIfMissing: true,
        matchPersistedTerminal: true,
      ),
      isStreaming: false,
      connectionError: error,
    );
  }

  Future<void> _cancelSubscription() async {
    _waitingReconnect?.cancel();
    _generation++;
    _connectionGeneration++;
    _subscribedRunId = 0;
    _resetStreamTracking();
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
