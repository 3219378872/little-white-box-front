import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';

import '../helpers/fake_assistant_source.dart';

// 运行事件归并的场景表：同一组「初始状态 + 事件序列 → 期望状态」既经由真实
// 连接驱动，也直接喂给纯 reducer，锁定两条路径的行为一致。

const _runId = 21;
const _responseId = 'run-21';
const _sentText = '比较方案';

const _pendingQuestion = AssistantQuestionRequest(
  id: 'q1',
  runId: _runId,
  messageId: 31,
  status: 'pending',
  deadlineMs: 4102444800000,
  questions: [
    AssistantQuestion(
      id: 'q',
      text: '优先级？',
      selection: 'single',
      options: [
        AssistantQuestionOption(id: 'a', label: '成本'),
        AssistantQuestionOption(id: 'b', label: '体验'),
      ],
    ),
  ],
);

final _answeredQuestion = AssistantQuestionRequest(
  id: _pendingQuestion.id,
  runId: _runId,
  messageId: _pendingQuestion.messageId,
  status: 'answered',
  deadlineMs: _pendingQuestion.deadlineMs,
  questions: _pendingQuestion.questions,
  answers: const [
    AssistantQuestionAnswer(questionId: 'q', disposition: 'unknown'),
  ],
);

const _presentation = AssistantAnswerPresentation(
  messageId: 32,
  runId: _runId,
  blocks: [AssistantAnswerBlock(id: 'b1', kind: 'limitation', text: '保留差异。')],
  sources: [],
);

const _source = AssistantSourceCard(
  handle: 'S1',
  kind: 'post',
  authorityId: '501',
  title: '来源',
);

// 场景如何进入运行中：send 走乐观消息 + 新 run；resume 走历史加载后续订。
enum _Start { send, resume }

// 一个可复用的事件序列场景；verify 只断言事件归并负责的字段。
class _RunScenario {
  final String name;
  final _Start start;
  final List<AssistantHistoryMessage> history;
  final List<AssistantRunEvent> events;
  final void Function(AssistantState state, AssistantState initial) verify;

  const _RunScenario(
    this.name, {
    this.start = _Start.send,
    this.history = const [],
    required this.events,
    required this.verify,
  });
}

AssistantRunEvent _token(String text, {int seq = 0, String streamId = ''}) =>
    AssistantRunEvent(
      type: AssistantEventType.token,
      runId: _runId,
      seq: seq,
      text: text,
      streamId: streamId,
    );

AssistantRunEvent _reset(String streamId) => AssistantRunEvent(
  type: AssistantEventType.responseReset,
  runId: _runId,
  streamId: streamId,
);

AssistantRunEvent _tool(
  AssistantEventType type,
  String callId, {
  String summary = '',
}) => AssistantRunEvent(
  type: type,
  runId: _runId,
  toolCall: AssistantToolCall(
    callId: callId,
    tool: 'search_posts',
    summary: summary,
  ),
);

const _done = AssistantRunEvent(type: AssistantEventType.done, runId: _runId);

AssistantMessage _response(AssistantState state) =>
    state.messages.singleWhere((message) => message.id == _responseId);

