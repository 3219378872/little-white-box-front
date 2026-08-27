import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../sdk/data/gateway.dart' show AssistantAttachment;
import '../data/assistant_models.dart';
import '../data/assistant_repository.dart';

enum AssistantMessageRole { user, assistant }

/// 工具步骤状态（AGNT-060 / FX-056）：confirm_required 渲染为确认卡片。
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

  AssistantToolStep copyWith({AssistantToolStatus? status}) {
    return AssistantToolStep(
      callId: callId,
      tool: tool,
      summary: summary,
      status: status ?? this.status,
    );
  }
}

/// 用户随消息携带的会话附件缩略信息（仅展示用）。
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
  final String text;
  final List<AssistantSourceReference> sources;
  final List<AssistantToolStep> toolSteps;
  final List<PendingChatImage> attachments;
  final List<AssistantStructuredCard> cards;
  final List<AssistantStructuredAction> actions;
  final List<AssistantWatchHitNotice> watchHits;
  final bool isStreaming;
  final bool isCanceled;
  final bool degraded;
  final String errorCode;

  const AssistantMessage({
    required this.id,
    required this.role,
    required this.text,
    this.sources = const [],
    this.toolSteps = const [],
    this.attachments = const [],
    this.cards = const [],
    this.actions = const [],
    this.watchHits = const [],
    this.isStreaming = false,
    this.isCanceled = false,
    this.degraded = false,
    this.errorCode = '',
  });

  bool get hasPendingConfirmation => toolSteps.any(
    (step) => step.status == AssistantToolStatus.awaitingConfirmation,
  );

  AssistantMessage copyWith({
    String? text,
    List<AssistantSourceReference>? sources,
    List<AssistantToolStep>? toolSteps,
    List<PendingChatImage>? attachments,
    List<AssistantStructuredCard>? cards,
    List<AssistantStructuredAction>? actions,
    List<AssistantWatchHitNotice>? watchHits,
    bool? isStreaming,
    bool? isCanceled,
    bool? degraded,
    String? errorCode,
  }) {
    return AssistantMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      sources: sources ?? this.sources,
      toolSteps: toolSteps ?? this.toolSteps,
      attachments: attachments ?? this.attachments,
      cards: cards ?? this.cards,
      actions: actions ?? this.actions,
      watchHits: watchHits ?? this.watchHits,
      isStreaming: isStreaming ?? this.isStreaming,
      isCanceled: isCanceled ?? this.isCanceled,
      degraded: degraded ?? this.degraded,
      errorCode: errorCode ?? this.errorCode,
    );
  }
}

class AssistantState {
  final String conversationId;
  final List<AssistantMessage> messages;
  final bool isStreaming;
  final String? connectionError;
  final AssistantMode mode;
  final List<PendingChatImage> pendingAttachments;
  final bool agentAuthorizationRequired;

  const AssistantState({
    this.conversationId = '',
    this.messages = const [],
    this.isStreaming = false,
    this.connectionError,
    this.mode = AssistantMode.enhancedSearch,
    this.pendingAttachments = const [],
    this.agentAuthorizationRequired = false,
  });

  AssistantState copyWith({
    String? conversationId,
    List<AssistantMessage>? messages,
    bool? isStreaming,
    String? connectionError,
    bool clearConnectionError = false,
    AssistantMode? mode,
    List<PendingChatImage>? pendingAttachments,
    bool clearPendingAttachments = false,
    bool? agentAuthorizationRequired,
    bool clearAgentAuthorizationRequired = false,
  }) {
    return AssistantState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      connectionError: clearConnectionError
          ? null
          : (connectionError ?? this.connectionError),
      mode: mode ?? this.mode,
      pendingAttachments: clearPendingAttachments
          ? const []
          : (pendingAttachments ?? this.pendingAttachments),
      agentAuthorizationRequired: clearAgentAuthorizationRequired
          ? false
          : (agentAuthorizationRequired ?? this.agentAuthorizationRequired),
    );
  }
}

class AssistantNotifier extends StateNotifier<AssistantState> {
  final AssistantDataSource _repository;
  final String Function() _createRequestId;
  StreamSubscription<AssistantChatEvent>? _subscription;
  int _generation = 0;
  String _activeRequestId = '';

  AssistantNotifier({
    required AssistantDataSource repository,
    String Function()? createRequestId,
  }) : _repository = repository,
       _createRequestId = createRequestId ?? _defaultRequestId,
       super(const AssistantState());

  AssistantMode get mode => state.mode;

  /// 切换模式（AGNT-001/FX-052）；流式进行中不允许切换。
  void setMode(AssistantMode next) {
    if (state.mode == next || state.isStreaming) return;
    state = state.copyWith(mode: next, clearAgentAuthorizationRequired: true);
  }

  void addPendingAttachment(PendingChatImage image) {
    if (state.mode != AssistantMode.agent) return;
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

  bool send(String message) {
    final normalized = message.trim();
    if (normalized.isEmpty || normalized.length > 2000 || state.isStreaming) {
      return false;
    }

    final requestId = _createRequestId();
    final generation = ++_generation;
    final responseId = 'assistant-$requestId';
    final mode = state.mode;
    final attachments = state.mode == AssistantMode.agent
        ? state.pendingAttachments
        : const <PendingChatImage>[];
    _activeRequestId = requestId;
    state = state.copyWith(
      messages: [
        ...state.messages,
        AssistantMessage(
          id: 'user-$requestId',
          role: AssistantMessageRole.user,
          text: normalized,
          attachments: [...attachments],
        ),
        AssistantMessage(
          id: responseId,
          role: AssistantMessageRole.assistant,
          text: '',
          isStreaming: true,
        ),
      ],
      isStreaming: true,
      clearConnectionError: true,
      clearPendingAttachments: true,
    );

    final stream = _repository.chat(
      message: normalized,
      requestId: requestId,
      conversationId: state.conversationId,
      mode: mode,
      attachments: [
        for (final item in attachments)
          AssistantAttachment(mediaId: item.mediaId, url: item.url),
      ],
    );
    _subscription = stream.listen(
      (event) {
        if (generation != _generation) return;
        _applyEvent(responseId, event);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation != _generation) return;
        _finishWithTransportError(responseId, friendlyErrorMessage(error));
      },
      onDone: () {
        if (generation != _generation || !state.isStreaming) return;
        _finishWithTransportError(responseId, 'Assistant 连接意外中断');
      },
      cancelOnError: false,
    );
    return true;
  }

