part of 'assistant_notifier.dart';

// 用户触发的命令：发送/重试、答题、工具确认、停止、清空历史与撤销记忆变更。
extension _AssistantCommands on AssistantNotifier {
  // 校验后决定复用失败的待重试命令（同文本、同上下文且没有新附件）还是新建命令。
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

  // 提交命令：乐观插入用户消息，受理后按处置结果对账并决定是否订阅事件流；
  // 失败时保留为待重试命令。
  Future<bool> _submit(
    PendingAssistantCommand command, {
    required bool addOptimisticMessage,
  }) async {
    if (_identityKey.isEmpty || _value.isSending || _value.isLoadingHistory) {
      return false;
    }
    // 乐观更新：以 user-<requestId> 占位，重试同一命令时不重复插入。
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
      // 会话切换时作废在途的增量刷新与翻页，并重置消息游标与 run 下限。
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
      // 把乐观消息换成服务端 ID 并按 ID 顺序就位。
      final userMessages = hasAcceptedMessageId
          ? _reconcileAcceptedUserMessage(
              _value.messages,
              optimisticId: optimisticId,
              acceptedMessageId: acceptedMessageId,
              acceptedRunId: accepted.runId,
            )
          : [..._value.messages];
      // 历史已带回该 run 的终态回复时不再跟随；否则按处置决定是否流式订阅。
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
      // 排队的消息暂不建回复占位，等 run_started 再建。
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
      // 不再流式时，断开仍在跟随其他 run 的旧订阅。
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
      // 失败：保留命令供重试；Agent 未授权时提示用户先授权。
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

  // 原样重发待重试命令：沿用 requestId，不再插入乐观消息。
  Future<bool> _retryPendingCommand() async {
    final pending = _value.pendingRetryCommand;
    if (pending == null) return false;
    return _submit(pending, addOptimisticMessage: false);
  }

  // 提交提问卡答案：过期问题以新消息续答并重载历史；未过期则回到排队阶段并
  // 订阅该 run。
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
    // 幂等：同一问题、同一答案在成功前的重试都使用同一个 requestId。
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
        // run 已有终态回复：只更新提问卡，不再订阅。
        if (_hasPersistedTerminalResponseForRun(
              _value.messages,
              question.runId,
            ) ||
            _hasTerminalEventResponseForRun(_value.messages, question.runId)) {
          _value = _value.copyWith(
            messages: _questionMessages(_value.messages, updated),
            isSending: false,
          );
          _questionRequestIds.remove(fingerprint);
          return true;
        }
        _value = _value.copyWith(
          messages: _ensureAssistantIn(
            _questionMessages(_value.messages, updated),
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

  // 工具确认：先乐观置为 confirming，成功落为 confirmed/declined，失败回滚为
  // 待确认；期间 run 已切换则丢弃结果。
  Future<bool> _respondToConfirmationCommand(
    String callId,
    bool approved,
  ) async {
    final runId = _value.activeRunId;
    if (!jsonInt64IsPositive(runId)) return false;
    var changed = false;
    _value = _value.copyWith(
      messages: _updateResponseMessage(
        _value.messages,
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
          _value.messages,
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
          _value.messages,
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

  // 停止活跃 run：取消请求成功后断开订阅，把回复标为已取消并结算未完成的工具步骤。
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
        _value.messages,
        responseId,
        runId,
        (message) => message.copyWith(
          text: message.text.isEmpty ? '已取消' : message.text,
          isStreaming: false,
          isCanceled: true,
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
      clearActiveRun: true,
      clearLastDisposition: true,
      clearConnectionError: true,
    );
    return true;
  }

  // 清空历史：先作废在途加载并停止 run，停止失败则放弃删除；成功后重置为空会话，
  // 只保留待发附件。
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

  // 撤销记忆变更：提示上先显示撤销中，成功标为已撤销，失败恢复并报错。
  Future<bool> _undoMemoryChangeCommand(Object changeId) async {
    if (!jsonInt64IsPositive(changeId)) return false;
    _value = _value.copyWith(
      messages: _updateMemoryChange(
        _value.messages,
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
          _value.messages,
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
          _value.messages,
          changeId,
          (message) => message.copyWith(memoryUndoing: false),
        ),
        connectionError: friendlyErrorMessage(error),
      );
      return false;
    }
  }
}
