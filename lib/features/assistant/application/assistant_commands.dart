part of 'assistant_notifier.dart';

extension _AssistantCommands on AssistantNotifier {
  Future<bool> _sendCommand(String message, {Object contextPostId = 0}) async {
    final normalized = message.trim();
    if (_identityKey.isEmpty ||
        normalized.isEmpty ||
        normalized.length > 2000 ||
        _value.isSending ||
        _value.isLoadingHistory) {
      return false;
    }

    final pending = _value.pendingRetryCommand;
    if (pending != null &&
        pending.matches(normalized, contextPostId) &&
        _value.pendingAttachments.isEmpty) {
      return _submit(pending, addOptimisticMessage: false);
    }
    final command = PendingAssistantCommand(
      message: normalized,
      requestId: _createRequestId(),
      attachments: [..._value.pendingAttachments],
      contextPostId: contextPostId,
    );
    return _submit(command, addOptimisticMessage: true);
  }

  Future<bool> _submit(
    PendingAssistantCommand command, {
    required bool addOptimisticMessage,
  }) async {
    if (_identityKey.isEmpty || _value.isSending || _value.isLoadingHistory) {
      return false;
    }
    final optimisticId = 'user-${command.requestId}';
    final messages =
        addOptimisticMessage &&
            !_value.messages.any((item) => item.id == optimisticId)
        ? [
            ..._value.messages,
            AssistantMessage(
              id: optimisticId,
              role: AssistantMessageRole.user,
              text: command.message,
              attachments: command.attachments,
            ),
          ]
        : _value.messages;
    _value = _value.copyWith(
      messages: messages,
      isSending: true,
      pendingRetryCommand: command,
      clearConnectionError: true,
      clearPendingAttachments: addOptimisticMessage,
      clearAgentAuthorizationRequired: true,
    );

    try {
      final accepted = await _repository.postMessage(
        message: command.message,
        requestId: command.requestId,
        attachments: [
          for (final item in command.attachments)
            AssistantAttachment(mediaId: item.mediaId, url: item.url),
        ],
        contextPostId: command.contextPostId,
      );
      if (!mounted) return false;
      final acceptedMessageId = jsonInt64Id(accepted.messageId);
      final hasAcceptedMessageId = jsonInt64IsPositive(accepted.messageId);
      final sessionChanged = !_sameRun(accepted.sessionId, _value.sessionId);
      if (sessionChanged) {
        ++_refreshGeneration;
        ++_olderGeneration;
        _lastMessageId = 0;
      }
      if (sessionChanged || !_sameRun(accepted.runId, _value.activeRunId)) {
        _activeRunFloorMessageId = 0;
      }
      _advanceActiveRunFloor(accepted.messageId);
      final userMessages = hasAcceptedMessageId
          ? _reconcileAcceptedUserMessage(
              _value.messages,
              optimisticId: optimisticId,
              acceptedMessageId: acceptedMessageId,
              acceptedRunId: accepted.runId,
            )
          : [..._value.messages];
      final queued = accepted.disposition == AssistantDisposition.queued;
      final persistedResponse = _hasPersistedTerminalResponseForRun(
        userMessages,
        accepted.runId,
      );
      final terminalResponse =
          persistedResponse ||
          _hasTerminalEventResponseForRun(userMessages, accepted.runId);
      final shouldStream =
          !terminalResponse &&
          (accepted.disposition == AssistantDisposition.started ||
              accepted.disposition == AssistantDisposition.redirected ||
              accepted.disposition == AssistantDisposition.steered ||
              queued);
      final responseId = 'run-${jsonInt64Id(accepted.runId)}';
      final nextMessages = queued || terminalResponse
          ? userMessages
          : _ensureAssistantIn(userMessages, responseId, accepted.runId);
      _value = _value.copyWith(
        sessionId: accepted.sessionId,
        activeRunId: accepted.runId,
        clearActiveRun: terminalResponse,
        lastDisposition: accepted.disposition,
        clearLastDisposition: terminalResponse,
        messages: nextMessages,
        isSending: false,
        isStreaming: shouldStream,
        isQueued: queued && !terminalResponse,
        hasMoreHistory: sessionChanged ? false : _value.hasMoreHistory,
        nextBeforeId: sessionChanged ? 0 : _value.nextBeforeId,
        isLoadingOlder: sessionChanged ? false : _value.isLoadingOlder,
        activeRunPhase: terminalResponse
            ? ''
            : switch (accepted.disposition) {
                AssistantDisposition.queued => 'queued',
                AssistantDisposition.steered => 'tool_executing',
                AssistantDisposition.redirected ||
                AssistantDisposition.started => 'model_request',
                _ => _value.activeRunPhase,
              },
        clearPendingRetryCommand: true,
        clearHistoryError: sessionChanged,
      );
      _activeCommand = terminalResponse ? null : command;
      if (terminalResponse) _activeRunFloorMessageId = 0;
      if (!shouldStream &&
          _subscription != null &&
          !_sameRun(_subscribedRunId, accepted.runId)) {
        await _cancelSubscription();
        if (!mounted) return false;
      }
      if (shouldStream && jsonInt64IsPositive(accepted.runId)) {
        _ensureSubscribed(accepted.runId);
      }
      return true;
    } on ApiException catch (error) {
      if (!mounted) return false;
      final unauthorized = error.message.contains('AGENT_NOT_AUTHORIZED');
      _value = _value.copyWith(
        isSending: false,
        agentAuthorizationRequired: unauthorized,
        connectionError: friendlyErrorMessage(error),
        pendingRetryCommand: command,
      );
      return false;
    } catch (error) {
      if (!mounted) return false;
      _value = _value.copyWith(
        isSending: false,
        connectionError: friendlyErrorMessage(error),
        pendingRetryCommand: command,
      );
      return false;
    }
  }

