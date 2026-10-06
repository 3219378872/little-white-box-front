part of 'assistant_notifier.dart';

/// 流 ID 跟踪：记录当前输出中的 streamId 与已被 response_reset 作废的 streamId，
/// 让重试/重置后的陈旧 token 不会拼进新回复。
class AssistantStreamTracking {
  final String activeStreamId;
  final Set<String> retiredStreamIds;
  // 一旦见过带 streamId 的事件，就不再接受缺少 streamId 的 token。
  final bool usesStreamIds;

  const AssistantStreamTracking({
    this.activeStreamId = '',
    this.retiredStreamIds = const {},
    this.usesStreamIds = false,
  });

  /// 新 run、终止事件或答案提交后的初始跟踪状态。
  static const idle = AssistantStreamTracking();
}

/// run 事件 reducer 的输入与输出：界面状态加上会被事件改写的运行簿记
/// （流跟踪、可重试命令、活动 run 的历史下限），供 notifier 整体回写。
class AssistantRunReduction {
  final AssistantState state;
  final AssistantStreamTracking streams;
  // 授权失败时转为 pendingRetryCommand，供用户授权后原样重发。
  final PendingAssistantCommand? activeCommand;
  final Object activeRunFloorMessageId;

  const AssistantRunReduction({
    required this.state,
    this.streams = AssistantStreamTracking.idle,
    this.activeCommand,
    this.activeRunFloorMessageId = 0,
  });

  AssistantRunReduction copyWith({
    AssistantState? state,
    AssistantStreamTracking? streams,
    PendingAssistantCommand? activeCommand,
    bool clearActiveCommand = false,
    Object? activeRunFloorMessageId,
  }) {
    return AssistantRunReduction(
      state: state ?? this.state,
      streams: streams ?? this.streams,
      activeCommand: clearActiveCommand
          ? null
          : (activeCommand ?? this.activeCommand),
      activeRunFloorMessageId:
          activeRunFloorMessageId ?? this.activeRunFloorMessageId,
    );
  }

  // 终止事件结束 run：清空流跟踪、活动命令与历史下限。
  AssistantRunReduction _endRun(AssistantState state) => AssistantRunReduction(
    state: state,
    streams: AssistantStreamTracking.idle,
    activeRunFloorMessageId: 0,
  );
}

