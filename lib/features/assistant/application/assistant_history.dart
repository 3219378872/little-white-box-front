part of 'assistant_notifier.dart';

extension _AssistantHistory on AssistantNotifier {
  Future<void> _loadHistory() async {
    if (_identityKey.isEmpty || _value.isSending || _value.isLoadingHistory) {
      return;
    }
    final generation = ++_loadGeneration;
    ++_refreshGeneration;
    ++_olderGeneration;
    _value = _value.copyWith(
      isLoadingHistory: true,
      isLoadingOlder: false,
      clearConnectionError: _value.messages.isEmpty,
    );
    try {
      final thread = await _repository.getThread();
      if (!mounted || generation != _loadGeneration) return;
      if (_value.isLoaded && !_sameRun(thread.sessionId, _value.sessionId)) {
        await _cancelSubscription();
        if (!mounted || generation != _loadGeneration) return;
      }
      final page = await _repository.listMessages(sessionId: thread.sessionId);
      if (!mounted || generation != _loadGeneration) return;
      final history = page.messages;
      _lastMessageId = history.isEmpty ? 0 : history.last.id;
      final loadedMessages = [for (final item in history) _fromHistory(item)];
      final resumeRun =
          thread.hasActiveRun &&
          !_hasPersistedTerminalResponseForRun(
            loadedMessages,
            thread.activeRunId,
          );
      if (!resumeRun || !_sameRun(thread.activeRunId, _value.activeRunId)) {
        _activeCommand = null;
      }
      _activeRunFloorMessageId = resumeRun ? thread.lastMessageId : 0;
      if (resumeRun && history.isNotEmpty) {
        _advanceActiveRunFloor(history.last.id);
      }
      if (!resumeRun) {
        await _cancelSubscription();
        if (!mounted || generation != _loadGeneration) return;
      }
      _value = _value.copyWith(
        sessionId: thread.sessionId,
        activeRunId: resumeRun ? thread.activeRunId : 0,
        activeRunPhase: resumeRun ? thread.activeRunPhase : '',
        clearLastDisposition: true,
        messages: resumeRun
            ? _ensureAssistantIn(
                loadedMessages,
                'run-${jsonInt64Id(thread.activeRunId)}',
                thread.activeRunId,
              )
            : loadedMessages,
        isStreaming: resumeRun,
        isQueued: resumeRun && thread.activeRunPhase == 'queued',
        clearConnectionError: true,
        isLoaded: true,
        isLoadingHistory: false,
        hasMoreHistory: page.hasMore,
        nextBeforeId: page.nextBeforeId,
        isLoadingOlder: false,
        clearHistoryError: true,
      );
      if (resumeRun) {
        _subscribe(thread.activeRunId, afterSeq: 0);
      }
      unawaited(_markRead());
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      _value = _value.copyWith(
        connectionError: friendlyErrorMessage(error),
        isLoaded: true,
        isLoadingHistory: false,
      );
    }
  }

  Future<bool> _refreshThread(AssistantThreadSummary thread) async {
    if (_identityKey.isEmpty || !_value.isLoaded || _value.isLoadingHistory) {
      return false;
    }
    if (jsonInt64IsPositive(thread.sessionId) &&
        !_sameRun(thread.sessionId, _value.sessionId)) {
      if (_value.isSending) return false;
      await load();
      return mounted && _value.connectionError == null;
    }
    if (thread.hasActiveRun &&
        !_sameRun(thread.activeRunId, _value.activeRunId)) {
      if (_value.isSending) return false;
      await load();
      return mounted && _value.connectionError == null;
    }
    final observedRunId = _value.activeRunId;
    var changed = false;
    if (thread.hasActiveRun && _sameRun(thread.activeRunId, observedRunId)) {
      final phase = thread.activeRunPhase.trim();
      final queuedConsumed =
          phase == 'model_request' || phase == 'tool_executing';
      final preserveQueued =
          (_value.isQueued ||
              _value.lastDisposition == AssistantDisposition.queued) &&
          !queuedConsumed;
      if ((phase.isNotEmpty && phase != _value.activeRunPhase) ||
          preserveQueued != _value.isQueued) {
        final hasLiveSubscription =
            _subscription != null && _sameRun(_subscribedRunId, observedRunId);
        _value = _value.copyWith(
          activeRunPhase: phase.isEmpty ? null : phase,
          isQueued: preserveQueued,
          isStreaming: hasLiveSubscription,
          clearLastDisposition:
              _value.lastDisposition != AssistantDisposition.queued ||
              !preserveQueued,
        );
        changed = true;
      }
      if (_subscription == null && reconnectActiveRun()) changed = true;
    }
    final needsMessageRefresh =
        jsonInt64IsPositive(thread.lastMessageId) &&
        _idIsAfter(thread.lastMessageId, _lastMessageId);
    if (needsMessageRefresh) {
      final refreshed = await refreshMessages();
      if (!refreshed) return changed;
      changed = true;
    }
    if (!mounted || !_sameRun(thread.sessionId, _value.sessionId)) {
      return changed;
    }
    return await _settleRunFromThread(thread, observedRunId) || changed;
  }