  /// 高危操作逐次确认（FX-056/057）：回调服务端并立即把卡片置为不可交互。
  Future<void> respondToConfirmation(String callId, bool approved) async {
    final requestId = _activeRequestId;
    if (!state.isStreaming || requestId.isEmpty) return;
    state = state.copyWith(
      messages: _updateMessage(_responseIdOf(requestId), (message) {
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
      await _repository.confirmTool(
        requestId: requestId,
        callId: callId,
        approved: approved,
      );
    } on ApiException {
      // 卡片已置为已处理；失败结果由后续错误事件或超时语义呈现。
    }
  }

  Future<void> cancel() async {
    if (!state.isStreaming) return;
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    state = state.copyWith(
      messages: _updateLastAssistant(
        (message) => message.copyWith(
          text: message.text.isEmpty ? '已取消' : message.text,
          isStreaming: false,
          isCanceled: true,
        ),
      ),
      isStreaming: false,
      clearConnectionError: true,
    );
  }

  void clear() {
    unawaited(cancel());
    state = AssistantState(mode: state.mode);
  }

  void _applyEvent(String responseId, AssistantChatEvent event) {
    final conversationId = event.conversationId.isEmpty
        ? state.conversationId
        : event.conversationId;
    switch (event.type) {
      case AssistantEventType.token:
        state = state.copyWith(
          conversationId: conversationId,
          messages: _updateMessage(
            responseId,
            (message) => message.copyWith(text: '${message.text}${event.text}'),
          ),
        );
      case AssistantEventType.source:
        state = state.copyWith(
          conversationId: conversationId,
          messages: _updateMessage(responseId, (message) {
            final source = event.source!;
            return message.sources.contains(source)
                ? message
                : message.copyWith(sources: [...message.sources, source]);
          }),
        );
      case AssistantEventType.toolCall:
        state = state.copyWith(
          conversationId: conversationId,
          messages: _updateMessage(responseId, (message) {
            final call = event.toolCall!;
            final existing = message.toolSteps.indexWhere(
              (step) => step.callId == call.callId,
            );
            final steps = [...message.toolSteps];
            final step = AssistantToolStep(
              callId: call.callId,
              tool: call.tool,
              summary: call.summary,
              status: AssistantToolStatus.running,
            );
            if (existing >= 0) {
              steps[existing] = steps[existing].copyWith(status: .running);
            } else {
              steps.add(step);
            }
            return message.copyWith(toolSteps: steps);
          }),
        );
      case AssistantEventType.confirmRequired:
        state = state.copyWith(
          conversationId: conversationId,
          messages: _updateMessage(responseId, (message) {
            final call = event.toolCall!;
            return message.copyWith(
              toolSteps: [
                ...message.toolSteps,
                AssistantToolStep(
                  callId: call.callId,
                  tool: call.tool,
                  summary: call.summary,
                  status: AssistantToolStatus.awaitingConfirmation,
                ),
              ],
            );
          }),
        );
      case AssistantEventType.card:
        if (event.card == null) return;
        state = state.copyWith(
          conversationId: conversationId,
          messages: _updateMessage(
            responseId,
            (message) =>
                message.copyWith(cards: [...message.cards, event.card!]),
          ),
        );
      case AssistantEventType.actions:
        if (event.actions.isEmpty) return;
        state = state.copyWith(
          conversationId: conversationId,
          messages: _updateMessage(
            responseId,
            (message) => message.copyWith(
              actions: [...message.actions, ...event.actions],
            ),
          ),
        );
      case AssistantEventType.watchHit:
        if (event.watchHit == null) return;
        state = state.copyWith(
          conversationId: conversationId,
          messages: _updateMessage(
            responseId,
            (message) => message.copyWith(
              watchHits: [...message.watchHits, event.watchHit!],
            ),
          ),
        );
      case AssistantEventType.unknown:
        return;
      case AssistantEventType.done:
        state = state.copyWith(
          conversationId: conversationId,
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
          ),
          isStreaming: false,
        );
      case AssistantEventType.error:
        final needsAuthorization = event.errorCode == 'AGENT_NOT_AUTHORIZED';
        state = state.copyWith(
          conversationId: conversationId,
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
          ),
          isStreaming: false,
          connectionError: event.text,
        );
    }
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
                ? .completed
                : .failed,
          ),
          // 等待确认的卡片在终止事件后按过期呈现（AGNT-021）。
          AssistantToolStatus.awaitingConfirmation => step.copyWith(
            status: .expired,
          ),
          _ => step,
        },
    ];
  }

  String _responseIdOf(String requestId) => 'assistant-$requestId';

  void _finishWithTransportError(String responseId, String error) {
    state = state.copyWith(
      messages: _updateMessage(
        responseId,
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
      connectionError: error,
    );
  }

  List<AssistantMessage> _updateMessage(
    String id,
    AssistantMessage Function(AssistantMessage) update,
  ) {
    return [
      for (final message in state.messages)
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

/// Agent 能力授权状态（FX-053/054/080）：进入 Agent 模式前查询，同意后记录。
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