final _runEventScenarios = <_RunScenario>[
  _RunScenario(
    'run_started and tokens append to one streaming response',
    events: [
      const AssistantRunEvent(
        type: AssistantEventType.runStarted,
        runId: _runId,
        sessionId: 9,
      ),
      _token('Hel'),
      _token('lo'),
    ],
    verify: (state, initial) {
      expect(state.sessionId, 9);
      expect(state.activeRunId, _runId);
      expect(state.activeRunPhase, 'model_request');
      expect(state.isStreaming, isTrue);
      expect(state.isQueued, isFalse);
      expect(state.lastDisposition, isNull);
      expect(_response(state).text, 'Hello');
      expect(_response(state).isStreaming, isTrue);
    },
  ),
  _RunScenario(
    'first stream id owns tokens until reset',
    events: [
      _token('a', streamId: 's1'),
      _token('x', streamId: 's2'),
      _token('', streamId: ''),
      _token('b', streamId: 's1'),
      // 已启用流 ID 后，缺少流 ID 的 token 一律视为陈旧输出。
      _token('stale'),
    ],
    verify: (state, initial) {
      expect(_response(state).text, 'ab');
    },
  ),
  _RunScenario(
    'response_reset clears text and retires the active stream',
    events: [
      _token('draft', streamId: 's1'),
      _reset('s1'),
      _token('late', streamId: 's1'),
      _token('final', streamId: 's2'),
    ],
    verify: (state, initial) {
      expect(_response(state).text, 'final');
      expect(state.isStreaming, isTrue);
    },
  ),
  _RunScenario(
    'response_reset for a non-active stream is ignored',
    events: [
      _token('keep', streamId: 's1'),
      _reset('s2'),
      _reset(''),
    ],
    verify: (state, initial) {
      expect(_response(state).text, 'keep');
    },
  ),
  _RunScenario(
    'tool_call then tool_result upsert one step',
    events: [
      _tool(AssistantEventType.toolCall, 'c1', summary: '搜索中'),
      _tool(AssistantEventType.toolResult, 'c1'),
      _tool(AssistantEventType.toolCall, 'c2', summary: '第二步'),
    ],
    verify: (state, initial) {
      expect(state.activeRunPhase, 'tool_executing');
      final steps = _response(state).toolSteps;
      expect(steps.map((step) => step.callId), ['c1', 'c2']);
      expect(steps[0].status, AssistantToolStatus.completed);
      expect(steps[0].summary, '搜索中');
      expect(steps[1].status, AssistantToolStatus.running);
    },
  ),
  _RunScenario(
    'confirm_required waits for user confirmation',
    events: [_tool(AssistantEventType.confirmRequired, 'c1', summary: '写入记忆')],
    verify: (state, initial) {
      final message = _response(state);
      expect(message.hasPendingConfirmation, isTrue);
      expect(
        message.toolSteps.single.status,
        AssistantToolStatus.awaitingConfirmation,
      );
    },
  ),
  _RunScenario(
    'done settles steps, ends the run and clears transient errors',
    events: [
      _token('答案'),
      _tool(AssistantEventType.toolCall, 'run'),
      _tool(AssistantEventType.confirmRequired, 'confirm'),
      const AssistantRunEvent(
        type: AssistantEventType.done,
        runId: _runId,
        degraded: true,
      ),
    ],
    verify: (state, initial) {
      final message = _response(state);
      expect(message.text, '答案');
      expect(message.isStreaming, isFalse);
      expect(message.degraded, isTrue);
      expect(message.terminalEventReceived, isTrue);
      expect(message.toolSteps.map((step) => step.status), [
        AssistantToolStatus.completed,
        AssistantToolStatus.expired,
      ]);
      expect(state.activeRunId, 0);
      expect(state.activeRunPhase, '');
      expect(state.isStreaming, isFalse);
      expect(state.isQueued, isFalse);
      expect(state.connectionError, isNull);
      expect(state.pendingRetryCommand, isNull);
    },
  ),
  _RunScenario(
    'error keeps partial text, fails running steps and surfaces the error',
    events: [
      _tool(AssistantEventType.toolCall, 'run'),
      const AssistantRunEvent(
        type: AssistantEventType.error,
        runId: _runId,
        text: '模型超时',
        errorCode: 'MODEL_TIMEOUT',
      ),
    ],
    verify: (state, initial) {
      final message = _response(state);
      expect(message.text, '模型超时');
      expect(message.degraded, isTrue);
      expect(message.errorCode, 'MODEL_TIMEOUT');
      expect(message.terminalEventReceived, isTrue);
      expect(message.toolSteps.single.status, AssistantToolStatus.failed);
      expect(state.connectionError, '模型超时');
      expect(state.agentAuthorizationRequired, isFalse);
      expect(state.pendingRetryCommand, isNull);
      expect(state.activeRunId, 0);
      expect(state.isStreaming, isFalse);
    },
  ),
  _RunScenario(
    'error after partial text keeps the streamed text',
    events: [
      _token('部分'),
      const AssistantRunEvent(
        type: AssistantEventType.error,
        runId: _runId,
        text: '模型超时',
      ),
    ],
    verify: (state, initial) {
      expect(_response(state).text, '部分');
    },
  ),
  _RunScenario(
    'unauthorized error keeps the active command for retry',
    events: [
      const AssistantRunEvent(
        type: AssistantEventType.error,
        runId: _runId,
        text: '需要授权',
        errorCode: 'AGENT_NOT_AUTHORIZED',
      ),
    ],
    verify: (state, initial) {
      expect(state.agentAuthorizationRequired, isTrue);
      expect(state.pendingRetryMessage, _sentText);
      expect(state.connectionError, '需要授权');
    },
  ),
  _RunScenario(
    'source cards are de-duplicated on the response',
    events: [
      const AssistantRunEvent(
        type: AssistantEventType.sourceCard,
        runId: _runId,
        sourceCard: _source,
      ),
      const AssistantRunEvent(
        type: AssistantEventType.sourceCard,
        runId: _runId,
        sourceCard: _source,
      ),
      // 缺少卡片内容的事件不应改动回复。
      const AssistantRunEvent(type: AssistantEventType.sourceCard),
    ],
    verify: (state, initial) {
      expect(_response(state).sources, [_source]);
    },
  ),
  _RunScenario(
    'memory_changed appends one system notice per change',
    events: [
      const AssistantRunEvent(
        type: AssistantEventType.memoryChanged,
        runId: _runId,
        seq: 3,
        changeId: 5,
      ),
      const AssistantRunEvent(
        type: AssistantEventType.memoryChanged,
        runId: _runId,
        seq: 4,
        changeId: 5,
        text: '重复',
      ),
    ],
    verify: (state, initial) {
      final notices = state.messages.where((m) => m.isMemoryChanged).toList();
      expect(notices, hasLength(1));
      expect(notices.single.id, 'memory-5-3');
      expect(notices.single.text, '记忆已更新');
      expect(notices.single.role, AssistantMessageRole.system);
    },
  ),
  _RunScenario(
    'questions_required parks the run and drops the empty placeholder',
    events: [
      const AssistantRunEvent(
        type: AssistantEventType.questionsRequired,
        runId: _runId,
        questionRequest: _pendingQuestion,
      ),
    ],
    verify: (state, initial) {
      expect(state.activeRunPhase, 'waiting_input');
      expect(state.isStreaming, isFalse);
      expect(state.messages.any((m) => m.id == _responseId), isFalse);
      final question = state.messages.singleWhere(
        (m) => m.questionRequest != null,
      );
      expect(question.id, '31');
      expect(question.kind, 'question');
    },
  ),
  _RunScenario(
    'questions_required keeps a response that already has text',
    events: [
      _token('先说明'),
      const AssistantRunEvent(
        type: AssistantEventType.questionsRequired,
        runId: _runId,
        questionRequest: _pendingQuestion,
      ),
    ],
    verify: (state, initial) {
      expect(_response(state).text, '先说明');
      expect(_response(state).isStreaming, isFalse);
    },
  ),
  _RunScenario(
    'questions_resolved resumes streaming with a fresh placeholder',
    events: [
      const AssistantRunEvent(
        type: AssistantEventType.questionsRequired,
        runId: _runId,
        questionRequest: _pendingQuestion,
      ),
      AssistantRunEvent(
        type: AssistantEventType.questionsResolved,
        runId: _runId,
        questionRequest: _answeredQuestion,
      ),
    ],
    verify: (state, initial) {
      expect(state.activeRunPhase, 'queued');
      expect(state.isStreaming, isTrue);
      final question = state.messages.singleWhere(
        (m) => m.questionRequest != null,
      );
      expect(question.questionRequest!.status, 'answered');
      expect(_response(state).isStreaming, isTrue);
      expect(_response(state).text, isEmpty);
    },
  ),
  _RunScenario(
    'late pending event does not reopen an answered question',
    events: [
      AssistantRunEvent(
        type: AssistantEventType.questionsResolved,
        runId: _runId,
        questionRequest: _answeredQuestion,
      ),
      const AssistantRunEvent(
        type: AssistantEventType.questionsRequired,
        runId: _runId,
        questionRequest: _pendingQuestion,
      ),
    ],
    verify: (state, initial) {
      final question = state.messages.singleWhere(
        (m) => m.questionRequest != null,
      );
      expect(question.questionRequest!.status, 'answered');
      // 现状：迟到的 pending 仍把阶段切回等待输入并移除空占位。
      expect(state.activeRunPhase, 'waiting_input');
      expect(state.messages.any((m) => m.id == _responseId), isFalse);
    },
  ),
  _RunScenario(
    'questions_resolved alone resumes as queued',
    events: [
      AssistantRunEvent(
        type: AssistantEventType.questionsResolved,
        runId: _runId,
        questionRequest: _answeredQuestion,
      ),
    ],
    verify: (state, initial) {
      expect(state.activeRunPhase, 'queued');
      expect(state.isStreaming, isTrue);
      expect(_response(state).isStreaming, isTrue);
    },
  ),
  _RunScenario(
    'question events for another run are ignored',
    events: [
      const AssistantRunEvent(
        type: AssistantEventType.questionsRequired,
        runId: _runId,
        questionRequest: AssistantQuestionRequest(
          id: 'other',
          runId: 99,
          messageId: 41,
          status: 'pending',
          deadlineMs: 4102444800000,
          questions: [],
        ),
      ),
    ],
    verify: (state, initial) {
      expect(state.messages.any((m) => m.questionRequest != null), isFalse);
      expect(state.activeRunPhase, initial.activeRunPhase);
      expect(state.isStreaming, initial.isStreaming);
    },
  ),
  _RunScenario(
    'answer_committed replaces streamed text and resets stream ids',
    events: [
      _token('草稿', streamId: 's1'),
      const AssistantRunEvent(
        type: AssistantEventType.answerCommitted,
        runId: _runId,
        text: '正式答案',
        answerPresentation: _presentation,
      ),
      // 提交后流跟踪清零，新流 ID 的 token 可以继续追加。
      _token('。', streamId: 's2'),
    ],
    verify: (state, initial) {
      final message = _response(state);
      expect(message.text, '正式答案。');
      expect(message.answerPresentation, same(_presentation));
    },
  ),
  _RunScenario(
    'answer_committed for another run is ignored',
    events: [
      _token('草稿'),
      const AssistantRunEvent(
        type: AssistantEventType.answerCommitted,
        runId: _runId,
        text: '别的答案',
        answerPresentation: AssistantAnswerPresentation(
          messageId: 52,
          runId: 99,
          blocks: [],
          sources: [],
        ),
      ),
    ],
    verify: (state, initial) {
      expect(_response(state).text, '草稿');
      expect(_response(state).answerPresentation, isNull);
    },
  ),
  _RunScenario(
    'answer_committed after resume appends the answer after history',
    start: _Start.resume,
    history: const [
      AssistantHistoryMessage(
        id: 30,
        sessionId: 1,
        runId: _runId,
        role: 'user',
        content: _sentText,
      ),
      AssistantHistoryMessage(
        id: 31,
        sessionId: 1,
        runId: _runId,
        role: 'assistant',
        kind: 'question',
        content: '',
        questionRequest: _pendingQuestion,
      ),
    ],
    events: [
      _token('草稿'),
      const AssistantRunEvent(
        type: AssistantEventType.answerCommitted,
        runId: _runId,
        text: '正式答案',
        answerPresentation: _presentation,
      ),
    ],
    verify: (state, initial) {
      final answer = state.messages.last;
      expect(answer.id, _responseId);
      expect(answer.text, '正式答案');
      expect(answer.isStreaming, isFalse);
      expect(state.messages.map((m) => m.id), ['30', '31', _responseId]);
    },
  ),
  _RunScenario(
    'resumed run applies events to the restored placeholder',
    start: _Start.resume,
    history: const [
      AssistantHistoryMessage(
        id: 30,
        sessionId: 1,
        runId: _runId,
        role: 'user',
        content: _sentText,
      ),
    ],
    events: [_token('续'), _done],
    verify: (state, initial) {
      expect(initial.activeRunId, _runId);
      expect(_response(state).text, '续');
      expect(_response(state).terminalEventReceived, isTrue);
      expect(state.activeRunId, 0);
    },
  ),
  _RunScenario(
    'unknown events leave state untouched',
    events: [
      const AssistantRunEvent(type: AssistantEventType.unknown, runId: _runId),
    ],
    verify: (state, initial) {
      expect(state, same(initial));
    },
  ),
];

