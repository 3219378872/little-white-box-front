import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';

import '../helpers/fake_assistant_source.dart';

void main() {
  test('assembles tokens, source cards, and terminal state', () async {
    final controller = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(controller.close);
    final repository = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) => controller.stream;
    final notifier = AssistantNotifier(
      repository: repository,
      createRequestId: () => 'request-1',
    );

    expect(await notifier.send('hello'), isTrue);
    controller.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: 'Answer',
        sessionId: 1,
        seq: 1,
      ),
    );
    controller.add(
      const AssistantRunEvent(
        type: AssistantEventType.sourceCard,
        sourceCard: AssistantSourceCard(
          handle: 'src-7',
          kind: 'post',
          authorityId: '7',
          title: 'Source',
        ),
        sessionId: 1,
        seq: 2,
      ),
    );
    controller.add(
      const AssistantRunEvent(
        type: AssistantEventType.done,
        sessionId: 1,
        seq: 3,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final answer = notifier.state.messages.last;
    expect(answer.text, 'Answer');
    expect(answer.sources.single.authorityId, '7');
    expect(answer.isStreaming, isFalse);
    expect(notifier.state.isStreaming, isFalse);
    expect(repository.lastPostedMessage, 'hello');
  });

  test('stop marks the response and cancels the run', () async {
    final canceled = Completer<void>();
    final controller = StreamController<AssistantRunEvent>(
      onCancel: () {
        if (!canceled.isCompleted) canceled.complete();
      },
    );
    addTearDown(controller.close);
    final repository = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) => controller.stream;
    final notifier = AssistantNotifier(
      repository: repository,
      createRequestId: () => 'request-1',
    );

    await notifier.send('hello');
    controller.add(
      const AssistantRunEvent(type: AssistantEventType.token, text: 'partial'),
    );
    await Future<void>.delayed(Duration.zero);
    await notifier.stop();

    expect(notifier.state.isStreaming, isFalse);
    expect(notifier.state.messages.last.isCanceled, isTrue);
    expect(notifier.state.messages.last.text, 'partial');
    expect(repository.lastCancelRunId, 21);
    await expectLater(canceled.future, completes);
  });

  test('a disconnected stream reconnects then becomes a transport error', () async {
    final repository = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) {
        return Stream<AssistantRunEvent>.fromIterable(const [
          AssistantRunEvent(type: AssistantEventType.token, text: 'partial', seq: 1),
        ]);
      };
    final notifier = AssistantNotifier(
      repository: repository,
      createRequestId: () => 'request-1',
    );

    await notifier.send('hello');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.isStreaming, isFalse);
    expect(notifier.state.connectionError, contains('中断'));
    expect(notifier.state.messages.last.errorCode, 'STREAM_DISCONNECTED');
    expect(repository.eventCalls, isNotEmpty);
  });
}
