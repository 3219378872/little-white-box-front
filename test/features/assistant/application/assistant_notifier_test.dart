import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';

import '../helpers/fake_assistant_source.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('assembles tokens, source cards, and terminal state', () async {
    final controller = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(controller.close);
    final repository = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) =>
          controller.stream;
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

  test(
    'response reset replaces partial text and retires the old stream',
    () async {
      final controller = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(controller.close);
      final repository = FakeAssistantSource()
        ..eventsHandler = ({required runId, required afterSeq}) =>
            controller.stream;
      final notifier = AssistantNotifier(
        repository: repository,
        createRequestId: () => 'request-1',
      );

      expect(await notifier.send('hello'), isTrue);
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'discard me',
          streamId: 'attempt-1',
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
          seq: 2,
        ),
      );
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.responseReset,
          streamId: 'attempt-1',
          seq: 3,
        ),
      );
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'late old text',
          streamId: 'attempt-1',
          seq: 4,
        ),
      );
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'final answer',
          streamId: 'attempt-2',
          seq: 5,
        ),
      );
      controller.add(
        const AssistantRunEvent(type: AssistantEventType.done, seq: 6),
      );
      await pumpEventQueue();

      final assistants = notifier.state.messages
          .where((message) => message.role == AssistantMessageRole.assistant)
          .toList();
      expect(assistants, hasLength(1));
      final answer = assistants.single;
      expect(answer.id, 'run-21');
      expect(answer.text, 'final answer');
      expect(answer.text, isNot(contains('discard me')));
      expect(answer.text, isNot(contains('late old text')));
      expect(answer.sources.single.authorityId, '7');
      expect(answer.isStreaming, isFalse);
    },
  );

  test(
    'response reset discards text idempotently for the same stream',
    () async {
      final controller = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(controller.close);
      final repository = FakeAssistantSource()
        ..eventsHandler = ({required runId, required afterSeq}) =>
            controller.stream;
      final notifier = AssistantNotifier(
        repository: repository,
        createRequestId: () => 'request-1',
      );

      expect(await notifier.send('hello'), isTrue);
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'kept answer',
          streamId: 'attempt-1',
          seq: 1,
        ),
      );
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.responseReset,
          streamId: 'attempt-1',
          seq: 2,
        ),
      );
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.responseReset,
          streamId: 'attempt-1',
          seq: 3,
        ),
      );
      await pumpEventQueue();

      final assistants = notifier.state.messages
          .where((message) => message.role == AssistantMessageRole.assistant)
          .toList();
      expect(assistants, hasLength(1));
      expect(assistants.single.id, 'run-21');
      expect(assistants.single.text, isEmpty);
    },
  );

  test(
    'a different stream is ignored until the active stream is reset',
    () async {
      final controller = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(controller.close);
      final repository = FakeAssistantSource()
        ..eventsHandler = ({required runId, required afterSeq}) =>
            controller.stream;
      final notifier = AssistantNotifier(repository: repository);

      expect(await notifier.send('hello'), isTrue);
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'A',
          streamId: 'attempt-1',
          seq: 1,
        ),
      );
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'wrong',
          streamId: 'attempt-2',
          seq: 2,
        ),
      );
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'B',
          streamId: 'attempt-1',
          seq: 3,
        ),
      );
      controller.add(
        const AssistantRunEvent(type: AssistantEventType.done, seq: 4),
      );
      await pumpEventQueue();

      expect(notifier.state.messages.last.text, 'AB');
    },
  );

  test('legacy tokens without stream ids remain compatible', () async {
    final controller = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(controller.close);
    final repository = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) =>
          controller.stream;
    final notifier = AssistantNotifier(repository: repository);

    expect(await notifier.send('hello'), isTrue);
    controller.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: 'legacy ',
        seq: 1,
      ),
    );
    controller.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: 'answer',
        seq: 2,
      ),
    );
    controller.add(
      const AssistantRunEvent(type: AssistantEventType.done, seq: 3),
    );
    await pumpEventQueue();

    expect(notifier.state.messages.last.text, 'legacy answer');
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
      ..eventsHandler = ({required runId, required afterSeq}) =>
          controller.stream;
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

  test(
    'a disconnected stream reconnects then becomes a transport error',
    () async {
      final repository = FakeAssistantSource()
        ..eventsHandler = ({required runId, required afterSeq}) {
          return Stream<AssistantRunEvent>.fromIterable(const [
            AssistantRunEvent(
              type: AssistantEventType.token,
              text: 'partial',
              seq: 1,
            ),
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
    },
  );

  test(
    'account changes rebuild Assistant state and cancel the old SSE',
    () async {
      final canceled = Completer<void>();
      final controller = StreamController<AssistantRunEvent>.broadcast(
        onCancel: () {
          if (!canceled.isCompleted) canceled.complete();
        },
      );
      addTearDown(controller.close);
      final source = FakeAssistantSource()
        ..eventsHandler = ({required runId, required afterSeq}) =>
            controller.stream;
      final container = ProviderContainer(
        overrides: [assistantRepositoryProvider.overrideWithValue(source)],
      );
      addTearDown(container.dispose);
      final listener = container.listen(
        assistantNotifierProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(listener.close);
      await pumpEventQueue();

      final auth = container.read(authNotifierProvider.notifier);
      await auth.onLoginSuccess(1, 'user-1-token');
      final first = container.read(assistantNotifierProvider.notifier);
      first.addPendingAttachment(
        const PendingChatImage(mediaId: 7, url: 'https://media/7'),
      );
      expect(await first.send('user one private text'), isTrue);
      await container
          .read(agentConsentNotifierProvider.notifier)
          .ensureLoaded();
      expect(container.read(agentConsentNotifierProvider).loaded, isTrue);

      await auth.onLoginSuccess(2, 'user-2-token');
      final second = container.read(assistantNotifierProvider.notifier);
      expect(identical(first, second), isFalse);
      expect(container.read(assistantNotifierProvider).messages, isEmpty);
      expect(
        container.read(assistantNotifierProvider).pendingAttachments,
        isEmpty,
      );
      expect(container.read(agentConsentNotifierProvider).loaded, isFalse);
      await expectLater(canceled.future, completes);

      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'old account token',
          seq: 1,
        ),
      );
      await pumpEventQueue();
      expect(container.read(assistantNotifierProvider).messages, isEmpty);

      await auth.logout();
      final signedOut = container.read(assistantNotifierProvider.notifier);
      expect(identical(second, signedOut), isFalse);
      expect(container.read(assistantNotifierProvider).messages, isEmpty);
    },
  );

  test(
    'account change stops a stale load before the history request',
    () async {
      final delayedThread = Completer<AssistantThreadSummary>();
      final source = FakeAssistantSource()
        ..threadHandler = () => delayedThread.future;
      final container = ProviderContainer(
        overrides: [assistantRepositoryProvider.overrideWithValue(source)],
      );
      addTearDown(container.dispose);
      final listener = container.listen(
        assistantNotifierProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(listener.close);
      await pumpEventQueue();
      final auth = container.read(authNotifierProvider.notifier);

      await auth.onLoginSuccess(1, 'user-1-token');
      final first = container.read(assistantNotifierProvider.notifier);
      final staleLoad = first.load();
      await pumpEventQueue();
      await auth.onLoginSuccess(2, 'user-2-token');
      final second = container.read(assistantNotifierProvider.notifier);
      expect(identical(first, second), isFalse);

      delayedThread.complete(
        const AssistantThreadSummary(sessionId: 1, lastMessageId: 9),
      );
      await staleLoad;

      expect(source.listMessageCalls, 0);
      expect(container.read(assistantNotifierProvider).messages, isEmpty);
    },
  );

  test(
    'redirect and queue keep one run subscription and reject replayed seq',
    () async {
      final controller = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(controller.close);
      var posts = 0;
      final source = FakeAssistantSource()
        ..postHandler =
            ({
              required message,
              required requestId,
              required attachments,
              required contextPostId,
            }) async {
              posts++;
              return AssistantPostResult(
                messageId: 10 + posts,
                sessionId: 1,
                runId: 21,
                disposition: switch (posts) {
                  1 => AssistantDisposition.started,
                  2 => AssistantDisposition.redirected,
                  _ => AssistantDisposition.queued,
                },
              );
            }
        ..eventsHandler = ({required runId, required afterSeq}) =>
            controller.stream;
      var request = 0;
      final notifier = AssistantNotifier(
        repository: source,
        createRequestId: () => 'request-${++request}',
      );

      expect(await notifier.send('first'), isTrue);
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'A',
          seq: 4,
        ),
      );
      await pumpEventQueue();
      expect(await notifier.send('redirect'), isTrue);
      expect(await notifier.send('queue'), isTrue);
      expect(source.eventCalls, [0]);

      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'replayed',
          seq: 4,
        ),
      );
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'B',
          seq: 5,
        ),
      );
      await pumpEventQueue();
      final replies = notifier.state.messages.where(
        (item) => item.role == AssistantMessageRole.assistant,
      );
      expect(replies, hasLength(1));
      expect(replies.single.text, 'AB');
    },
  );

  test('old onDone cannot fail the connection opened by onError', () async {
    final first = StreamController<AssistantRunEvent>();
    final second = StreamController<AssistantRunEvent>();
    addTearDown(first.close);
    addTearDown(second.close);
    var calls = 0;
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) {
        calls++;
        return calls == 1 ? first.stream : second.stream;
      };
    final notifier = AssistantNotifier(repository: source);
    expect(await notifier.send('hello'), isTrue);
    first.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: 'A',
        seq: 1,
      ),
    );
    await pumpEventQueue();
    first.addError(const AssistantStreamException('connection dropped'));
    await pumpEventQueue();
    expect(source.eventCalls, [0, 1]);

    await first.close();
    await pumpEventQueue();
    second.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: 'duplicate',
        seq: 1,
      ),
    );
    second.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: 'B',
        seq: 2,
      ),
    );
    second.add(const AssistantRunEvent(type: AssistantEventType.done, seq: 3));
    await pumpEventQueue();

    expect(notifier.state.messages.last.text, 'AB');
    expect(notifier.state.connectionError, isNull);
    expect(notifier.state.isStreaming, isFalse);
  });
}