  Future<bool> _retryPendingCommand() async {
    final pending = _value.pendingRetryCommand;
    if (pending == null) return false;
    return _submit(pending, addOptimisticMessage: false);
  }

  Future<bool> _answerQuestionCommand(
    AssistantQuestionRequest question,
    List<AssistantQuestionAnswer> answers, {
    bool continueExpired = false,
  }) async {
    if (_identityKey.isEmpty || _value.isSending || _value.isLoadingHistory) {
      return false;
    }
    if (continueExpired && _value.hasActiveRun) {
      _value = _value.copyWith(connectionError: '当前任务结束后再继续此问题');
      return false;
    }
    final fingerprint = jsonEncode([
      question.id,
      continueExpired,
      [for (final answer in answers) answer.toJson()],
    ]);
    final requestId = _questionRequestIds.putIfAbsent(
      fingerprint,
      _createRequestId,
    );
    _value = _value.copyWith(isSending: true, clearConnectionError: true);
    try {
      if (continueExpired) {
        await _repository.continueQuestions(
          question: question,
          requestId: requestId,
          answers: answers,
        );
        if (!mounted) return false;
        _value = _value.copyWith(isSending: false);
        await load();
      } else {
        final updated = await _repository.answerQuestions(
          question: question,
          requestId: requestId,
          answers: answers,
        );
        if (!mounted) return false;
        if (_hasPersistedTerminalResponseForRun(
              _value.messages,
              question.runId,
            ) ||
            _hasTerminalEventResponseForRun(_value.messages, question.runId)) {
          _value = _value.copyWith(
            messages: _questionMessages(updated),
            isSending: false,
          );
          _questionRequestIds.remove(fingerprint);
          return true;
        }
        _value = _value.copyWith(
          messages: _ensureAssistantIn(
            _questionMessages(updated),
            'run-${jsonInt64Id(question.runId)}',
            question.runId,
          ),
          isSending: false,
          isStreaming: true,
          activeRunId: question.runId,
          activeRunPhase: 'queued',
        );
        _ensureSubscribed(question.runId);
      }
      _questionRequestIds.remove(fingerprint);
      return true;
    } catch (error) {
      if (!mounted) return false;
      _value = _value.copyWith(
        isSending: false,
        connectionError: friendlyErrorMessage(error),
      );
      return false;
    }
  }

