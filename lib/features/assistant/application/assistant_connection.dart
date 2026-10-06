part of 'assistant_notifier.dart';

// Owns the run event subscription: generations, seq cursor, reconnect timers
// and teardown. State transitions per event live in assistant_run_reducer.dart.
extension _AssistantConnection on AssistantNotifier {
  // Re-attaches to the active run (manual retry or thread poll); refuses when
  // the run already has a persisted answer or automatic retries are blocked.
  bool _reconnectRun({bool automatic = false}) {
    final runId = _value.activeRunId;
    if (_identityKey.isEmpty ||
        !mounted ||
        !jsonInt64IsPositive(runId) ||
        _subscription != null ||
        (automatic && _sameRun(_automaticReconnectBlockedRunId, runId)) ||
        _hasPersistedTerminalResponseForRun(_value.messages, runId)) {
      return false;
    }
    _value = _value.copyWith(isStreaming: true);
    _ensureSubscribed(runId);
    return true;
  }

  // Keeps an existing subscription; otherwise resumes from the last seq when
  // the run is the one we were already following.
  void _ensureSubscribed(Object runId) {
    if (_sameRun(_subscribedRunId, runId) && _subscription != null) return;
    _subscribe(
      runId,
      afterSeq: _sameRun(_subscribedRunId, runId) ? _lastSeq : 0,
    );
  }

  // Starts a fresh subscription from [afterSeq]; bumping the generation makes
  // callbacks of the previous one inert, and stream ids reset on a run change.
  void _subscribe(Object runId, {required Object afterSeq}) {
    // A new subscription comes from an explicit action/new run or from the
    // automatic reconnect gate above. A manual retry may try the same run.
    _automaticReconnectBlockedRunId = 0;
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

  // Opens one connection attempt. Events are de-duplicated by seq before they
  // reach the reducer; errors and early closes decide between one in-place
  // reconnect, a delayed waiting-input reconnect, or a transport error.
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
        if (error is AssistantStreamException && !error.retryable) {
          // Preserve the active run while stopping both the short waiting
          // reconnect timer and the thread poll's automatic reconnect path.
          _automaticReconnectBlockedRunId = runId;
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

  // Late callbacks from replaced or cancelled connections must not touch state.
  bool _isCurrentConnection(int generation, int connectionGeneration) {
    return mounted &&
        generation == _generation &&
        connectionGeneration == _connectionGeneration;
  }

  // A run parked on user questions may legitimately close its stream; poll it
  // again shortly while it is still waiting for input.
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

  // Folds one accepted event through the pure reducer and writes back both the
  // visible state and the run bookkeeping the reducer owns.
  void _applyEvent(Object runId, AssistantRunEvent event) {
    final next = reduceAssistantRunEvent(
      AssistantRunReduction(
        state: _value,
        streams: _streams,
        activeCommand: _activeCommand,
        activeRunFloorMessageId: _activeRunFloorMessageId,
      ),
      runId,
      event,
    );
    _streams = next.streams;
    _activeCommand = next.activeCommand;
    _activeRunFloorMessageId = next.activeRunFloorMessageId;
    _value = next.state;
  }

  // Forgets stream ids when the followed run changes or the subscription ends.
  void _resetStreamTracking() {
    _streams = AssistantStreamTracking.idle;
  }

  // Ends the current connection after a failed attempt: a run with a persisted
  // answer is simply closed, otherwise its response is marked disconnected so
  // the next event (or a manual retry) can recover it.
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
        _value.messages,
        responseId,
        runId,
        (message) => message.copyWith(
          text: message.text.isEmpty ? '响应中断' : message.text,
          isStreaming: false,
          degraded: true,
          errorCode: 'STREAM_DISCONNECTED',
          toolSteps: _settleSteps(
            message.toolSteps,
            AssistantToolStatus.failed,
          ),
        ),
        createIfMissing: true,
        matchPersistedTerminal: true,
      ),
      isStreaming: false,
      connectionError: error,
    );
  }

  // Explicit teardown when the followed run stops, finishes elsewhere or the
  // loaded session changes.
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
