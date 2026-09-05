import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/assistant_models.dart';
import '../data/assistant_repository.dart';

enum AssistantMessageRole { user, assistant, system }

enum AssistantToolStatus {
  running,
  awaitingConfirmation,
  confirming,
  completed,
  confirmed,
  declined,
  expired,
  failed,
}

class AssistantToolStep {
  final String callId;
  final String tool;
  final String summary;
  final AssistantToolStatus status;

  const AssistantToolStep({
    required this.callId,
    required this.tool,
    required this.summary,
    required this.status,
  });

  AssistantToolStep copyWith({AssistantToolStatus? status, String? summary}) {
    return AssistantToolStep(
      callId: callId,
      tool: tool,
      summary: summary ?? this.summary,
      status: status ?? this.status,
    );
  }
}

class PendingChatImage {
  final Object mediaId;
  final String url;
  final String thumbnailUrl;

  const PendingChatImage({
    required this.mediaId,
    required this.url,
    this.thumbnailUrl = '',
  });
}

class PendingAssistantCommand {
  final String message;
  final String requestId;
  final List<PendingChatImage> attachments;
  final Object contextPostId;

  const PendingAssistantCommand({
    required this.message,
    required this.requestId,
    this.attachments = const [],
    this.contextPostId = 0,
  });

  bool matches(String message, Object contextPostId) {
    return this.message == message &&
        jsonInt64Id(this.contextPostId) == jsonInt64Id(contextPostId);
  }
}

class AssistantMessage {
  final String id;
  final Object runId;
  final AssistantMessageRole role;
  final String kind;
  final String text;
  final List<AssistantSourceCard> sources;
  final List<AssistantToolStep> toolSteps;
  final List<PendingChatImage> attachments;
  final Object changeId;
  final bool isStreaming;
  final bool isCanceled;
  final bool degraded;
  final String errorCode;
  final bool terminalEventReceived;
  final bool memoryUndoing;
  final bool memoryUndone;

  const AssistantMessage({
    required this.id,
    required this.role,
    required this.text,
    this.runId = 0,
    this.kind = '',
    this.sources = const [],
    this.toolSteps = const [],
    this.attachments = const [],
    this.changeId = 0,
    this.isStreaming = false,
    this.isCanceled = false,
    this.degraded = false,
    this.errorCode = '',
    this.terminalEventReceived = false,
    this.memoryUndoing = false,
    this.memoryUndone = false,
  });

  bool get hasPendingConfirmation => toolSteps.any(
    (step) => step.status == AssistantToolStatus.awaitingConfirmation,
  );

  bool get isMemoryChanged => kind == 'memory_changed';

  AssistantMessage copyWith({
    String? id,
    Object? runId,
    String? text,
    List<AssistantSourceCard>? sources,
    List<AssistantToolStep>? toolSteps,
    List<PendingChatImage>? attachments,
    Object? changeId,
    bool? isStreaming,
    bool? isCanceled,
    bool? degraded,
    String? errorCode,
    bool? terminalEventReceived,
    bool? memoryUndoing,
    bool? memoryUndone,
  }) {
    return AssistantMessage(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      role: role,
      kind: kind,
      text: text ?? this.text,
      sources: sources ?? this.sources,
      toolSteps: toolSteps ?? this.toolSteps,
      attachments: attachments ?? this.attachments,
      changeId: changeId ?? this.changeId,
      isStreaming: isStreaming ?? this.isStreaming,
      isCanceled: isCanceled ?? this.isCanceled,
      degraded: degraded ?? this.degraded,
      errorCode: errorCode ?? this.errorCode,
      terminalEventReceived:
          terminalEventReceived ?? this.terminalEventReceived,
      memoryUndoing: memoryUndoing ?? this.memoryUndoing,
      memoryUndone: memoryUndone ?? this.memoryUndone,
    );
  }
}

class AssistantState {
  final Object sessionId;
  final Object activeRunId;
  final String activeRunPhase;
  final AssistantDisposition? lastDisposition;
  final List<AssistantMessage> messages;
  final bool isStreaming;
  final bool isSending;
  final bool isQueued;
  final String? connectionError;
  final List<PendingChatImage> pendingAttachments;
  final bool agentAuthorizationRequired;
  final PendingAssistantCommand? pendingRetryCommand;
  final bool isLoaded;
  final bool isLoadingHistory;
  final bool hasMoreHistory;
  final Object nextBeforeId;
  final bool isLoadingOlder;
  final String? historyError;

