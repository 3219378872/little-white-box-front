import '../../../core/api/json_int64.dart';
import '../data/assistant_models.dart';

/// 会话气泡的角色；system 用于记忆变更等系统提示。
enum AssistantMessageRole { user, assistant, system }

/// 工具步骤的生命周期：running 结束为 completed/failed；需确认的调用经
/// awaitingConfirmation → confirming 落为 confirmed/declined，run 结束时仍未
/// 确认则为 expired。
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

/// 回复气泡内展示的一步工具调用。
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

/// 已上传、等待随下一条消息发送的图片；[thumbnailUrl] 只用于界面预览。
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

/// 一次发送命令的快照；[requestId] 在重试之间保持不变，保证服务端幂等。
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

  /// 用户重发同一文本与上下文时复用本命令（及其 requestId）。
  bool matches(String message, Object contextPostId) {
    return this.message == message &&
        jsonInt64Id(this.contextPostId) == jsonInt64Id(contextPostId);
  }
}

/// 会话页的一条消息：已持久化消息用数字 ID，乐观用户消息为
/// `user-<requestId>`，流式回复占位为 `run-<runId>`，记忆变更提示为
/// `memory-<changeId>-<seq>`。
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

  /// 事件流已送达 done/error 或本地已取消，持久化对账时据此保留错误标记。
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

  /// 有工具调用正在等待用户确认。
  bool get hasPendingConfirmation => toolSteps.any(
    (step) => step.status == AssistantToolStatus.awaitingConfirmation,
  );

  /// 记忆变更系统提示，可撤销。
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

/// Assistant 会话页状态：历史分页、活跃 run 的流式进度、发送中的命令与错误。
class AssistantState {
  final Object sessionId;
  final Object activeRunId;

  /// 服务端 run 阶段：queued、model_request、tool_executing、waiting_input 等。
  final String activeRunPhase;

  /// 最近一次发送的处置结果，run 开始处理或结束后清除。
  final AssistantDisposition? lastDisposition;
  final List<AssistantMessage> messages;
  final bool isStreaming;
  final bool isSending;

  /// 当前 run 或新消息仍在排队，尚未开始处理。
  final bool isQueued;
  final String? connectionError;
  final List<PendingChatImage> pendingAttachments;

  /// 服务端以 AGENT_NOT_AUTHORIZED 拒绝，需要用户先授权。
  final bool agentAuthorizationRequired;

  /// 在途或失败、可原样重发的命令：发送成功后清除，run 因未授权失败时恢复。
  final PendingAssistantCommand? pendingRetryCommand;
  final bool isLoaded;
  final bool isLoadingHistory;
  final bool hasMoreHistory;

  /// 向前翻页的游标；[hasMoreHistory] 为 false 时无意义。
  final Object nextBeforeId;
  final bool isLoadingOlder;

  /// 加载更早历史失败的错误，独立于 [connectionError]。
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

  /// 当前跟随着一个未结束的 run（含排队与等待作答）。
  bool get hasActiveRun => jsonInt64IsPositive(activeRunId);

  /// 发送请求不在途即可再发；活跃 run 期间如何处置由服务端决定。
  bool get canSend => !isSending;

  /// 待重试命令的文本，没有时为空串。
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
