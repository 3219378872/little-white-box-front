import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';

void main() {
  test('assembles tokens, sources, and terminal state', () async {
    final controller = StreamController<AssistantChatEvent>();
    addTearDown(controller.close);
    final repository = _AssistantSource(controller.stream);
    final notifier = AssistantNotifier(
      repository: repository,
      createRequestId: () => 'request-1',
    );

    expect(notifier.send('hello'), isTrue);
    controller.add(
      const AssistantChatEvent(
        type: AssistantEventType.token,
        text: 'Answer',
        conversationId: 'conversation-1',
      ),
    );
    controller.add(
      const AssistantChatEvent(
        type: AssistantEventType.source,
        source: AssistantSourceReference(
          sourceType: 'post',
          sourceId: '7',
          title: 'Source',
        ),
        conversationId: 'conversation-1',
      ),
    );
    controller.add(
      const AssistantChatEvent(
        type: AssistantEventType.done,
        conversationId: 'conversation-1',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final answer = notifier.state.messages.last;
    expect(answer.text, 'Answer');
    expect(answer.sources.single.sourceId, '7');
    expect(answer.isStreaming, isFalse);
    expect(notifier.state.conversationId, 'conversation-1');
    expect(notifier.state.isStreaming, isFalse);
  });

  test('cancel marks the response and cancels the source stream', () async {
    final canceled = Completer<void>();
    final controller = StreamController<AssistantChatEvent>(
      onCancel: () {
        if (!canceled.isCompleted) canceled.complete();
      },
    );
    addTearDown(controller.close);
    final notifier = AssistantNotifier(
      repository: _AssistantSource(controller.stream),
      createRequestId: () => 'request-1',
    );

    notifier.send('hello');
    controller.add(
      const AssistantChatEvent(type: AssistantEventType.token, text: 'partial'),
    );
    await Future<void>.delayed(Duration.zero);
    await notifier.cancel();

    expect(notifier.state.isStreaming, isFalse);
    expect(notifier.state.messages.last.isCanceled, isTrue);
    expect(notifier.state.messages.last.text, 'partial');
    await expectLater(canceled.future, completes);
  });

  test('a disconnected stream becomes a visible transport error', () async {
    final controller = StreamController<AssistantChatEvent>();
    final notifier = AssistantNotifier(
      repository: _AssistantSource(controller.stream),
      createRequestId: () => 'request-1',
    );

    notifier.send('hello');
    await controller.close();
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.isStreaming, isFalse);
    expect(notifier.state.connectionError, contains('中断'));
    expect(notifier.state.messages.last.errorCode, 'STREAM_DISCONNECTED');
  });
}

class _AssistantSource implements AssistantDataSource {
  final Stream<AssistantChatEvent> stream;

  _AssistantSource(this.stream);

  @override
  Stream<AssistantChatEvent> chat({
    required String message,
    required String requestId,
    String conversationId = '',
  }) => stream;
}
