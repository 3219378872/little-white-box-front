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
  final bool memoryUndoing;
  final bool memoryUndone;

  const AssistantMessage({
    required this.id,
    required this.role,
    required this.text,
    this.kind = '',
    this.sources = const [],
    this.toolSteps = const [],
    this.attachments = const [],
    this.changeId = 0,
    this.isStreaming = false,
    this.isCanceled = false,
    this.degraded = false,
    this.errorCode = '',
    this.memoryUndoing = false,
    this.memoryUndone = false,
  });

  bool get hasPendingConfirmation => toolSteps.any(
    (step) => step.status == AssistantToolStatus.awaitingConfirmation,
  );

  bool get isMemoryChanged => kind == 'memory_changed';

  AssistantMessage copyWith({
    String? text,
    List<AssistantSourceCard>? sources,
    List<AssistantToolStep>? toolSteps,
    List<PendingChatImage>? attachments,
    Object? changeId,
    bool? isStreaming,
    bool? isCanceled,
    bool? degraded,
    String? errorCode,
    bool? memoryUndoing,
    bool? memoryUndone,
  }) {
    return AssistantMessage(
      id: id,
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
      lastDisposition: lastDisposition ?? this.lastDisposition,
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
  Object _lastMessageId = 0;
  PendingAssistantCommand? _activeCommand;

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
    if (_identityKey.isEmpty) return;
    final generation = ++_loadGeneration;
    ++_refreshGeneration;
    ++_olderGeneration;
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
      state = state.copyWith(
        sessionId: thread.sessionId,
        activeRunId: thread.activeRunId,
        activeRunPhase: thread.activeRunPhase,
        messages: [for (final item in history) _fromHistory(item)],
        isStreaming: thread.hasActiveRun,
        isQueued: thread.activeRunPhase == 'queued',
        clearConnectionError: true,
        isLoaded: true,
        hasMoreHistory: page.hasMore,
        nextBeforeId: page.nextBeforeId,
        isLoadingOlder: false,
        clearHistoryError: true,
      );
      if (thread.hasActiveRun) {
        _subscribe(thread.activeRunId, afterSeq: 0);
      }
      unawaited(_markRead());
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        connectionError: friendlyErrorMessage(error),
        isLoaded: true,
      );
    }
  }

  Future<bool> send(String message, {Object contextPostId = 0}) async {
    final normalized = message.trim();
    if (_identityKey.isEmpty ||
        normalized.isEmpty ||
        normalized.length > 2000 ||
        state.isSending) {
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
    if (_identityKey.isEmpty || state.isSending) return false;
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
      final userMessages = [
        for (final item in state.messages)
          if (item.id == optimisticId &&
              jsonInt64IsPositive(accepted.messageId))
            AssistantMessage(
              id: jsonInt64Id(accepted.messageId),
              role: item.role,
              text: item.text,
              attachments: item.attachments,
            )
          else
            item,
      ];
      _advanceMessageCursor(accepted.messageId);
      final queued = accepted.disposition == AssistantDisposition.queued;
      final shouldStream =
          accepted.disposition == AssistantDisposition.started ||
          accepted.disposition == AssistantDisposition.redirected ||
          accepted.disposition == AssistantDisposition.steered ||
          queued;
      final responseId = 'run-${jsonInt64Id(accepted.runId)}';
      final nextMessages = queued
          ? userMessages
          : _ensureAssistantIn(userMessages, responseId);
      state = state.copyWith(
        sessionId: accepted.sessionId,
        activeRunId: accepted.runId,
        lastDisposition: accepted.disposition,
        messages: nextMessages,
        isSending: false,
        isStreaming: shouldStream,
        isQueued: queued,
        activeRunPhase: switch (accepted.disposition) {
          AssistantDisposition.queued => 'queued',
          AssistantDisposition.steered => 'tool_executing',
          AssistantDisposition.redirected ||
          AssistantDisposition.started => 'model_request',
          _ => state.activeRunPhase,
        },
        clearPendingRetryCommand: true,
      );
      _activeCommand = command;
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
      messages: _updateLastAssistant((message) {
        return message.copyWith(
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
        );
      }),
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
    state = state.copyWith(
      messages: _updateLastAssistant(
        (message) => message.copyWith(
          text: message.text.isEmpty ? '已取消' : message.text,
          isStreaming: false,
          isCanceled: true,
        ),
      ),
      isStreaming: false,
      isQueued: false,
      clearActiveRun: true,
      clearConnectionError: true,
    );
    return true;
  }

  Future<void> clearHistory() async {
    if (!await stop()) return;
    _loadGeneration++;
    _refreshGeneration++;
    _olderGeneration++;
    try {
      await _repository.deleteHistory();
      if (!mounted) return;
      state = AssistantState(
        pendingAttachments: state.pendingAttachments,
        isLoaded: true,
      );
      _lastMessageId = 0;
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(connectionError: friendlyErrorMessage(error));
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

  void _ensureSubscribed(Object runId) {
    if (_sameRun(_subscribedRunId, runId) && _subscription != null) return;
    _subscribe(
      runId,
      afterSeq: _sameRun(_subscribedRunId, runId) ? _lastSeq : 0,
    );
  }

  void _subscribe(Object runId, {required Object afterSeq}) {
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
          _subscription = null;
          _subscribedRunId = 0;
          _connectionGeneration++;
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
    final sessionId = jsonInt64IsPositive(event.sessionId)
        ? event.sessionId
        : state.sessionId;
    final responseId = 'run-${jsonInt64Id(runId)}';
    switch (event.type) {
      case AssistantEventType.runStarted:
        state = state.copyWith(
          sessionId: sessionId,
          activeRunId: runId,
          activeRunPhase: 'model_request',
          isQueued: false,
          isStreaming: true,
          messages: _ensureAssistant(responseId),
        );
      case AssistantEventType.token:
        state = state.copyWith(
          sessionId: sessionId,
          messages: _updateMessage(
            responseId,
            (message) => message.copyWith(text: '${message.text}${event.text}'),
            createIfMissing: true,
          ),
          isStreaming: true,
          isQueued: false,
        );
      case AssistantEventType.toolCall:
        state = state.copyWith(
          sessionId: sessionId,
          activeRunPhase: 'tool_executing',
          messages: _upsertTool(
            responseId,
            event.toolCall!,
            AssistantToolStatus.running,
          ),
        );
      case AssistantEventType.toolResult:
        state = state.copyWith(
          sessionId: sessionId,
          messages: _upsertTool(
            responseId,
            event.toolCall!,
            AssistantToolStatus.completed,
          ),
        );
      case AssistantEventType.confirmRequired:
        state = state.copyWith(
          sessionId: sessionId,
          messages: _upsertTool(
            responseId,
            event.toolCall!,
            AssistantToolStatus.awaitingConfirmation,
          ),
        );
      case AssistantEventType.sourceCard:
        if (event.sourceCard == null) return;
        state = state.copyWith(
          sessionId: sessionId,
          messages: _updateMessage(responseId, (message) {
            final source = event.sourceCard!;
            return message.sources.contains(source)
                ? message
                : message.copyWith(sources: [...message.sources, source]);
          }, createIfMissing: true),
        );
      case AssistantEventType.memoryChanged:
        state = state.copyWith(
          sessionId: sessionId,
          messages: [
            ...state.messages,
            AssistantMessage(
              id: 'memory-${jsonInt64Id(event.changeId)}-${event.seq}',
              role: AssistantMessageRole.system,
              kind: 'memory_changed',
              text: event.text.isEmpty ? '记忆已更新' : event.text,
              changeId: event.changeId,
            ),
          ],
        );
      case AssistantEventType.unknown:
        return;
      case AssistantEventType.done:
        _activeCommand = null;
        state = state.copyWith(
          sessionId: sessionId,
          messages: _updateMessage(
            responseId,
            (message) => message.copyWith(
              isStreaming: false,
              degraded: event.degraded,
              toolSteps: _settleSteps(
                message.toolSteps,
                AssistantToolStatus.completed,
              ),
            ),
            createIfMissing: true,
          ),
          isStreaming: false,
          isQueued: false,
          clearActiveRun: true,
        );
      case AssistantEventType.error:
        final needsAuthorization = event.errorCode == 'AGENT_NOT_AUTHORIZED';
        final retryCommand = needsAuthorization ? _activeCommand : null;
        _activeCommand = null;
        state = state.copyWith(
          sessionId: sessionId,
          agentAuthorizationRequired: needsAuthorization,
          messages: _updateMessage(
            responseId,
            (message) => message.copyWith(
              text: message.text.isEmpty ? event.text : message.text,
              isStreaming: false,
              degraded: true,
              errorCode: event.errorCode,
              toolSteps: _settleSteps(
                message.toolSteps,
                AssistantToolStatus.failed,
              ),
            ),
            createIfMissing: true,
          ),
          isStreaming: false,
          isQueued: false,
          connectionError: event.text,
          pendingRetryCommand: retryCommand,
          clearActiveRun: true,
        );
    }
  }

  List<AssistantMessage> _ensureAssistant(String id) {
    if (state.messages.any((message) => message.id == id)) {
      return state.messages;
    }
    return [
      ...state.messages,
      AssistantMessage(
        id: id,
        role: AssistantMessageRole.assistant,
        text: '',
        isStreaming: true,
      ),
    ];
  }

  static List<AssistantMessage> _ensureAssistantIn(
    List<AssistantMessage> messages,
    String id,
  ) {
    if (messages.any((message) => message.id == id)) return messages;
    return [
      ...messages,
      AssistantMessage(
        id: id,
        role: AssistantMessageRole.assistant,
        text: '',
        isStreaming: true,
      ),
    ];
  }

  List<AssistantMessage> _upsertTool(
    String responseId,
    AssistantToolCall call,
    AssistantToolStatus status,
  ) {
    return _updateMessage(responseId, (message) {
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
    }, createIfMissing: true);
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
    int generation,
    int connectionGeneration,
  ) {
    if (!_isCurrentConnection(generation, connectionGeneration)) return;
    final subscription = _subscription;
    _subscription = null;
    _connectionGeneration++;
    unawaited(subscription?.cancel());
    state = state.copyWith(
      messages: _updateLastAssistant(
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
      ),
      isStreaming: false,
      isQueued: false,
      connectionError: error,
    );
  }

  List<AssistantMessage> _setToolStatus(
    String callId, {
    required Set<AssistantToolStatus> from,
    required AssistantToolStatus to,
  }) {
    return _updateLastAssistant((message) {
      return message.copyWith(
        toolSteps: [
          for (final step in message.toolSteps)
            if (step.callId == callId && from.contains(step.status))
              step.copyWith(status: to)
            else
              step,
        ],
      );
    });
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

  List<AssistantMessage> _updateMessage(
    String id,
    AssistantMessage Function(AssistantMessage) update, {
    bool createIfMissing = false,
  }) {
    final exists = state.messages.any((message) => message.id == id);
    if (!exists && createIfMissing) {
      return updateAll(
        [
          ...state.messages,
          AssistantMessage(
            id: id,
            role: AssistantMessageRole.assistant,
            text: '',
            isStreaming: true,
          ),
        ],
        id,
        update,
      );
    }
    return updateAll(state.messages, id, update);
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

  List<AssistantMessage> _updateLastAssistant(
    AssistantMessage Function(AssistantMessage) update,
  ) {
    final messages = [...state.messages];
    final index = messages.lastIndexWhere(
      (message) => message.role == AssistantMessageRole.assistant,
    );
    if (index >= 0) messages[index] = update(messages[index]);
    return messages;
  }

  Future<bool> refreshForThread(AssistantThreadSummary thread) async {
    if (_identityKey.isEmpty || !state.isLoaded) return false;
    if (jsonInt64IsPositive(thread.sessionId) &&
        !_sameRun(thread.sessionId, state.sessionId)) {
      await load();
      return mounted && state.connectionError == null;
    }
    if (!jsonInt64IsPositive(thread.lastMessageId) ||
        !_idIsAfter(thread.lastMessageId, _lastMessageId)) {
      return false;
    }
    return refreshMessages();
  }

  Future<bool> loadOlderMessages() async {
    if (_identityKey.isEmpty ||
        state.isLoadingOlder ||
        !state.hasMoreHistory ||
        !jsonInt64IsPositive(state.nextBeforeId) ||
        !jsonInt64IsPositive(state.sessionId)) {
      return false;
    }
    final generation = ++_olderGeneration;
    state = state.copyWith(isLoadingOlder: true, clearHistoryError: true);
    try {
      final page = await _repository.listMessages(
        sessionId: state.sessionId,
        beforeId: state.nextBeforeId,
      );
      if (!mounted || generation != _olderGeneration) return false;
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

  Future<bool> refreshMessages() async {
    if (_identityKey.isEmpty || !jsonInt64IsPositive(state.sessionId)) {
      return false;
    }
    final generation = ++_refreshGeneration;
    try {
      final history = <AssistantHistoryMessage>[];
      var cursor = _lastMessageId;
      while (true) {
        final page = await _repository.listMessages(
          sessionId: state.sessionId,
          afterId: cursor,
        );
        if (!mounted || generation != _refreshGeneration) return false;
        history.addAll(page.messages);
        if (!page.hasMore || page.messages.isEmpty) break;
        final nextCursor = page.messages.last.id;
        if (!_idIsAfter(nextCursor, cursor)) break;
        cursor = nextCursor;
      }
      if (history.isNotEmpty) {
        for (final item in history) {
          _advanceMessageCursor(item.id);
        }
        state = state.copyWith(messages: _mergeHistory(history));
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
      final id = jsonInt64Id(item.id);
      if (messages.any((message) => message.id == id)) continue;
      if (jsonInt64IsPositive(item.runId) &&
          item.role != 'user' &&
          messages.any(
            (message) => message.id == 'run-${jsonInt64Id(item.runId)}',
          )) {
        continue;
      }
      messages.add(_fromHistory(item));
    }
    return messages;
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

  AgentConsentNotifier({
    required AssistantDataSource repository,
    String identityKey = 'direct',
  }) : _repository = repository,
       _identityKey = identityKey,
       super(const AgentConsentState());

  Future<void> ensureLoaded() async {
    if (_identityKey.isEmpty) return;
    if (state.loaded || state.loading) return;
    await reload();
  }

  Future<void> reload() async {
    if (_identityKey.isEmpty || !mounted) return;
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
  return ref.watch(
    authNotifierProvider.select((state) {
      if (!state.isAuthenticated || !jsonInt64IsPositive(state.userId ?? 0)) {
        return '';
      }
      return jsonInt64Id(state.userId!);
    }),
  );
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
