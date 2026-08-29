import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../data/assistant_models.dart';
import '../data/assistant_repository.dart';

enum AssistantMessageRole { user, assistant, system }

enum AssistantToolStatus {
  running,
  awaitingConfirmation,
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
  final String pendingRetryMessage;

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
    this.pendingRetryMessage = '',
  });

  bool get hasActiveRun => jsonInt64IsPositive(activeRunId);

  bool get canSend => !isSending;

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
    String? pendingRetryMessage,
    bool clearPendingRetryMessage = false,
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
      pendingRetryMessage: clearPendingRetryMessage
          ? ''
          : (pendingRetryMessage ?? this.pendingRetryMessage),
    );
  }
}

class AssistantNotifier extends StateNotifier<AssistantState> {
  final AssistantDataSource _repository;
  final String Function() _createRequestId;
  StreamSubscription<AssistantRunEvent>? _subscription;
  int _generation = 0;
  int _lastSeq = 0;
  int _reconnects = 0;

  AssistantNotifier({
    required AssistantDataSource repository,
    String Function()? createRequestId,
  }) : _repository = repository,
       _createRequestId = createRequestId ?? _defaultRequestId,
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
    try {
      final thread = await _repository.getThread();
      final history = await _repository.listMessages(
        sessionId: thread.sessionId,
      );
      if (!mounted) return;
      state = state.copyWith(
        sessionId: thread.sessionId,
        activeRunId: thread.activeRunId,
        activeRunPhase: thread.activeRunPhase,
        messages: [for (final item in history) _fromHistory(item)],
        isStreaming: thread.hasActiveRun,
        isQueued: thread.activeRunPhase == 'queued',
        clearConnectionError: true,
      );
      if (thread.hasActiveRun) {
        _subscribe(thread.activeRunId, afterSeq: 0);
      }
      unawaited(_markRead());
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(connectionError: friendlyErrorMessage(error));
    }
  }

  Future<bool> send(String message) async {
    final normalized = message.trim();
    if (normalized.isEmpty || normalized.length > 2000 || state.isSending) {
      return false;
    }

    final requestId = _createRequestId();
    final attachments = [...state.pendingAttachments];
    state = state.copyWith(
      messages: [
        ...state.messages,
        AssistantMessage(
          id: 'user-$requestId',
          role: AssistantMessageRole.user,
          text: normalized,
          attachments: attachments,
        ),
      ],
      isSending: true,
      pendingRetryMessage: normalized,
      clearConnectionError: true,
      clearPendingAttachments: true,
      clearAgentAuthorizationRequired: true,
    );

    try {
      final accepted = await _repository.postMessage(
        message: normalized,
        requestId: requestId,
        attachments: [
          for (final item in attachments)
            AssistantAttachment(mediaId: item.mediaId, url: item.url),
        ],
      );
      if (!mounted) return false;
      final userMessages = [
        for (final item in state.messages)
          if (item.id == 'user-$requestId')
            AssistantMessage(
              id: jsonInt64Id(accepted.messageId),
              role: item.role,
              text: item.text,
              attachments: item.attachments,
            )
          else
            item,
      ];
      final queued = accepted.disposition == AssistantDisposition.queued;
      final shouldStream =
          accepted.disposition == AssistantDisposition.started ||
          accepted.disposition == AssistantDisposition.redirected ||
          accepted.disposition == AssistantDisposition.steered ||
          queued;
      state = state.copyWith(
        sessionId: accepted.sessionId,
        activeRunId: accepted.runId,
        lastDisposition: accepted.disposition,
        messages: queued
            ? userMessages
            : [
                ...userMessages,
                if (!_hasStreamingAssistant)
                  AssistantMessage(
                    id: 'run-${jsonInt64Id(accepted.runId)}',
                    role: AssistantMessageRole.assistant,
                    text: '',
                    isStreaming: true,
                  ),
              ],
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
        clearPendingRetryMessage: true,
      );
      if (shouldStream && jsonInt64IsPositive(accepted.runId)) {
        if (accepted.disposition == AssistantDisposition.redirected) {
          _lastSeq = 0;
        }
        _subscribe(
          accepted.runId,
          afterSeq: accepted.disposition == AssistantDisposition.steered
              ? _lastSeq
              : 0,
        );
      }
      return true;
    } on ApiException catch (error) {
      if (!mounted) return false;
      final unauthorized = error.message.contains('AGENT_NOT_AUTHORIZED');
      state = state.copyWith(
        isSending: false,
        agentAuthorizationRequired: unauthorized,
        connectionError: friendlyErrorMessage(error),
        pendingRetryMessage: normalized,
      );
      return false;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        isSending: false,
        connectionError: friendlyErrorMessage(error),
        pendingRetryMessage: normalized,
      );
      return false;
    }
  }

  Future<bool> retryPending() async {
    final pending = state.pendingRetryMessage;
    if (pending.isEmpty) return false;
    return send(pending);
  }

  Future<void> respondToConfirmation(String callId, bool approved) async {
    final runId = state.activeRunId;
    if (!jsonInt64IsPositive(runId)) return;
    state = state.copyWith(
      messages: _updateLastAssistant((message) {
        return message.copyWith(
          toolSteps: [
            for (final step in message.toolSteps)
              if (step.callId == callId &&
                  step.status == AssistantToolStatus.awaitingConfirmation)
                step.copyWith(
                  status: approved
                      ? AssistantToolStatus.confirmed
                      : AssistantToolStatus.declined,
                )
              else
                step,
          ],
        );
      }),
    );
    try {
      await _repository.confirmRun(
        runId: runId,
        callId: callId,
        approved: approved,
      );
    } on ApiException {
      // Card is already non-interactive; later error/timeout events present the outcome.
    }
  }

  Future<void> stop() async {
    if (!state.hasActiveRun && !state.isStreaming) return;
    final runId = state.activeRunId;
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    if (jsonInt64IsPositive(runId)) {
      try {
        await _repository.cancelRun(runId);
      } on ApiException {
        // Local stop still applies even if the cancel request fails.
      }
    }
    if (!mounted) return;
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
  }

  Future<void> startNewSession() async {
    await stop();
    try {
      final sessionId = await _repository.createSession();
      if (!mounted) return;
      state = AssistantState(
        sessionId: sessionId,
        pendingAttachments: state.pendingAttachments,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(connectionError: friendlyErrorMessage(error));
    }
  }

  Future<void> clearHistory() async {
    await stop();
    try {
      await _repository.deleteHistory();
      if (!mounted) return;
      state = AssistantState(pendingAttachments: state.pendingAttachments);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(connectionError: friendlyErrorMessage(error));
    }
  }

  Future<void> undoMemoryChange(Object changeId) async {
    try {
      await _repository.undoMemoryChange(changeId);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(connectionError: friendlyErrorMessage(error));
    }
  }

  void _subscribe(Object runId, {required Object afterSeq}) {
    _generation++;
    final generation = _generation;
    _lastSeq = _asInt(afterSeq);
    _reconnects = 0;
    unawaited(_subscription?.cancel());
    _listen(runId, generation);
  }

  void _listen(Object runId, int generation) {
    final stream = _repository.runEvents(runId: runId, afterSeq: _lastSeq);
    _subscription = stream.listen(
      (event) {
        if (generation != _generation) return;
        if (event.seq > _lastSeq) _lastSeq = event.seq;
        _applyEvent(runId, event);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation != _generation) return;
        if (error is AssistantStreamException &&
            state.hasActiveRun &&
            _reconnects < 1) {
          _reconnects++;
          _listen(runId, generation);
          return;
        }
        _finishWithTransportError(friendlyErrorMessage(error));
      },
      onDone: () {
        if (generation != _generation || !state.isStreaming) return;
        if (state.hasActiveRun && _reconnects < 1) {
          _reconnects++;
          _listen(runId, generation);
          return;
        }
        _finishWithTransportError('Assistant 连接意外中断');
      },
      cancelOnError: false,
    );
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
          clearActiveRun: true,
        );
    }
  }

  bool get _hasStreamingAssistant => state.messages.any(
    (message) =>
        message.role == AssistantMessageRole.assistant && message.isStreaming,
  );

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
          _ => step,
        },
    ];
  }

  void _finishWithTransportError(String error) {
    state = state.copyWith(
      messages: _updateLastAssistant(
        (message) => message.copyWith(
          text: message.text.isEmpty ? '响应中断' : message.text,
          isStreaming: false,
          degraded: true,
          errorCode: 'STREAM_DISCONNECTED',
          toolSteps: _settleSteps(message.toolSteps, AssistantToolStatus.failed),
        ),
      ),
      isStreaming: false,
      isQueued: false,
      connectionError: error,
    );
  }

  List<AssistantMessage> _updateMessage(
    String id,
    AssistantMessage Function(AssistantMessage) update, {
    bool createIfMissing = false,
  }) {
    final exists = state.messages.any((message) => message.id == id);
    if (!exists && createIfMissing) {
      return updateAll([
        ...state.messages,
        AssistantMessage(
          id: id,
          role: AssistantMessageRole.assistant,
          text: '',
          isStreaming: true,
        ),
      ], id, update);
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
    unawaited(_subscription?.cancel());
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

  AgentConsentNotifier({required AssistantDataSource repository})
    : _repository = repository,
      super(const AgentConsentState());

  Future<void> ensureLoaded() async {
    if (state.loaded || state.loading) return;
    await reload();
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true);
    try {
      final status = await _repository.loadAgentConsent();
      state = AgentConsentState(
        loaded: true,
        granted: status.granted,
        consentVersion: status.consentVersion,
        currentVersion: status.currentVersion,
      );
    } on ApiException {
      state = const AgentConsentState(loaded: true, granted: false);
    }
  }

  Future<void> grant() async {
    await _repository.setAgentConsent(granted: true);
    await reload();
    if (!state.granted) {
      state = state.copyWith(
        granted: true,
        consentVersion: state.currentVersion == 0 ? 2 : state.currentVersion,
      );
    }
  }

  Future<void> revoke() async {
    await _repository.setAgentConsent(granted: false);
    await reload();
    if (state.granted) {
      state = const AgentConsentState(loaded: true);
    }
  }
}

final assistantRepositoryProvider = Provider<AssistantDataSource>((ref) {
  return AssistantRepository();
});

final assistantNotifierProvider =
    StateNotifierProvider<AssistantNotifier, AssistantState>((ref) {
      return AssistantNotifier(
        repository: ref.read(assistantRepositoryProvider),
      );
    });

final agentConsentNotifierProvider =
    StateNotifierProvider<AgentConsentNotifier, AgentConsentState>((ref) {
      return AgentConsentNotifier(
        repository: ref.read(assistantRepositoryProvider),
      );
    });
