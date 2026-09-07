import '../../../core/api/json_int64.dart';
import '../data/assistant_models.dart';

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
  final AssistantQuestionRequest? questionRequest;
  final AssistantAnswerPresentation? answerPresentation;
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
    this.questionRequest,
    this.answerPresentation,
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
    AssistantQuestionRequest? questionRequest,
    AssistantAnswerPresentation? answerPresentation,
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
      questionRequest: questionRequest ?? this.questionRequest,
      answerPresentation: answerPresentation ?? this.answerPresentation,
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