  Future<bool> _respondToConfirmationCommand(
    String callId,
    bool approved,
  ) async {
    final runId = _value.activeRunId;
    if (!jsonInt64IsPositive(runId)) return false;
    var changed = false;
    _value = _value.copyWith(
      messages: _updateResponseMessage(
        'run-${jsonInt64Id(runId)}',
        runId,
        (message) => message.copyWith(
          toolSteps: [
            for (final step in message.toolSteps)
              if (step.callId == callId &&
                  step.status == AssistantToolStatus.awaitingConfirmation)
                (() {
                  changed = true;
                  return step.copyWith(status: AssistantToolStatus.confirming);
                })()
              else
                step,
          ],
        ),
      ),
    );
    if (!changed) return false;
    try {
      await _repository.confirmRun(
        runId: runId,
        callId: callId,
        approved: approved,
      );
      if (!mounted || !_sameRun(_value.activeRunId, runId)) return false;
      _value = _value.copyWith(
        messages: _setToolStatus(
          runId,
          callId,
          from: const {AssistantToolStatus.confirming},
          to: approved
              ? AssistantToolStatus.confirmed
              : AssistantToolStatus.declined,
        ),
        clearConnectionError: true,
      );
      return true;
    } catch (error) {
      if (!mounted || !_sameRun(_value.activeRunId, runId)) return false;
      _value = _value.copyWith(
        messages: _setToolStatus(
          runId,
          callId,
          from: const {AssistantToolStatus.confirming},
          to: AssistantToolStatus.awaitingConfirmation,
        ),
        connectionError: friendlyErrorMessage(error),
      );
      return false;
    }
  }

  Future<bool> _stopCommand() async {
    if (!_value.hasActiveRun && !_value.isStreaming) return true;
    final runId = _value.activeRunId;
    if (!jsonInt64IsPositive(runId)) return false;
    try {
      await _repository.cancelRun(runId);
    } catch (error) {
      if (!mounted || !_sameRun(_value.activeRunId, runId)) return false;
      _value = _value.copyWith(connectionError: friendlyErrorMessage(error));
      return false;
    }
    if (!mounted || !_sameRun(_value.activeRunId, runId)) return true;
    await _cancelSubscription();
    if (!mounted || !_sameRun(_value.activeRunId, runId)) return true;
    _activeCommand = null;
    _activeRunFloorMessageId = 0;
    final responseId = 'run-${jsonInt64Id(runId)}';
    _value = _value.copyWith(
      messages: _updateResponseMessage(
        responseId,
        runId,
        (message) => message.copyWith(
          text: message.text.isEmpty ? '已取消' : message.text,
          isStreaming: false,
          isCanceled: true,
          terminalEventReceived: true,
        ),
        createIfMissing: true,
        matchPersistedTerminal: true,
      ),
      isStreaming: false,
      isQueued: false,
      clearActiveRun: true,
      clearLastDisposition: true,
      clearConnectionError: true,
    );
    return true;
  }

  Future<void> _clearHistoryCommand() async {
    if (_value.isSending || _value.isLoadingHistory) return;
    _loadGeneration++;
    _refreshGeneration++;
    _olderGeneration++;
    _value = _value.copyWith(isLoadingHistory: true, isLoadingOlder: false);
    final stopped = await stop();
    if (!mounted) return;
    if (!stopped) {
      _value = _value.copyWith(isLoadingHistory: false);
      return;
    }
    try {
      await _repository.deleteHistory();
      if (!mounted) return;
      _value = AssistantState(
        pendingAttachments: _value.pendingAttachments,
        isLoaded: true,
      );
      _lastMessageId = 0;
      _activeRunFloorMessageId = 0;
    } catch (error) {
      if (!mounted) return;
      _value = _value.copyWith(
        connectionError: friendlyErrorMessage(error),
        isLoaded: true,
        isLoadingHistory: false,
      );
    }
  }

  Future<bool> _undoMemoryChangeCommand(Object changeId) async {
    if (!jsonInt64IsPositive(changeId)) return false;
    _value = _value.copyWith(
      messages: _updateMemoryChange(
        changeId,
        (message) => message.copyWith(memoryUndoing: true),
      ),
      clearConnectionError: true,
    );
    try {
      await _repository.undoMemoryChange(changeId);
      if (!mounted) return false;
      _value = _value.copyWith(
        messages: _updateMemoryChange(
          changeId,
          (message) =>
              message.copyWith(memoryUndoing: false, memoryUndone: true),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      _value = _value.copyWith(
        messages: _updateMemoryChange(
          changeId,
          (message) => message.copyWith(memoryUndoing: false),
        ),
        connectionError: friendlyErrorMessage(error),
      );
      return false;
    }
  }
}