// 经由真实 notifier 与连接驱动场景：事件从伪造 SSE 流进入 _listen。
Future<(AssistantState, AssistantState)> _runThroughNotifier(
  _RunScenario scenario,
) async {
  final events = StreamController<AssistantRunEvent>.broadcast();
  final source = FakeAssistantSource()
    ..eventsHandler = ({required runId, required afterSeq}) => events.stream;
  final notifier = AssistantNotifier(
    repository: source,
    createRequestId: () => 'req-1',
  );
  addTearDown(events.close);
  addTearDown(notifier.dispose);
  await _startRun(notifier, source, scenario);
  final initial = notifier.state;
  for (final event in scenario.events) {
    events.add(event);
  }
  await pumpEventQueue();
  return (notifier.state, initial);
}

// 直接喂给纯 reducer：起点仍由 notifier 生成（保证与连接路径同一初始状态），
// 之后不经过连接层，逐个折叠事件。
Future<(AssistantState, AssistantState)> _runThroughReducer(
  _RunScenario scenario,
) async {
  final source = FakeAssistantSource();
  final notifier = AssistantNotifier(
    repository: source,
    createRequestId: () => 'req-1',
  );
  addTearDown(notifier.dispose);
  await _startRun(notifier, source, scenario);
  final initial = notifier.state;
  var reduction = AssistantRunReduction(
    state: initial,
    activeCommand: scenario.start == _Start.send
        ? const PendingAssistantCommand(message: _sentText, requestId: 'req-1')
        : null,
  );
  for (final event in scenario.events) {
    reduction = reduceAssistantRunEvent(reduction, _runId, event);
  }
  return (reduction.state, initial);
}