  const AssistantState({
    this.sessionId = 0,
    this.activeRunId = 0,
    this.activeRunPhase = '',
    this.lastDisposition,
    this.messages = const [],
    this.isStreaming = false,
    this.isSending = false,
    this.isQueued = false,
    this.connectionError,
    this.pendingAttachments = const [],
    this.agentAuthorizationRequired = false,
    this.pendingRetryCommand,
    this.isLoaded = false,
    this.isLoadingHistory = false,
    this.hasMoreHistory = false,
    this.nextBeforeId = 0,
    this.isLoadingOlder = false,
    this.historyError,
  });

  bool get hasActiveRun => jsonInt64IsPositive(activeRunId);

  bool get canSend => !isSending;

  String get pendingRetryMessage => pendingRetryCommand?.message ?? '';

  AssistantState copyWith({
    Object? sessionId,
    Object? activeRunId,
    bool clearActiveRun = false,
    String? activeRunPhase,
    AssistantDisposition? lastDisposition,
    bool clearLastDisposition = false,
    List<AssistantMessage>? messages,
    bool? isStreaming,
    bool? isSending,
    bool? isQueued,
    String? connectionError,
    bool clearConnectionError = false,
    List<PendingChatImage>? pendingAttachments,
    bool clearPendingAttachments = false,
    bool? agentAuthorizationRequired,
    bool clearAgentAuthorizationRequired = false,
    PendingAssistantCommand? pendingRetryCommand,
    bool clearPendingRetryCommand = false,
    bool? isLoaded,
    bool? isLoadingHistory,
    bool? hasMoreHistory,
    Object? nextBeforeId,
    bool? isLoadingOlder,
    String? historyError,
    bool clearHistoryError = false,
  }) {
    return AssistantState(
      sessionId: sessionId ?? this.sessionId,
      activeRunId: clearActiveRun ? 0 : (activeRunId ?? this.activeRunId),
      activeRunPhase: clearActiveRun
          ? ''
          : (activeRunPhase ?? this.activeRunPhase),
      lastDisposition: clearLastDisposition
          ? null
          : (lastDisposition ?? this.lastDisposition),
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      isSending: isSending ?? this.isSending,
      isQueued: isQueued ?? this.isQueued,
      connectionError: clearConnectionError
          ? null
          : (connectionError ?? this.connectionError),
      pendingAttachments: clearPendingAttachments
          ? const []
          : (pendingAttachments ?? this.pendingAttachments),
      agentAuthorizationRequired: clearAgentAuthorizationRequired
          ? false
          : (agentAuthorizationRequired ?? this.agentAuthorizationRequired),
      pendingRetryCommand: clearPendingRetryCommand
          ? null
          : (pendingRetryCommand ?? this.pendingRetryCommand),
      isLoaded: isLoaded ?? this.isLoaded,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      nextBeforeId: nextBeforeId ?? this.nextBeforeId,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      historyError: clearHistoryError
          ? null
          : (historyError ?? this.historyError),
    );
  }
}

class AssistantNotifier extends StateNotifier<AssistantState> {
  final AssistantDataSource _repository;
  final String Function() _createRequestId;
  final String _identityKey;
  StreamSubscription<AssistantRunEvent>? _subscription;
  int _generation = 0;
  int _connectionGeneration = 0;
  int _loadGeneration = 0;
  int _refreshGeneration = 0;
  int _olderGeneration = 0;
  int _lastSeq = 0;
  int _reconnects = 0;
  Object _subscribedRunId = 0;
  String _activeStreamId = '';
  final Set<String> _retiredStreamIds = <String>{};
  bool _usesStreamIds = false;
  Object _lastMessageId = 0;
  Object _activeRunFloorMessageId = 0;
  PendingAssistantCommand? _activeCommand;
  Future<bool>? _refreshFuture;
  bool _refreshRequested = false;