/// 纯 reducer：把订阅 [runId] 时收到的一个 [event] 归并进 [current]。
///
/// 只做状态变换；seq 去重、订阅收尾、重连计时与网络请求都留在连接层。
AssistantRunReduction reduceAssistantRunEvent(
  AssistantRunReduction current,
  Object runId,
  AssistantRunEvent event,
) {
  // 过滤：按流 ID 丢弃陈旧 token/reset，被拒事件只可能改写流跟踪。
  final (accepted, streams) = _acceptRunEvent(current.streams, event);
  if (!accepted) {
    return identical(streams, current.streams)
        ? current
        : current.copyWith(streams: streams);
  }
  var reduction = current.copyWith(streams: streams);
  final responseId = 'run-${jsonInt64Id(runId)}';
  final sessionId = jsonInt64IsPositive(event.sessionId)
      ? event.sessionId
      : current.state.sessionId;
  // 恢复：断线标记过的回复在收到任何新事件时撤销「响应中断」。
  var state = _clearRecoveredTransportError(
    reduction.state,
    responseId,
    runId,
    event.isTerminal,
  );
  reduction = reduction.copyWith(state: state);

  switch (event.type) {
    case AssistantEventType.runStarted:
      state = state.copyWith(
        sessionId: sessionId,
        activeRunId: runId,
        activeRunPhase: 'model_request',
        clearLastDisposition: true,
        isQueued: false,
        isStreaming: true,
        messages: _ensureAssistantIn(state.messages, responseId, runId),
      );
    case AssistantEventType.token:
      state = state.copyWith(
        sessionId: sessionId,
        activeRunPhase: 'model_request',
        clearLastDisposition: true,
        messages: _updateResponseMessage(
          state.messages,
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
        messages: _clearResetResponse(state.messages, responseId, runId),
        isStreaming: true,
        isQueued: false,
      );
    case AssistantEventType.toolCall:
      state = state.copyWith(
        sessionId: sessionId,
        activeRunPhase: 'tool_executing',
        clearLastDisposition: true,
        messages: _upsertTool(
          state.messages,
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
          state.messages,
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
          state.messages,
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
          state.messages,
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
        messages: _upsertMemoryChangedEvent(state.messages, runId, event),
      );
    case AssistantEventType.questionsRequired:
    case AssistantEventType.questionsResolved:
      final question = event.questionRequest;
      // 迟到的 pending 不得重开已离开 pending 的问题，也不改阶段与占位。
      if (question == null ||
          !_sameRun(question.runId, runId) ||
          _isStalePendingQuestion(state.messages, question)) {
        return reduction;
      }
      state = _applyQuestion(state, question, responseId, runId, sessionId);
    case AssistantEventType.answerCommitted:
      final answer = event.answerPresentation;
      if (answer == null || !_sameRun(answer.runId, runId)) return reduction;
      // 答案落库后旧草稿流全部作废，后续 token 按新流重新认领。
      reduction = reduction.copyWith(streams: AssistantStreamTracking.idle);
      state = state.copyWith(
        sessionId: sessionId,
        messages: _answerMessages(
          state.messages,
          responseId,
          answer,
          event.text,
        ),
      );
    case AssistantEventType.unknown:
      return reduction;
    case AssistantEventType.done:
      return reduction._endRun(
        state.copyWith(
          sessionId: sessionId,
          messages: _updateResponseMessage(
            state.messages,
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
        ),
      );
    case AssistantEventType.error:
      // 仅授权失败保留原命令，用户授权后可原样重发；其他错误不自动重试。
      final needsAuthorization = event.errorCode == 'AGENT_NOT_AUTHORIZED';
      final retryCommand = needsAuthorization ? reduction.activeCommand : null;
      return reduction._endRun(
        state.copyWith(
          sessionId: sessionId,
          agentAuthorizationRequired: needsAuthorization,
          messages: _updateResponseMessage(
            state.messages,
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
        ),
      );
  }
  return reduction.copyWith(state: state);
}

// 问题事件：pending 时暂停流并移除仅含提问步骤的空占位；已回答/被取代时
// 恢复占位并回到排队阶段等待服务端续跑。
AssistantState _applyQuestion(
  AssistantState state,
  AssistantQuestionRequest question,
  String responseId,
  Object runId,
  Object sessionId,
) {
  var messages = _questionMessages(state.messages, question);
  final resumes =
      question.status == 'answered' || question.status == 'superseded';
  if (question.isPending) {
    messages = [
      for (final message in messages)
        if (!(message.id == responseId &&
            message.text.isEmpty &&
            message.sources.isEmpty &&
            message.toolSteps.every((step) => step.tool == 'ask_questions')))
          message.id == responseId
              ? message.copyWith(isStreaming: false)
              : message,
    ];
  } else if (resumes) {
    messages = _ensureAssistantIn(messages, responseId, runId);
  }
  return state.copyWith(
    sessionId: sessionId,
    messages: messages,
    isStreaming: resumes,
    activeRunPhase: resumes ? 'queued' : 'waiting_input',
  );
}

// 判断事件是否参与归并，并返回可能更新后的流跟踪。
(bool, AssistantStreamTracking) _acceptRunEvent(
  AssistantStreamTracking streams,
  AssistantRunEvent event,
) {
  return switch (event.type) {
    AssistantEventType.token => _acceptToken(streams, event),
    AssistantEventType.responseReset => _acceptReset(streams, event),
    AssistantEventType.sourceCard => (event.sourceCard != null, streams),
    AssistantEventType.unknown => (false, streams),
    _ => (true, streams),
  };
}

// token：首个 streamId 认领输出，作废或不同的 streamId 被丢弃；
// 已启用流 ID 后，缺少 streamId 的 token 视为旧协议残留。
(bool, AssistantStreamTracking) _acceptToken(
  AssistantStreamTracking streams,
  AssistantRunEvent event,
) {
  final streamId = event.streamId.trim();
  if (streamId.isEmpty) return (!streams.usesStreamIds, streams);
  final using = AssistantStreamTracking(
    activeStreamId: streams.activeStreamId,
    retiredStreamIds: streams.retiredStreamIds,
    usesStreamIds: true,
  );
  if (streams.retiredStreamIds.contains(streamId)) return (false, using);
  if (streams.activeStreamId.isEmpty) {
    return (
      true,
      AssistantStreamTracking(
        activeStreamId: streamId,
        retiredStreamIds: streams.retiredStreamIds,
        usesStreamIds: true,
      ),
    );
  }
  return (streams.activeStreamId == streamId, using);
}

// response_reset：只认当前输出流，作废后等待下一个 streamId 认领。
(bool, AssistantStreamTracking) _acceptReset(
  AssistantStreamTracking streams,
  AssistantRunEvent event,
) {
  final streamId = event.streamId.trim();
  if (streamId.isEmpty || streams.activeStreamId != streamId) {
    return (false, streams);
  }
  return (
    true,
    AssistantStreamTracking(
      retiredStreamIds: {...streams.retiredStreamIds, streamId},
      usesStreamIds: true,
    ),
  );
}

// 断线后续订成功：撤销 STREAM_DISCONNECTED 标记与占位文案，并清掉连接错误。
AssistantState _clearRecoveredTransportError(
  AssistantState state,
  String responseId,
  Object runId,
  bool terminal,
) {
  var recovered = false;
  final messages = _updateResponseMessage(state.messages, responseId, runId, (
    message,
  ) {
    if (message.errorCode != 'STREAM_DISCONNECTED') return message;
    recovered = true;
    return message.copyWith(
      text: message.text == '响应中断' ? '' : message.text,
      isStreaming: !terminal,
      degraded: false,
      errorCode: '',
    );
  }, matchPersistedTerminal: true);
  if (!recovered) return state;
  return state.copyWith(messages: messages, clearConnectionError: true);
}