  Future<bool> _loadOlderHistory() async {
    if (_identityKey.isEmpty ||
        _value.isLoadingHistory ||
        _value.isLoadingOlder ||
        !_value.hasMoreHistory ||
        !jsonInt64IsPositive(_value.nextBeforeId) ||
        !jsonInt64IsPositive(_value.sessionId)) {
      return false;
    }
    final generation = ++_olderGeneration;
    final sessionId = _value.sessionId;
    final beforeId = _value.nextBeforeId;
    _value = _value.copyWith(isLoadingOlder: true, clearHistoryError: true);
    try {
      final page = await _repository.listMessages(
        sessionId: sessionId,
        beforeId: beforeId,
      );
      if (!mounted || generation != _olderGeneration) return false;
      if (!_sameRun(_value.sessionId, sessionId)) {
        _value = _value.copyWith(isLoadingOlder: false);
        return false;
      }
      final existingIds = {for (final item in _value.messages) item.id};
      final older = [
        for (final item in page.messages)
          if (!existingIds.contains(jsonInt64Id(item.id))) _fromHistory(item),
      ];
      _value = _value.copyWith(
        messages: [...older, ..._value.messages],
        hasMoreHistory: page.hasMore,
        nextBeforeId: page.nextBeforeId,
        isLoadingOlder: false,
        clearHistoryError: true,
      );
      return true;
    } catch (error) {
      if (!mounted || generation != _olderGeneration) return false;
      _value = _value.copyWith(
        isLoadingOlder: false,
        historyError: friendlyErrorMessage(error),
      );
      return false;
    }
  }

  Future<bool> _refreshHistory() {
    if (_identityKey.isEmpty ||
        _value.isLoadingHistory ||
        !jsonInt64IsPositive(_value.sessionId)) {
      return Future.value(false);
    }
    _refreshRequested = true;
    return _refreshFuture ??= _drainMessageRefreshes();
  }