  AssistantNotifier({
    required AssistantDataSource repository,
    String Function()? createRequestId,
    String identityKey = 'direct',
  }) : _repository = repository,
       _createRequestId = createRequestId ?? _defaultRequestId,
       _identityKey = identityKey,
       super(const AssistantState());

  void addPendingAttachment(PendingChatImage image) {
    state = state.copyWith(
      pendingAttachments: [...state.pendingAttachments, image],
    );
  }

  void removePendingAttachment(Object mediaId) {
    state = state.copyWith(
      pendingAttachments: [
        for (final item in state.pendingAttachments)
          if (item.mediaId != mediaId) item,
      ],
    );
  }

  Future<void> load() async {
    if (_identityKey.isEmpty || state.isSending || state.isLoadingHistory) {
      return;
    }
    final generation = ++_loadGeneration;
    ++_refreshGeneration;
    ++_olderGeneration;
    state = state.copyWith(
      isLoadingHistory: true,
      isLoadingOlder: false,
      clearConnectionError: state.messages.isEmpty,
    );
    try {
      final thread = await _repository.getThread();
      if (!mounted || generation != _loadGeneration) return;
      if (state.isLoaded && !_sameRun(thread.sessionId, state.sessionId)) {
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
      if (!resumeRun || !_sameRun(thread.activeRunId, state.activeRunId)) {
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
      state = state.copyWith(
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
      state = state.copyWith(
        connectionError: friendlyErrorMessage(error),
        isLoaded: true,
        isLoadingHistory: false,
      );
    }
  }

  Future<bool> send(String message, {Object contextPostId = 0}) async {
    final normalized = message.trim();
    if (_identityKey.isEmpty ||
        normalized.isEmpty ||
        normalized.length > 2000 ||
        state.isSending ||
        state.isLoadingHistory) {
      return false;
    }

    final pending = state.pendingRetryCommand;
    if (pending != null &&
        pending.matches(normalized, contextPostId) &&
        state.pendingAttachments.isEmpty) {
      return _submit(pending, addOptimisticMessage: false);
    }
    final command = PendingAssistantCommand(
      message: normalized,
      requestId: _createRequestId(),
      attachments: [...state.pendingAttachments],
      contextPostId: contextPostId,
    );
    return _submit(command, addOptimisticMessage: true);
  }

  Future<bool> _submit(
    PendingAssistantCommand command, {
    required bool addOptimisticMessage,
  }) async {
    if (_identityKey.isEmpty || state.isSending || state.isLoadingHistory) {
      return false;
    }
    final optimisticId = 'user-${command.requestId}';
    final messages =
        addOptimisticMessage &&
            !state.messages.any((item) => item.id == optimisticId)
        ? [
            ...state.messages,
            AssistantMessage(
              id: optimisticId,
              role: AssistantMessageRole.user,
              text: command.message,
              attachments: command.attachments,
            ),
          ]
        : state.messages;
    state = state.copyWith(
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
      final sessionChanged = !_sameRun(accepted.sessionId, state.sessionId);
      if (sessionChanged) {
        ++_refreshGeneration;
        ++_olderGeneration;
        _lastMessageId = 0;
      }
      if (sessionChanged || !_sameRun(accepted.runId, state.activeRunId)) {
        _activeRunFloorMessageId = 0;
      }
      _advanceActiveRunFloor(accepted.messageId);
      final userMessages = hasAcceptedMessageId
          ? _reconcileAcceptedUserMessage(
              state.messages,
              optimisticId: optimisticId,
              acceptedMessageId: acceptedMessageId,
              acceptedRunId: accepted.runId,
            )
          : [...state.messages];
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
      state = state.copyWith(
        sessionId: accepted.sessionId,
        activeRunId: accepted.runId,
        clearActiveRun: terminalResponse,
        lastDisposition: accepted.disposition,
        clearLastDisposition: terminalResponse,
        messages: nextMessages,
        isSending: false,
        isStreaming: shouldStream,
        isQueued: queued && !terminalResponse,
        hasMoreHistory: sessionChanged ? false : state.hasMoreHistory,
        nextBeforeId: sessionChanged ? 0 : state.nextBeforeId,
        isLoadingOlder: sessionChanged ? false : state.isLoadingOlder,
        activeRunPhase: terminalResponse
            ? ''
            : switch (accepted.disposition) {
                AssistantDisposition.queued => 'queued',
                AssistantDisposition.steered => 'tool_executing',
                AssistantDisposition.redirected ||
                AssistantDisposition.started => 'model_request',
                _ => state.activeRunPhase,
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
      state = state.copyWith(
        isSending: false,
        agentAuthorizationRequired: unauthorized,
        connectionError: friendlyErrorMessage(error),
        pendingRetryCommand: command,
      );
      return false;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        isSending: false,
        connectionError: friendlyErrorMessage(error),
        pendingRetryCommand: command,
      );
      return false;
    }
  }

  Future<bool> retryPending() async {
    final pending = state.pendingRetryCommand;
    if (pending == null) return false;
    return _submit(pending, addOptimisticMessage: false);
  }

  Future<bool> respondToConfirmation(String callId, bool approved) async {
    final runId = state.activeRunId;
    if (!jsonInt64IsPositive(runId)) return false;
    var changed = false;
    state = state.copyWith(
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
      if (!mounted || !_sameRun(state.activeRunId, runId)) return false;
      state = state.copyWith(
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
      if (!mounted || !_sameRun(state.activeRunId, runId)) return false;
      state = state.copyWith(
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

  Future<bool> stop() async {
    if (!state.hasActiveRun && !state.isStreaming) return true;
    final runId = state.activeRunId;
    if (!jsonInt64IsPositive(runId)) return false;
    try {
      await _repository.cancelRun(runId);
    } catch (error) {
      if (!mounted || !_sameRun(state.activeRunId, runId)) return false;
      state = state.copyWith(connectionError: friendlyErrorMessage(error));
      return false;
    }
    if (!mounted || !_sameRun(state.activeRunId, runId)) return true;
    await _cancelSubscription();
    if (!mounted || !_sameRun(state.activeRunId, runId)) return true;
    _activeCommand = null;
    _activeRunFloorMessageId = 0;
    final responseId = 'run-${jsonInt64Id(runId)}';
    state = state.copyWith(
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

  Future<void> clearHistory() async {
    if (state.isSending || state.isLoadingHistory) return;
    _loadGeneration++;
    _refreshGeneration++;
    _olderGeneration++;
    state = state.copyWith(isLoadingHistory: true, isLoadingOlder: false);
    final stopped = await stop();
    if (!mounted) return;
    if (!stopped) {
      state = state.copyWith(isLoadingHistory: false);
      return;
    }
    try {
      await _repository.deleteHistory();
      if (!mounted) return;
      state = AssistantState(
        pendingAttachments: state.pendingAttachments,
        isLoaded: true,
      );
      _lastMessageId = 0;
      _activeRunFloorMessageId = 0;
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        connectionError: friendlyErrorMessage(error),
        isLoaded: true,
        isLoadingHistory: false,
      );
    }
  }

  Future<bool> undoMemoryChange(Object changeId) async {
    if (!jsonInt64IsPositive(changeId)) return false;
    state = state.copyWith(
      messages: _updateMemoryChange(
        changeId,
        (message) => message.copyWith(memoryUndoing: true),
      ),
      clearConnectionError: true,
    );
    try {
      await _repository.undoMemoryChange(changeId);
      if (!mounted) return false;
      state = state.copyWith(
        messages: _updateMemoryChange(
          changeId,
          (message) =>
              message.copyWith(memoryUndoing: false, memoryUndone: true),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        messages: _updateMemoryChange(
          changeId,
          (message) => message.copyWith(memoryUndoing: false),
        ),
        connectionError: friendlyErrorMessage(error),
      );
      return false;
    }
  }

  bool reconnectActiveRun() {
    final runId = state.activeRunId;
    if (_identityKey.isEmpty ||
        !mounted ||
        !jsonInt64IsPositive(runId) ||
        _subscription != null ||
        _hasPersistedTerminalResponseForRun(state.messages, runId)) {
      return false;
    }
    state = state.copyWith(isStreaming: true);
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
            state.hasActiveRun &&
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
        if (!_isCurrentConnection(generation, connectionGeneration) ||
            !state.isStreaming) {
          return;
        }
        if (state.hasActiveRun && _reconnects < 1) {
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

  void _applyEvent(Object runId, AssistantRunEvent event) {
    if (!_acceptEvent(event)) return;
    final sessionId = jsonInt64IsPositive(event.sessionId)
        ? event.sessionId
        : state.sessionId;
    final responseId = 'run-${jsonInt64Id(runId)}';
    _clearRecoveredTransportError(responseId, runId, event.isTerminal);
    switch (event.type) {
      case AssistantEventType.runStarted:
        state = state.copyWith(
          sessionId: sessionId,
          activeRunId: runId,
          activeRunPhase: 'model_request',
          clearLastDisposition: true,
          isQueued: false,
          isStreaming: true,
          messages: _ensureAssistant(responseId, runId),
        );
      case AssistantEventType.token:
        state = state.copyWith(
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
        state = state.copyWith(
          sessionId: sessionId,
          clearLastDisposition: true,
          messages: _clearResetResponse(responseId, runId),
          isStreaming: true,
          isQueued: false,
        );
      case AssistantEventType.toolCall:
        state = state.copyWith(
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
        state = state.copyWith(
          sessionId: sessionId,
          messages: _upsertTool(
            responseId,
            runId,
            event.toolCall!,
            AssistantToolStatus.completed,
          ),
        );
      case AssistantEventType.confirmRequired:
        state = state.copyWith(
          sessionId: sessionId,
          messages: _upsertTool(
            responseId,
            runId,
            event.toolCall!,
            AssistantToolStatus.awaitingConfirmation,
          ),
        );
      case AssistantEventType.sourceCard:
        state = state.copyWith(
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
        state = state.copyWith(
          sessionId: sessionId,
          messages: _upsertMemoryChangedEvent(runId, event),
        );
      case AssistantEventType.unknown:
        return;
      case AssistantEventType.done:
        _resetStreamTracking();
        _activeCommand = null;
        _activeRunFloorMessageId = 0;
        state = state.copyWith(
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
          clearConnectionError: state.pendingRetryCommand == null,
          clearActiveRun: true,
          clearLastDisposition: true,
        );
      case AssistantEventType.error:
        _resetStreamTracking();
        final needsAuthorization = event.errorCode == 'AGENT_NOT_AUTHORIZED';
        final retryCommand = needsAuthorization ? _activeCommand : null;
        _activeCommand = null;
        _activeRunFloorMessageId = 0;
        state = state.copyWith(
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
      state = state.copyWith(messages: messages, clearConnectionError: true);
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

  List<AssistantMessage> _ensureAssistant(String id, Object runId) {
    if (_exactMessageIndex(state.messages, id) >= 0 ||
        _hasPersistedTerminalResponseForRun(state.messages, runId)) {
      return state.messages;
    }
    return [
      ...state.messages,
      AssistantMessage(
        id: id,
        runId: runId,
        role: AssistantMessageRole.assistant,
        text: '',
        isStreaming: true,
      ),
    ];
  }

  static List<AssistantMessage> _ensureAssistantIn(
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

  static int _exactMessageIndex(
    List<AssistantMessage> messages,
    String responseId,
  ) {
    return messages.indexWhere((message) => message.id == responseId);
  }

  static int _persistedTerminalResponseIndex(
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
    if (_hasPersistedTerminalResponseForRun(state.messages, runId)) {
      _subscribedRunId = 0;
      _resetStreamTracking();
      _activeCommand = null;
      _activeRunFloorMessageId = 0;
      state = state.copyWith(
        isStreaming: false,
        isQueued: false,
        clearActiveRun: true,
        clearLastDisposition: true,
        clearConnectionError: state.pendingRetryCommand == null,
      );
      return;
    }
    final responseId = 'run-${jsonInt64Id(runId)}';
    state = state.copyWith(
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
      for (final message in state.messages)
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
        state.messages.any(
          (message) =>
              message.isMemoryChanged &&
              _sameRun(message.changeId, event.changeId),
        )) {
      return state.messages;
    }
    return [
      ...state.messages,
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
    final messages = [...state.messages];
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

  static List<AssistantMessage> updateAll(
    List<AssistantMessage> messages,
    String id,
    AssistantMessage Function(AssistantMessage) update,
  ) {
    return [
      for (final message in messages)
        if (message.id == id) update(message) else message,
    ];
  }

  Future<bool> refreshForThread(AssistantThreadSummary thread) async {
    if (_identityKey.isEmpty || !state.isLoaded || state.isLoadingHistory) {
      return false;
    }
    if (jsonInt64IsPositive(thread.sessionId) &&
        !_sameRun(thread.sessionId, state.sessionId)) {
      if (state.isSending) return false;
      await load();
      return mounted && state.connectionError == null;
    }
    if (thread.hasActiveRun &&
        !_sameRun(thread.activeRunId, state.activeRunId)) {
      if (state.isSending) return false;
      await load();
      return mounted && state.connectionError == null;
    }
    final observedRunId = state.activeRunId;
    var changed = false;
    if (thread.hasActiveRun && _sameRun(thread.activeRunId, observedRunId)) {
      final phase = thread.activeRunPhase.trim();
      final queuedConsumed =
          phase == 'model_request' || phase == 'tool_executing';
      final preserveQueued =
          (state.isQueued ||
              state.lastDisposition == AssistantDisposition.queued) &&
          !queuedConsumed;
      if ((phase.isNotEmpty && phase != state.activeRunPhase) ||
          preserveQueued != state.isQueued) {
        final hasLiveSubscription =
            _subscription != null && _sameRun(_subscribedRunId, observedRunId);
        state = state.copyWith(
          activeRunPhase: phase.isEmpty ? null : phase,
          isQueued: preserveQueued,
          isStreaming: hasLiveSubscription,
          clearLastDisposition:
              state.lastDisposition != AssistantDisposition.queued ||
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
    if (!mounted || !_sameRun(thread.sessionId, state.sessionId)) {
      return changed;
    }
    return await _settleRunFromThread(thread, observedRunId) || changed;
  }

  Future<bool> loadOlderMessages() async {
    if (_identityKey.isEmpty ||
        state.isLoadingHistory ||
        state.isLoadingOlder ||
        !state.hasMoreHistory ||
        !jsonInt64IsPositive(state.nextBeforeId) ||
        !jsonInt64IsPositive(state.sessionId)) {
      return false;
    }
    final generation = ++_olderGeneration;
    final sessionId = state.sessionId;
    final beforeId = state.nextBeforeId;
    state = state.copyWith(isLoadingOlder: true, clearHistoryError: true);
    try {
      final page = await _repository.listMessages(
        sessionId: sessionId,
        beforeId: beforeId,
      );
      if (!mounted || generation != _olderGeneration) return false;
      if (!_sameRun(state.sessionId, sessionId)) {
        state = state.copyWith(isLoadingOlder: false);
        return false;
      }
      final existingIds = {for (final item in state.messages) item.id};
      final older = [
        for (final item in page.messages)
          if (!existingIds.contains(jsonInt64Id(item.id))) _fromHistory(item),
      ];
      state = state.copyWith(
        messages: [...older, ...state.messages],
        hasMoreHistory: page.hasMore,
        nextBeforeId: page.nextBeforeId,
        isLoadingOlder: false,
        clearHistoryError: true,
      );
      return true;
    } catch (error) {
      if (!mounted || generation != _olderGeneration) return false;
      state = state.copyWith(
        isLoadingOlder: false,
        historyError: friendlyErrorMessage(error),
      );
      return false;
    }
  }

  Future<bool> refreshMessages() {
    if (_identityKey.isEmpty ||
        state.isLoadingHistory ||
        !jsonInt64IsPositive(state.sessionId)) {
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
          !state.isLoadingHistory &&
          jsonInt64IsPositive(state.sessionId));
      return lastRefreshSucceeded;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<bool> _refreshMessagesOnce() async {
    final generation = ++_refreshGeneration;
    final sessionId = state.sessionId;
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
            !_sameRun(state.sessionId, sessionId)) {
          return false;
        }
        history.addAll(page.messages);
        if (!page.hasMore || page.messages.isEmpty) break;
        final nextCursor = page.messages.last.id;
        if (!_idIsAfter(nextCursor, cursor)) break;
        cursor = nextCursor;
      }
      final messages = history.isEmpty
          ? state.messages
          : _mergeHistory(history);
      state = state.copyWith(
        messages: messages,
        clearConnectionError: state.pendingRetryCommand == null,
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
      state = state.copyWith(connectionError: friendlyErrorMessage(error));
      return false;
    }
  }

  List<AssistantMessage> _mergeHistory(List<AssistantHistoryMessage> history) {
    final messages = [...state.messages];
    for (final item in history) {
      final persisted = _fromHistory(item);
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

  static void _insertNumericMessage(
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

  static bool _hasPersistedTerminalResponseForRun(
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

  static bool _hasTerminalEventResponseForRun(
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

  static bool _isTerminalAssistantResponse(AssistantMessage message) {
    return message.role == AssistantMessageRole.assistant &&
        (message.kind.isEmpty ||
            message.kind == 'message' ||
            message.kind == 'watch');
  }

  Future<bool> _settleRunFromThread(
    AssistantThreadSummary thread,
    Object observedRunId,
  ) async {
    final hasPersistedTerminal = _hasPersistedTerminalResponseForRun(
      state.messages,
      observedRunId,
    );
    if (thread.hasActiveRun ||
        !jsonInt64IsPositive(observedRunId) ||
        !_sameRun(state.activeRunId, observedRunId) ||
        state.isSending ||
        (!hasPersistedTerminal &&
            state.isStreaming &&
            _subscription != null &&
            _sameRun(_subscribedRunId, observedRunId)) ||
        (jsonInt64IsPositive(_activeRunFloorMessageId) &&
            _idIsAfter(_activeRunFloorMessageId, thread.lastMessageId))) {
      return false;
    }
    await _cancelSubscription();
    if (!mounted ||
        !_sameRun(state.activeRunId, observedRunId) ||
        !_sameRun(state.sessionId, thread.sessionId) ||
        state.isSending ||
        (jsonInt64IsPositive(_activeRunFloorMessageId) &&
            _idIsAfter(_activeRunFloorMessageId, thread.lastMessageId))) {
      return false;
    }
    _activeCommand = null;
    _activeRunFloorMessageId = 0;
    state = state.copyWith(
      messages: _updateResponseMessage(
        'run-${jsonInt64Id(observedRunId)}',
        observedRunId,
        (message) => message.copyWith(isStreaming: false),
      ),
      isStreaming: false,
      isQueued: false,
      clearConnectionError: state.pendingRetryCommand == null,
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

  static List<AssistantMessage> _reconcileAcceptedUserMessage(
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

  void _advanceMessageCursor(Object id) {
    if (jsonInt64IsPositive(id) && _idIsAfter(id, _lastMessageId)) {
      _lastMessageId = id;
    }
  }

  static bool _idIsAfter(Object candidate, Object current) {
    final next = BigInt.tryParse(jsonInt64Id(candidate));
    final previous = BigInt.tryParse(jsonInt64Id(current));
    if (next == null) return false;
    return previous == null || next > previous;
  }

  static bool _sameRun(Object left, Object right) {
    return jsonInt64Id(left) == jsonInt64Id(right);
  }

  Future<void> _cancelSubscription() async {
    _generation++;
    _connectionGeneration++;
    _subscribedRunId = 0;
    _resetStreamTracking();
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> _markRead() async {
    try {
      await _repository.markThreadRead();
    } on ApiException {
      // Read failure is independently retryable via refresh.
    }
  }

  static AssistantMessage _fromHistory(AssistantHistoryMessage item) {
    final role = switch (item.role) {
      'user' => AssistantMessageRole.user,
      'system' => AssistantMessageRole.system,
      _ => AssistantMessageRole.assistant,
    };
    return AssistantMessage(
      id: jsonInt64Id(item.id),
      runId: item.runId,
      role: role,
      kind: item.kind,
      text: item.content,
      changeId: item.changeId,
    );
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _defaultRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    final suffix = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'assistant-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$suffix';
  }

  @override
  void dispose() {
    _generation++;
    _connectionGeneration++;
    _loadGeneration++;
    _refreshGeneration++;
    _olderGeneration++;
    final subscription = _subscription;
    _subscription = null;
    _subscribedRunId = 0;
    _resetStreamTracking();
    unawaited(subscription?.cancel());
    super.dispose();
  }
}

class AgentConsentState {
  final bool loading;
  final bool loaded;
  final bool granted;
  final int consentVersion;
  final int currentVersion;

  const AgentConsentState({
    this.loading = false,
    this.loaded = false,
    this.granted = false,
    this.consentVersion = 0,
    this.currentVersion = 0,
  });

  bool get needsUpgrade =>
      loaded &&
      granted &&
      currentVersion > 0 &&
      consentVersion < currentVersion;

  bool get canUseMemoryWatch => loaded && granted && !needsUpgrade;

  bool get canStartRun => loaded && granted && !needsUpgrade;

  AgentConsentState copyWith({
    bool? loading,
    bool? loaded,
    bool? granted,
    int? consentVersion,
    int? currentVersion,
  }) {
    return AgentConsentState(
      loading: loading ?? this.loading,
      loaded: loaded ?? this.loaded,
      granted: granted ?? this.granted,
      consentVersion: consentVersion ?? this.consentVersion,
      currentVersion: currentVersion ?? this.currentVersion,
    );
  }
}

class AgentConsentNotifier extends StateNotifier<AgentConsentState> {
  final AssistantDataSource _repository;
  final String _identityKey;
  int _generation = 0;
  Future<void>? _loadFuture;

  AgentConsentNotifier({
    required AssistantDataSource repository,
    String identityKey = 'direct',
  }) : _repository = repository,
       _identityKey = identityKey,
       super(const AgentConsentState());

  Future<void> ensureLoaded() {
    if (_identityKey.isEmpty || state.loaded) return Future<void>.value();
    return reload();
  }

  Future<void> reload() {
    if (_identityKey.isEmpty || !mounted) return Future<void>.value();
    final active = _loadFuture;
    if (active != null) return active;
    late final Future<void> future;
    future = _reloadOnce().whenComplete(() {
      if (identical(_loadFuture, future)) _loadFuture = null;
    });
    _loadFuture = future;
    return future;
  }

  Future<void> _reloadOnce() async {
    final generation = ++_generation;
    state = state.copyWith(loading: true);
    try {
      final status = await _repository.loadAgentConsent();
      if (!mounted || generation != _generation) return;
      state = AgentConsentState(
        loaded: true,
        granted: status.granted,
        consentVersion: status.consentVersion,
        currentVersion: status.currentVersion,
      );
    } on ApiException {
      if (!mounted || generation != _generation) return;
      state = const AgentConsentState(loaded: true, granted: false);
    }
  }

  Future<void> grant() async {
    if (_identityKey.isEmpty || !mounted) return;
    await _repository.setAgentConsent(granted: true);
    if (!mounted) return;
    await reload();
    if (mounted && !state.granted) {
      state = state.copyWith(
        granted: true,
        consentVersion: state.currentVersion == 0 ? 2 : state.currentVersion,
      );
    }
  }

  Future<void> revoke() async {
    if (_identityKey.isEmpty || !mounted) return;
    await _repository.setAgentConsent(granted: false);
    if (!mounted) return;
    await reload();
    if (mounted && state.granted) {
      state = const AgentConsentState(loaded: true);
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}

final assistantRepositoryProvider = Provider<AssistantDataSource>((ref) {
  return AssistantRepository();
});

final assistantUserKeyProvider = Provider<String>((ref) {
  return ref.watch(authenticatedSessionIdentityProvider) ?? '';
});

final assistantNotifierProvider =
    StateNotifierProvider<AssistantNotifier, AssistantState>((ref) {
      final identityKey = ref.watch(assistantUserKeyProvider);
      return AssistantNotifier(
        repository: ref.read(assistantRepositoryProvider),
        identityKey: identityKey,
      );
    });

final agentConsentNotifierProvider =
    StateNotifierProvider<AgentConsentNotifier, AgentConsentState>((ref) {
      final identityKey = ref.watch(assistantUserKeyProvider);
      final notifier = AgentConsentNotifier(
        repository: ref.read(assistantRepositoryProvider),
        identityKey: identityKey,
      );
      if (identityKey.isNotEmpty) unawaited(notifier.ensureLoaded());
      return notifier;
    });
