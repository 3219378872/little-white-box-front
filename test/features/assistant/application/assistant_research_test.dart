import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';

import '../helpers/fake_assistant_source.dart';

const questions = [
  AssistantQuestion(
    id: 'q',
    text: '优先级？',
    selection: 'single',
    options: [
      AssistantQuestionOption(id: 'a', label: '成本'),
      AssistantQuestionOption(id: 'b', label: '体验'),
    ],
  ),
];
const pending = AssistantQuestionRequest(
  id: 'q1',
  runId: 21,
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
const answers = [
  AssistantQuestionAnswer(questionId: 'q', disposition: 'unknown'),
];
const resolved = AssistantQuestionRequest(
  id: 'q1',
  runId: 21,
  messageId: 31,
  status: 'answered',
  deadlineMs: 4102444800000,
  questions: questions,
  answers: answers,
);
const presentation = AssistantAnswerPresentation(
  messageId: 32,
  runId: 21,
  blocks: [
    AssistantAnswerBlock(id: 'b1', kind: 'limitation', text: '条件未知，保留不同适用情况。'),
  ],
  sources: [],
);

void main() {
  test(
    'waiting response preserves question and failed answers reuse command identity',
    () async {
      final events = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(events.close);
      final source = FakeAssistantSource()
        ..eventsHandler = ({required runId, required afterSeq}) =>
            events.stream;
      var attempts = 0;
      source.answerHandler = (requestId, value) async {
        if (attempts++ == 0) throw const ApiException('网络暂时不可用');
        return resolved;
      };
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);
      await notifier.send('比较方案');
      events.add(
        const AssistantRunEvent(
          type: AssistantEventType.questionsRequired,
          runId: 21,
          seq: 1,
          questionRequest: pending,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.activeRunPhase, 'waiting_input');
      expect(notifier.state.isStreaming, isFalse);
      expect(
        notifier.state.messages.where((item) => item.questionRequest != null),
        hasLength(1),
      );
      expect(await notifier.answerQuestion(pending, answers), isFalse);
      expect(await notifier.answerQuestion(pending, answers), isTrue);
      expect(source.answerRequestIds[0], source.answerRequestIds[1]);
    },
  );

  test('late answer acknowledgement never reopens a completed run', () async {
    final events = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(events.close);
    final acknowledgement = Completer<AssistantQuestionRequest>();
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) => events.stream;
    source.answerHandler = (id, value) => acknowledgement.future;
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.send('比较方案');
    events.add(
      const AssistantRunEvent(
        type: AssistantEventType.questionsRequired,
        runId: 21,
        seq: 1,
        questionRequest: pending,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final submitted = notifier.answerQuestion(pending, answers);
    events.add(
      const AssistantRunEvent(
        type: AssistantEventType.answerCommitted,
        runId: 21,
        seq: 2,
        text: '条件未知，保留不同适用情况。',
        answerPresentation: presentation,
      ),
    );
    events.add(
      const AssistantRunEvent(type: AssistantEventType.done, runId: 21, seq: 3),
    );
    await Future<void>.delayed(Duration.zero);
    acknowledgement.complete(resolved);
    expect(await submitted, isTrue);
    expect(notifier.state.hasActiveRun, isFalse);
    expect(notifier.state.isStreaming, isFalse);
    expect(
      notifier.state.messages.where((item) => item.answerPresentation != null),
      hasLength(1),
    );
    expect(notifier.state.messages.last.answerPresentation, isNotNull);
  });

  test(
    'history and event replay merge by question and answer identities',
    () async {
      final events = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(events.close);
      final source = FakeAssistantSource()
        ..thread = const AssistantThreadSummary(
          sessionId: 1,
          activeRunId: 21,
          activeRunPhase: 'waiting_input',
          questionRequest: pending,
        )
        ..messages = const [
          AssistantHistoryMessage(
            id: 31,
            sessionId: 1,
            runId: 21,
            role: 'assistant',
            kind: 'question',
            questionRequest: resolved,
          ),
          AssistantHistoryMessage(
            id: 32,
            sessionId: 1,
            runId: 21,
            role: 'assistant',
            content: '条件未知',
            answerPresentation: presentation,
          ),
        ]
        ..eventsHandler = ({required runId, required afterSeq}) =>
            events.stream;
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);
      await notifier.load();
      events.add(
        const AssistantRunEvent(
          type: AssistantEventType.runStarted,
          runId: 21,
          seq: 1,
        ),
      );
      events.add(
        const AssistantRunEvent(
          type: AssistantEventType.questionsRequired,
          runId: 21,
          seq: 2,
          questionRequest: pending,
        ),
      );
      events.add(
        const AssistantRunEvent(
          type: AssistantEventType.answerCommitted,
          runId: 21,
          seq: 3,
          text: '条件未知',
          answerPresentation: presentation,
        ),
      );
      events.add(
        const AssistantRunEvent(
          type: AssistantEventType.done,
          runId: 21,
          seq: 4,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        notifier.state.messages.where((item) => item.questionRequest != null),
        hasLength(1),
      );
      expect(
        notifier.state.messages.where(
          (item) => item.answerPresentation != null,
        ),
        hasLength(1),
      );
      expect(notifier.state.messages.first.questionRequest!.status, 'answered');
    },
  );
}