  Future<bool> _drainMessageRefreshes() async {
    var lastRefreshSucceeded = false;
    try {
      do {
        _refreshRequested = false;
        lastRefreshSucceeded = await _refreshMessagesOnce();
      } while (_refreshRequested &&
          mounted &&
          !_value.isLoadingHistory &&
          jsonInt64IsPositive(_value.sessionId));
      return lastRefreshSucceeded;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<bool> _refreshMessagesOnce() async {
    final generation = ++_refreshGeneration;
    final sessionId = _value.sessionId;
    try {
      final history = <AssistantHistoryMessage>[];
      var cursor = _lastMessageId;
      while (true) {
        final page = await _repository.listMessages(
          sessionId: sessionId,
          afterId: cursor,
        );
        if (!mounted ||
            generation != _refreshGeneration ||
            !_sameRun(_value.sessionId, sessionId)) {
          return false;
        }
        history.addAll(page.messages);
        if (!page.hasMore || page.messages.isEmpty) break;
        final nextCursor = page.messages.last.id;
        if (!_idIsAfter(nextCursor, cursor)) break;
        cursor = nextCursor;
      }
      final messages = history.isEmpty
          ? _value.messages
          : _mergeHistory(history);
      _value = _value.copyWith(
        messages: messages,
        clearConnectionError: _value.pendingRetryCommand == null,
      );
      if (history.isNotEmpty) {
        for (final item in history) {
          _advanceMessageCursor(item.id);
        }
      }
      unawaited(_markRead());
      return true;
    } catch (error) {
      if (!mounted || generation != _refreshGeneration) return false;
      _value = _value.copyWith(connectionError: friendlyErrorMessage(error));
      return false;
    }
  }

  List<AssistantMessage> _mergeHistory(List<AssistantHistoryMessage> history) {
    final messages = [..._value.messages];
    for (final item in history) {
      final persisted = _fromHistory(item);
      if (persisted.questionRequest != null) {
        final index = messages.indexWhere(
          (message) =>
              message.id == persisted.id ||
              message.questionRequest?.id == persisted.questionRequest!.id,
        );
        if (index < 0) {
          _insertNumericMessage(messages, persisted);
        } else {
          final existing = messages[index];
          if (!(existing.questionRequest != null &&
              !existing.questionRequest!.isPending &&
              persisted.questionRequest!.isPending)) {
            messages[index] = existing.copyWith(
              questionRequest: persisted.questionRequest,
              runId: persisted.runId,
              text: persisted.text,
            );
          }
        }
        continue;
      }
      if (_isTerminalAssistantResponse(persisted) &&
          jsonInt64IsPositive(persisted.runId)) {
        final responseId = 'run-${jsonInt64Id(persisted.runId)}';
        final placeholderIndex = messages.indexWhere(
          (message) => message.id == responseId,
        );
        if (placeholderIndex >= 0) {
          final existing = messages[placeholderIndex];
          messages.removeWhere(
            (message) => message.id == responseId || message.id == persisted.id,
          );
          _insertNumericMessage(
            messages,
            _reconcilePersistedAssistant(existing, persisted),
          );
          continue;
        }
      }
      if (messages.any((message) => message.id == persisted.id)) continue;
      if (persisted.isMemoryChanged &&
          jsonInt64IsPositive(persisted.changeId)) {
        final existingIndex = messages.indexWhere(
          (message) =>
              message.isMemoryChanged &&
              _sameRun(message.changeId, persisted.changeId),
        );
        if (existingIndex >= 0) {
          final existing = messages.removeAt(existingIndex);
          _insertNumericMessage(
            messages,
            AssistantMessage(
              id: persisted.id,
              runId: persisted.runId,
              role: persisted.role,
              kind: persisted.kind,
              text: persisted.text,
              changeId: persisted.changeId,
              memoryUndoing: existing.memoryUndoing,
              memoryUndone: existing.memoryUndone,
            ),
          );
          continue;
        }
      }
      _insertNumericMessage(messages, persisted);
    }
    return messages;
  }

  AssistantMessage _reconcilePersistedAssistant(
    AssistantMessage existing,
    AssistantMessage persisted,
  ) {
    return AssistantMessage(
      id: persisted.id,
      runId: persisted.runId,
      role: persisted.role,
      kind: persisted.kind,
      text: persisted.text,
      questionRequest: persisted.questionRequest ?? existing.questionRequest,
      answerPresentation:
          persisted.answerPresentation ?? existing.answerPresentation,
      sources: existing.sources,
      toolSteps: _settleSteps(
        existing.toolSteps,
        AssistantToolStatus.completed,
      ),
      attachments: existing.attachments,
      changeId: persisted.changeId,
      isStreaming: false,
      isCanceled: existing.terminalEventReceived && existing.isCanceled,
      degraded: existing.terminalEventReceived && existing.degraded,
      errorCode: existing.terminalEventReceived ? existing.errorCode : '',
      terminalEventReceived: existing.terminalEventReceived,
      memoryUndoing: existing.memoryUndoing,
      memoryUndone: existing.memoryUndone,
    );
  }

  Future<bool> _settleRunFromThread(
    AssistantThreadSummary thread,
    Object observedRunId,
  ) async {
    final hasPersistedTerminal = _hasPersistedTerminalResponseForRun(
      _value.messages,
      observedRunId,
    );
    if (thread.hasActiveRun ||
        !jsonInt64IsPositive(observedRunId) ||
        !_sameRun(_value.activeRunId, observedRunId) ||
        _value.isSending ||
        (!hasPersistedTerminal &&
            _value.isStreaming &&
            _subscription != null &&
            _sameRun(_subscribedRunId, observedRunId)) ||
        (jsonInt64IsPositive(_activeRunFloorMessageId) &&
            _idIsAfter(_activeRunFloorMessageId, thread.lastMessageId))) {
      return false;
    }
    await _cancelSubscription();
    if (!mounted ||
        !_sameRun(_value.activeRunId, observedRunId) ||
        !_sameRun(_value.sessionId, thread.sessionId) ||
        _value.isSending ||
        (jsonInt64IsPositive(_activeRunFloorMessageId) &&
            _idIsAfter(_activeRunFloorMessageId, thread.lastMessageId))) {
      return false;
    }
    _activeCommand = null;
    _activeRunFloorMessageId = 0;
    _value = _value.copyWith(
      messages: _updateResponseMessage(
        'run-${jsonInt64Id(observedRunId)}',
        observedRunId,
        (message) => message.copyWith(isStreaming: false),
      ),
      isStreaming: false,
      isQueued: false,
      clearConnectionError: _value.pendingRetryCommand == null,
      clearActiveRun: true,
      clearLastDisposition: true,
    );
    return true;
  }

  void _advanceActiveRunFloor(Object id) {
    if (jsonInt64IsPositive(id) && _idIsAfter(id, _activeRunFloorMessageId)) {
      _activeRunFloorMessageId = id;
    }
  }

  void _advanceMessageCursor(Object id) {
    if (jsonInt64IsPositive(id) && _idIsAfter(id, _lastMessageId)) {
      _lastMessageId = id;
    }
  }

  Future<void> _markRead() async {
    try {
      await _repository.markThreadRead();
    } on ApiException {
      // Read failure is independently retryable via refresh.
    }
  }
}