// 把 notifier 带到「run 已订阅、尚未收到事件」的起点。
Future<void> _startRun(
  AssistantNotifier notifier,
  FakeAssistantSource source,
  _RunScenario scenario,
) async {
  switch (scenario.start) {
    case _Start.send:
      expect(await notifier.send(_sentText), isTrue);
    case _Start.resume:
      source
        ..thread = AssistantThreadSummary(
          sessionId: 1,
          lastMessageId: scenario.history.last.id,
          activeRunId: _runId,
          activeRunPhase: 'model_request',
        )
        ..messages = scenario.history;
      await notifier.load();
  }
  expect(notifier.state.activeRunId, _runId);
}

void main() {
  group('run event sequences via notifier', () {
    for (final scenario in _runEventScenarios) {
      test(scenario.name, () async {
        final (state, initial) = await _runThroughNotifier(scenario);
        scenario.verify(state, initial);
      });
    }
  });

  group('run event sequences via pure reducer', () {
    for (final scenario in _runEventScenarios) {
      test(scenario.name, () async {
        final (state, initial) = await _runThroughReducer(scenario);
        scenario.verify(state, initial);
      });
    }
  });

  group('pure reducer contract', () {
    const streaming = AssistantState(
      sessionId: 1,
      activeRunId: _runId,
      activeRunPhase: 'model_request',
      isStreaming: true,
      messages: [
        AssistantMessage(
          id: _responseId,
          runId: _runId,
          role: AssistantMessageRole.assistant,
          text: '',
          isStreaming: true,
        ),
      ],
    );

    test('rejected events return the same reduction', () {
      const current = AssistantRunReduction(
        state: streaming,
        streams: AssistantStreamTracking(
          activeStreamId: 's1',
          usesStreamIds: true,
        ),
      );
      expect(
        reduceAssistantRunEvent(current, _runId, _reset('s2')),
        same(current),
      );
      expect(
        reduceAssistantRunEvent(
          current,
          _runId,
          const AssistantRunEvent(type: AssistantEventType.unknown),
        ),
        same(current),
      );
    });

    test('reset retires the stream without mutating the input', () {
      final retired = <String>{'s0'};
      final current = AssistantRunReduction(
        state: streaming,
        streams: AssistantStreamTracking(
          activeStreamId: 's1',
          retiredStreamIds: retired,
          usesStreamIds: true,
        ),
      );
      final next = reduceAssistantRunEvent(current, _runId, _reset('s1'));
      expect(next.streams.activeStreamId, isEmpty);
      expect(next.streams.retiredStreamIds, {'s0', 's1'});
      expect(retired, {'s0'});
      expect(current.streams.activeStreamId, 's1');
    });

    test('terminal events clear the run bookkeeping', () {
      const command = PendingAssistantCommand(message: '问', requestId: 'r');
      const current = AssistantRunReduction(
        state: streaming,
        streams: AssistantStreamTracking(
          activeStreamId: 's1',
          usesStreamIds: true,
        ),
        activeCommand: command,
        activeRunFloorMessageId: 30,
      );
      for (final event in [
        _done,
        const AssistantRunEvent(type: AssistantEventType.error, runId: _runId),
      ]) {
        final next = reduceAssistantRunEvent(current, _runId, event);
        expect(next.activeCommand, isNull);
        expect(next.activeRunFloorMessageId, 0);
        expect(next.streams.usesStreamIds, isFalse);
        expect(next.state.activeRunId, 0);
      }
    });

    test('any event clears a disconnected response marker', () {
      final disconnected = streaming.copyWith(
        connectionError: '连接中断',
        messages: [
          streaming.messages.single.copyWith(
            text: '响应中断',
            isStreaming: false,
            degraded: true,
            errorCode: 'STREAM_DISCONNECTED',
          ),
        ],
      );
      final next = reduceAssistantRunEvent(
        AssistantRunReduction(state: disconnected),
        _runId,
        _token('续'),
      );
      final message = _response(next.state);
      expect(message.text, '续');
      expect(message.errorCode, isEmpty);
      expect(message.degraded, isFalse);
      expect(message.isStreaming, isTrue);
      expect(next.state.connectionError, isNull);
    });
  });

  group('run event connection', () {
    test(
      'replayed events after a reconnect are de-duplicated by seq',
      () async {
        final connections = <StreamController<AssistantRunEvent>>[];
        final source = FakeAssistantSource()
          ..eventsHandler = ({required runId, required afterSeq}) {
            final controller = StreamController<AssistantRunEvent>();
            connections.add(controller);
            return controller.stream;
          };
        final notifier = AssistantNotifier(repository: source);
        addTearDown(() async {
          notifier.dispose();
          for (final controller in connections) {
            await controller.close();
          }
        });
        await notifier.send(_sentText);
        connections.last
          ..add(_token('a', seq: 1))
          ..add(_token('b', seq: 2))
          ..addError(const AssistantStreamException('断线'));
        await pumpEventQueue();

        expect(connections, hasLength(2));
        expect(source.lastEventsAfterSeq, 2);
        connections.last
          ..add(_token('a', seq: 1))
          ..add(_token('b', seq: 2))
          ..add(_token('c', seq: 3));
        await pumpEventQueue();

        expect(_response(notifier.state).text, 'abc');
        expect(notifier.state.connectionError, isNull);
      },
    );

    test('next event clears a recovered transport error', () async {
      final connections = <StreamController<AssistantRunEvent>>[];
      final source = FakeAssistantSource()
        ..eventsHandler = ({required runId, required afterSeq}) {
          final controller = StreamController<AssistantRunEvent>();
          connections.add(controller);
          return controller.stream;
        };
      final notifier = AssistantNotifier(repository: source);
      addTearDown(() async {
        notifier.dispose();
        for (final controller in connections) {
          await controller.close();
        }
      });
      await notifier.send(_sentText);
      connections.last.addError(
        const AssistantStreamException('不可重试', retryable: false),
      );
      await pumpEventQueue();

      expect(_response(notifier.state).errorCode, 'STREAM_DISCONNECTED');
      expect(_response(notifier.state).text, '响应中断');
      expect(notifier.state.connectionError, isNotNull);

      expect(notifier.reconnectActiveRun(), isTrue);
      connections.last.add(_token('恢复', seq: 1));
      await pumpEventQueue();

      final message = _response(notifier.state);
      expect(message.errorCode, isEmpty);
      expect(message.degraded, isFalse);
      expect(message.text, '恢复');
      expect(message.isStreaming, isTrue);
      expect(notifier.state.connectionError, isNull);
    });

    test(
      'terminal event closes the subscription and drops later events',
      () async {
        final events = StreamController<AssistantRunEvent>.broadcast();
        addTearDown(events.close);
        final source = FakeAssistantSource()
          ..eventsHandler = ({required runId, required afterSeq}) =>
              events.stream;
        final notifier = AssistantNotifier(repository: source);
        addTearDown(notifier.dispose);
        await notifier.send(_sentText);
        events
          ..add(_token('完', seq: 1))
          ..add(
            const AssistantRunEvent(
              type: AssistantEventType.done,
              runId: _runId,
              seq: 2,
            ),
          )
          ..add(_token('迟到', seq: 3));
        await pumpEventQueue();

        expect(_response(notifier.state).text, '完');
        expect(notifier.state.activeRunId, 0);
      },
    );
  });
}
