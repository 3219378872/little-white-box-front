import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/api/json_int64.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';

import '../helpers/fake_assistant_source.dart';

void main() {
  test(
    'full history load fences message submission until it completes',
    () async {
      final thread = Completer<AssistantThreadSummary>();
      final source = FakeAssistantSource()..threadHandler = () => thread.future;
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);

      final load = notifier.load();
      await pumpEventQueue();

      expect(notifier.state.isLoadingHistory, isTrue);
      expect(await notifier.send('must wait for history'), isFalse);
      expect(source.postedRequestIds, isEmpty);
      await notifier.clearHistory();
      expect(source.historyDeletes, 0);
      expect(notifier.state.isLoadingHistory, isTrue);

      thread.complete(const AssistantThreadSummary(sessionId: 1));
      await load;
      expect(notifier.state.isLoadingHistory, isFalse);
      expect(notifier.state.isLoaded, isTrue);
    },
  );

  test(
    'clear history excludes send and reload until deletion completes',
    () async {
      final deletion = Completer<void>();
      final source = FakeAssistantSource()
        ..messages = const [
          AssistantHistoryMessage(
            id: 1,
            sessionId: 1,
            role: 'assistant',
            content: 'existing history',
          ),
        ]
        ..deleteHistoryHandler = () => deletion.future;
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);
      await notifier.load();
      final initialListCalls = source.listMessageCalls;

      final clear = notifier.clearHistory();
      await pumpEventQueue();
      expect(notifier.state.isLoadingHistory, isTrue);
      expect(source.historyDeletes, 1);
      expect(await notifier.send('must wait for deletion'), isFalse);
      await notifier.load();
      expect(source.listMessageCalls, initialListCalls);
      expect(
        await notifier.refreshForThread(
          const AssistantThreadSummary(sessionId: 2, lastMessageId: 2),
        ),
        isFalse,
      );

      deletion.complete();
      await clear;
      expect(notifier.state.isLoaded, isTrue);
      expect(notifier.state.isLoadingHistory, isFalse);
      expect(notifier.state.messages, isEmpty);
      expect(source.postedRequestIds, isEmpty);
    },
  );

  test('failed clear history restores the existing usable state', () async {
    final source = FakeAssistantSource()
      ..messages = const [
        AssistantHistoryMessage(
          id: 1,
          sessionId: 1,
          role: 'assistant',
          content: 'existing history',
        ),
      ]
      ..deleteHistoryHandler = () async {
        throw const ApiException('清除失败');
      };
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();

    await notifier.clearHistory();
    expect(notifier.state.isLoaded, isTrue);
    expect(notifier.state.isLoadingHistory, isFalse);
    expect(notifier.state.messages.single.text, 'existing history');
    expect(notifier.state.connectionError, '清除失败');
    expect(await notifier.send('loading must not stay stuck'), isTrue);
  });

  test(
    'failed run cancellation aborts clear and releases its busy state',
    () async {
      final events = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(events.close);
      final source = FakeAssistantSource();
      source.eventsHandler = ({required runId, required afterSeq}) =>
          events.stream;
      source.cancelError = const ApiException('取消失败');
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);
      expect(await notifier.send('active run'), isTrue);
      final messagesBeforeClear = notifier.state.messages;

      await notifier.clearHistory();
      expect(source.historyDeletes, 0);
      expect(notifier.state.isLoadingHistory, isFalse);
      expect(notifier.state.hasActiveRun, isTrue);
      expect(notifier.state.messages, same(messagesBeforeClear));
      expect(notifier.state.connectionError, '取消失败');
    },
  );

  test('failed full reload resets an invalidated older-page spinner', () async {
    final source = FakeAssistantSource()
      ..thread = const AssistantThreadSummary(sessionId: 1, lastMessageId: 51)
      ..messages = [
        for (var id = 1; id <= 51; id++)
          AssistantHistoryMessage(
            id: id,
            sessionId: 1,
            role: 'assistant',
            content: 'message $id',
          ),
      ];
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();
    expect(notifier.state.hasMoreHistory, isTrue);

    final olderPage = Completer<AssistantMessagePage>();
    source.listMessagesHandler =
        ({
          required sessionId,
          required afterId,
          required beforeId,
          required limit,
        }) => olderPage.future;
    final older = notifier.loadOlderMessages();
    await pumpEventQueue();
    expect(notifier.state.isLoadingOlder, isTrue);

    source.lastError = const ApiException('刷新失败');
    await notifier.load();
    expect(notifier.state.isLoadingHistory, isFalse);
    expect(notifier.state.isLoadingOlder, isFalse);
    expect(notifier.state.connectionError, '刷新失败');

    olderPage.complete(const AssistantMessagePage());
    expect(await older, isFalse);
    expect(notifier.state.isLoadingOlder, isFalse);
  });

  test('session-changing refresh waits for an in-flight send', () async {
    final response = Completer<AssistantPostResult>();
    final source = FakeAssistantSource()
      ..postHandler =
          ({
            required message,
            required requestId,
            required attachments,
            required contextPostId,
          }) => response.future;
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();
    final initialListCalls = source.listMessageCalls;

    final send = notifier.send('keep optimistic message');
    await pumpEventQueue();
    expect(notifier.state.isSending, isTrue);
    expect(notifier.state.messages.single.text, 'keep optimistic message');

    source
      ..thread = const AssistantThreadSummary(sessionId: 2, lastMessageId: 11)
      ..messages = const [
        AssistantHistoryMessage(
          id: 11,
          sessionId: 2,
          role: 'assistant',
          content: 'new session message',
        ),
      ];

    expect(await notifier.refreshForThread(source.thread), isFalse);
    expect(source.listMessageCalls, initialListCalls);
    expect(notifier.state.messages.single.text, 'keep optimistic message');

    response.complete(
      const AssistantPostResult(
        messageId: 10,
        sessionId: 1,
        runId: 20,
        disposition: AssistantDisposition.unknown,
      ),
    );
    expect(await send, isTrue);
    expect(notifier.state.messages.first.text, 'keep optimistic message');

    expect(await notifier.refreshForThread(source.thread), isTrue);
    expect(notifier.state.messages.single.text, 'new session message');
  });

  test('same-session refresh merges safely while send is in flight', () async {
    final response = Completer<AssistantPostResult>();
    final source = FakeAssistantSource()
      ..postHandler =
          ({
            required message,
            required requestId,
            required attachments,
            required contextPostId,
          }) => response.future;
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();

    final send = notifier.send('keep optimistic message');
    await pumpEventQueue();
    source.messages = const [
      AssistantHistoryMessage(
        id: 11,
        sessionId: 1,
        role: 'assistant',
        kind: 'watch',
        content: 'concurrent Watch message',
      ),
      AssistantHistoryMessage(
        id: 12,
        sessionId: 1,
        role: 'user',
        content: 'keep optimistic message',
      ),
    ];

    expect(
      await notifier.refreshForThread(
        const AssistantThreadSummary(sessionId: 1, lastMessageId: 12),
      ),
      isTrue,
    );
    expect(
      notifier.state.messages.any((message) => message.id.startsWith('user-')),
      isTrue,
    );
    expect(
      notifier.state.messages.any(
        (message) => message.text == 'concurrent Watch message',
      ),
      isTrue,
    );

    response.complete(
      const AssistantPostResult(
        messageId: 12,
        sessionId: 1,
        runId: 20,
        disposition: AssistantDisposition.unknown,
      ),
    );
    expect(await send, isTrue);
    expect(
      notifier.state.messages.where((message) => message.id == '12'),
      hasLength(1),
    );
    expect(
      notifier.state.messages.any((message) => message.id.startsWith('user-')),
      isFalse,
    );
    expect(
      notifier.state.messages.any(
        (message) => message.text == 'concurrent Watch message',
      ),
      isTrue,
    );
    expect(
      notifier.state.messages
          .where((message) => message.id == '11' || message.id == '12')
          .map((message) => message.id),
      ['11', '12'],
    );
  });

  test(
    'send preserves a same-session refresh that was already in flight',
    () async {
      final page = Completer<AssistantMessagePage>();
      final response = Completer<AssistantPostResult>();
      final source = FakeAssistantSource()
        ..postHandler =
            ({
              required message,
              required requestId,
              required attachments,
              required contextPostId,
            }) => response.future;
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);
      await notifier.load();
      source.listMessagesHandler =
          ({
            required sessionId,
            required afterId,
            required beforeId,
            required limit,
          }) => page.future;

      final refresh = notifier.refreshForThread(
        const AssistantThreadSummary(sessionId: 1, lastMessageId: 11),
      );
      await pumpEventQueue();
      final send = notifier.send('keep optimistic message');
      await pumpEventQueue();
      expect(notifier.state.isSending, isTrue);

      response.complete(
        const AssistantPostResult(
          messageId: 12,
          sessionId: 1,
          runId: 20,
          disposition: AssistantDisposition.unknown,
        ),
      );
      expect(await send, isTrue);
      page.complete(
        const AssistantMessagePage(
          messages: [
            AssistantHistoryMessage(
              id: 11,
              sessionId: 1,
              role: 'assistant',
              kind: 'watch',
              content: 'refresh completed after send',
            ),
          ],
        ),
      );
      expect(await refresh, isTrue);
      expect(
        notifier.state.messages
            .where((message) => message.id == '11' || message.id == '12')
            .map((message) => message.id),
        ['11', '12'],
      );
      expect(
        notifier.state.messages.any(
          (message) => message.text == 'refresh completed after send',
        ),
        isTrue,
      );
    },
  );

  test('a session-changing send discards an older session refresh', () async {
    final page = Completer<AssistantMessagePage>();
    final source = FakeAssistantSource();
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();
    source.listMessagesHandler =
        ({
          required sessionId,
          required afterId,
          required beforeId,
          required limit,
        }) => page.future;
    source.postHandler =
        ({
          required message,
          required requestId,
          required attachments,
          required contextPostId,
        }) async => const AssistantPostResult(
          messageId: 10,
          sessionId: 2,
          runId: 20,
          disposition: AssistantDisposition.unknown,
        );

    final refresh = notifier.refreshForThread(
      const AssistantThreadSummary(sessionId: 1, lastMessageId: 9),
    );
    await pumpEventQueue();
    expect(await notifier.send('move to the new session'), isTrue);
    expect(notifier.state.sessionId, 2);

    page.complete(
      const AssistantMessagePage(
        messages: [
          AssistantHistoryMessage(
            id: 9,
            sessionId: 1,
            role: 'assistant',
            content: 'stale session message',
          ),
        ],
      ),
    );
    expect(await refresh, isFalse);
    expect(
      notifier.state.messages.any(
        (message) => message.text == 'stale session message',
      ),
      isFalse,
    );
  });

  test('post acceptance does not advance past a failed history gap', () async {
    final pendingPage = Completer<AssistantMessagePage>();
    final source = FakeAssistantSource()
      ..thread = const AssistantThreadSummary(sessionId: 1, lastMessageId: 10)
      ..messages = const [
        AssistantHistoryMessage(
          id: 10,
          sessionId: 1,
          role: 'assistant',
          content: 'loaded watermark',
        ),
      ];
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();
    source.listMessagesHandler =
        ({
          required sessionId,
          required afterId,
          required beforeId,
          required limit,
        }) => pendingPage.future;
    source.postHandler =
        ({
          required message,
          required requestId,
          required attachments,
          required contextPostId,
        }) async => const AssistantPostResult(
          messageId: 12,
          sessionId: 1,
          runId: 20,
          disposition: AssistantDisposition.unknown,
        );

    final failedRefresh = notifier.refreshForThread(
      const AssistantThreadSummary(sessionId: 1, lastMessageId: 11),
    );
    await pumpEventQueue();
    expect(await notifier.send('message after the gap'), isTrue);
    pendingPage.completeError(const ApiException('增量失败'));
    expect(await failedRefresh, isFalse);

    final callsBeforeRetry = source.listMessageCalls;
    source
      ..listMessagesHandler = null
      ..messages = const [
        AssistantHistoryMessage(
          id: 10,
          sessionId: 1,
          role: 'assistant',
          content: 'loaded watermark',
        ),
        AssistantHistoryMessage(
          id: 11,
          sessionId: 1,
          role: 'assistant',
          kind: 'watch',
          content: 'message inside the gap',
        ),
        AssistantHistoryMessage(
          id: 12,
          sessionId: 1,
          role: 'user',
          content: 'message after the gap',
        ),
      ];
    expect(
      await notifier.refreshForThread(
        const AssistantThreadSummary(sessionId: 1, lastMessageId: 12),
      ),
      isTrue,
    );
    expect(source.listMessageCalls, callsBeforeRetry + 1);
    expect(
      notifier.state.messages.where((message) => message.id == '12'),
      hasLength(1),
    );
    expect(
      notifier.state.messages.any(
        (message) => message.text == 'message inside the gap',
      ),
      isTrue,
    );
  });

  test(
    'persisted reply replaces the same-run partial and advances the cursor',
    () async {
      final events = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(events.close);
      final source = FakeAssistantSource()
        ..eventsHandler = ({required runId, required afterSeq}) =>
            events.stream;
      final notifier = AssistantNotifier(
        repository: source,
        createRequestId: () => 'request-1',
      );
      addTearDown(notifier.dispose);
      await notifier.load();

      expect(await notifier.send('hello'), isTrue);
      events.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'partial',
          streamId: 'attempt-1',
          seq: 1,
        ),
      );
      events.add(
        const AssistantRunEvent(
          type: AssistantEventType.sourceCard,
          sourceCard: AssistantSourceCard(
            handle: 'source-7',
            kind: 'post',
            authorityId: '7',
            title: 'source title',
          ),
          seq: 2,
        ),
      );
      await pumpEventQueue();

      source.messages = const [
        AssistantHistoryMessage(
          id: 11,
          sessionId: 1,
          runId: 21,
          role: 'user',
          content: 'hello',
        ),
        AssistantHistoryMessage(
          id: 12,
          sessionId: 1,
          runId: 21,
          role: 'assistant',
          kind: 'tool',
          content: 'tool preamble',
        ),
        AssistantHistoryMessage(
          id: 13,
          sessionId: 1,
          runId: 21,
          role: 'assistant',
          kind: 'message',
          content: 'authoritative final answer',
        ),
      ];
      expect(
        await notifier.refreshForThread(
          const AssistantThreadSummary(sessionId: 1, lastMessageId: 13),
        ),
        isTrue,
      );

      final replies = notifier.state.messages.where(
        (message) => message.role == AssistantMessageRole.assistant,
      );
      expect(replies, hasLength(2));
      expect(replies.map((message) => message.id), ['12', '13']);
      expect(replies.map((message) => message.text), [
        'tool preamble',
        'authoritative final answer',
      ]);
      expect(replies.last.runId, 21);
      expect(replies.last.sources.single.handle, 'source-7');
      expect(replies.last.isStreaming, isFalse);
      expect(notifier.state.hasActiveRun, isFalse);

      events.add(
        const AssistantRunEvent(type: AssistantEventType.done, seq: 3),
      );
      await pumpEventQueue();
      expect(notifier.state.hasActiveRun, isFalse);

      source.messages = [
        ...source.messages,
        const AssistantHistoryMessage(
          id: 14,
          sessionId: 1,
          role: 'assistant',
          kind: 'watch',
          content: 'later message',
        ),
      ];
      expect(
        await notifier.refreshForThread(
          const AssistantThreadSummary(sessionId: 1, lastMessageId: 14),
        ),
        isTrue,
      );
      expect(source.listMessageAfterIds.last, 13);
      expect(notifier.state.messages.last.id, '14');
    },
  );

  test(
    'reply completed before POST returns stays single and terminal',
    () async {
      final response = Completer<AssistantPostResult>();
      final source = FakeAssistantSource()
        ..postHandler =
            ({
              required message,
              required requestId,
              required attachments,
              required contextPostId,
            }) => response.future;
      final notifier = AssistantNotifier(
        repository: source,
        createRequestId: () => 'request-1',
      );
      addTearDown(notifier.dispose);
      await notifier.load();

      final send = notifier.send('hello');
      await pumpEventQueue();
      source.messages = const [
        AssistantHistoryMessage(
          id: 11,
          sessionId: 1,
          role: 'user',
          content: 'hello',
        ),
        AssistantHistoryMessage(
          id: 12,
          sessionId: 1,
          runId: 21,
          role: 'assistant',
          kind: 'tool',
          content: 'tool preamble',
        ),
        AssistantHistoryMessage(
          id: 13,
          sessionId: 1,
          runId: 21,
          role: 'assistant',
          kind: 'message',
          content: 'already completed',
        ),
      ];
      expect(
        await notifier.refreshForThread(
          const AssistantThreadSummary(sessionId: 1, lastMessageId: 13),
        ),
        isTrue,
      );

      response.complete(
        const AssistantPostResult(
          messageId: 11,
          sessionId: 1,
          runId: 21,
          disposition: AssistantDisposition.queued,
        ),
      );
      expect(await send, isTrue);

      final replies = notifier.state.messages.where(
        (message) => message.role == AssistantMessageRole.assistant,
      );
      expect(replies, hasLength(2));
      expect(replies.map((message) => message.id), ['12', '13']);
      expect(replies.map((message) => message.text), [
        'tool preamble',
        'already completed',
      ]);
      expect(notifier.state.hasActiveRun, isFalse);
      expect(notifier.state.isStreaming, isFalse);
      expect(notifier.state.isQueued, isFalse);
      expect(source.eventCalls, isEmpty);
    },
  );

  test('terminal SSE before POST returns cannot reactivate the run', () async {
    final events = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(events.close);
    final response = Completer<AssistantPostResult>();
    final source = FakeAssistantSource()
      ..thread = const AssistantThreadSummary(
        sessionId: 1,
        lastMessageId: 10,
        activeRunId: 21,
        activeRunStatus: 'running',
        activeRunPhase: 'model_request',
      )
      ..messages = const [
        AssistantHistoryMessage(
          id: 10,
          sessionId: 1,
          role: 'user',
          content: 'original question',
        ),
      ];
    source.eventsHandler = ({required runId, required afterSeq}) =>
        events.stream;
    source.postHandler =
        ({
          required message,
          required requestId,
          required attachments,
          required contextPostId,
        }) => response.future;
    final notifier = AssistantNotifier(
      repository: source,
      createRequestId: () => 'request-2',
    );
    addTearDown(notifier.dispose);
    await notifier.load();

    final send = notifier.send('late steering command');
    await pumpEventQueue();
    events.add(
      const AssistantRunEvent(
        type: AssistantEventType.done,
        degraded: true,
        seq: 1,
      ),
    );
    await pumpEventQueue();
    response.complete(
      const AssistantPostResult(
        messageId: 11,
        sessionId: 1,
        runId: 21,
        disposition: AssistantDisposition.steered,
      ),
    );

    expect(await send, isTrue);
    expect(notifier.state.hasActiveRun, isFalse);
    expect(notifier.state.isStreaming, isFalse);
    expect(notifier.state.lastDisposition, isNull);
    expect(source.lastEventsRunId, 21);
    expect(source.eventCalls, [0]);
    final responseMessage = notifier.state.messages.singleWhere(
      (message) => message.id == 'run-21',
    );
    expect(responseMessage.terminalEventReceived, isTrue);
    expect(responseMessage.degraded, isTrue);
  });

  test('Stop before POST returns cannot reactivate the canceled run', () async {
    final events = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(events.close);
    final response = Completer<AssistantPostResult>();
    final source = FakeAssistantSource()
      ..thread = const AssistantThreadSummary(
        sessionId: 1,
        lastMessageId: 10,
        activeRunId: 21,
        activeRunStatus: 'running',
        activeRunPhase: 'model_request',
      )
      ..messages = const [
        AssistantHistoryMessage(
          id: 10,
          sessionId: 1,
          role: 'user',
          content: 'original question',
        ),
      ];
    source.eventsHandler = ({required runId, required afterSeq}) =>
        events.stream;
    source.postHandler =
        ({
          required message,
          required requestId,
          required attachments,
          required contextPostId,
        }) => response.future;
    final notifier = AssistantNotifier(
      repository: source,
      createRequestId: () => 'request-2',
    );
    addTearDown(notifier.dispose);
    await notifier.load();

    final send = notifier.send('late steering command');
    await pumpEventQueue();
    expect(await notifier.stop(), isTrue);
    response.complete(
      const AssistantPostResult(
        messageId: 11,
        sessionId: 1,
        runId: 21,
        disposition: AssistantDisposition.redirected,
      ),
    );

    expect(await send, isTrue);
    expect(notifier.state.hasActiveRun, isFalse);
    expect(notifier.state.isStreaming, isFalse);
    expect(source.lastEventsRunId, 21);
    expect(source.eventCalls, [0]);
    final responseMessage = notifier.state.messages.singleWhere(
      (message) => message.id == 'run-21',
    );
    expect(responseMessage.terminalEventReceived, isTrue);
    expect(responseMessage.isCanceled, isTrue);
  });

  test('completed replacement run fences the previous run stream', () async {
    final oldStreamCanceled = Completer<void>();
    final oldEvents = StreamController<AssistantRunEvent>.broadcast(
      onCancel: () {
        if (!oldStreamCanceled.isCompleted) oldStreamCanceled.complete();
      },
    );
    addTearDown(oldEvents.close);
    final response = Completer<AssistantPostResult>();
    final source = FakeAssistantSource()
      ..thread = const AssistantThreadSummary(
        sessionId: 1,
        lastMessageId: 10,
        activeRunId: 21,
        activeRunStatus: 'running',
        activeRunPhase: 'model_request',
      )
      ..messages = const [
        AssistantHistoryMessage(
          id: 10,
          sessionId: 1,
          role: 'user',
          content: 'old question',
        ),
      ];
    source.eventsHandler = ({required runId, required afterSeq}) =>
        oldEvents.stream;
    source.postHandler =
        ({
          required message,
          required requestId,
          required attachments,
          required contextPostId,
        }) => response.future;
    final notifier = AssistantNotifier(
      repository: source,
      createRequestId: () => 'request-2',
    );
    addTearDown(notifier.dispose);
    await notifier.load();

    final send = notifier.send('replacement question');
    await pumpEventQueue();
    source.messages = const [
      AssistantHistoryMessage(
        id: 10,
        sessionId: 1,
        role: 'user',
        content: 'old question',
      ),
      AssistantHistoryMessage(
        id: 11,
        sessionId: 1,
        runId: 21,
        role: 'assistant',
        kind: 'message',
        content: 'old answer',
      ),
      AssistantHistoryMessage(
        id: 12,
        sessionId: 1,
        role: 'user',
        content: 'replacement question',
      ),
      AssistantHistoryMessage(
        id: 13,
        sessionId: 1,
        runId: 22,
        role: 'assistant',
        kind: 'message',
        content: 'replacement answer',
      ),
    ];
    expect(
      await notifier.refreshForThread(
        const AssistantThreadSummary(sessionId: 1, lastMessageId: 13),
      ),
      isTrue,
    );

    response.complete(
      const AssistantPostResult(
        messageId: 12,
        sessionId: 1,
        runId: 22,
        disposition: AssistantDisposition.started,
      ),
    );
    expect(await send, isTrue);
    await expectLater(oldStreamCanceled.future, completes);
    final beforeLateEvent = notifier.state.messages;
    oldEvents.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: 'late old token',
        seq: 1,
      ),
    );
    await pumpEventQueue();

    expect(notifier.state.messages, same(beforeLateEvent));
    expect(notifier.state.hasActiveRun, isFalse);
    expect(
      notifier.state.messages.where((message) => message.id == '12'),
      hasLength(1),
    );
    expect(
      notifier.state.messages.any((message) => message.id.startsWith('user-')),
      isFalse,
    );
  });

  test('queued disposition clears when token processing begins', () async {
    final events = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(events.close);
    final source = FakeAssistantSource();
    source.postHandler =
        ({
          required message,
          required requestId,
          required attachments,
          required contextPostId,
        }) async => const AssistantPostResult(
          messageId: 11,
          sessionId: 1,
          runId: 21,
          disposition: AssistantDisposition.queued,
        );
    source.eventsHandler = ({required runId, required afterSeq}) =>
        events.stream;
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();

    expect(await notifier.send('queued question'), isTrue);
    expect(notifier.state.isQueued, isTrue);
    expect(notifier.state.lastDisposition, AssistantDisposition.queued);

    events.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: 'started',
        seq: 1,
      ),
    );
    await pumpEventQueue();
    expect(notifier.state.isQueued, isFalse);
    expect(notifier.state.lastDisposition, isNull);
    expect(notifier.state.activeRunPhase, 'model_request');
  });

  test(
    'queued disposition survives preparation phases until model request',
    () async {
      final events = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(events.close);
      final source = FakeAssistantSource();
      source.postHandler =
          ({
            required message,
            required requestId,
            required attachments,
            required contextPostId,
          }) async => const AssistantPostResult(
            messageId: 11,
            sessionId: 1,
            runId: 21,
            disposition: AssistantDisposition.queued,
          );
      source.eventsHandler = ({required runId, required afterSeq}) =>
          events.stream;
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);
      await notifier.load();

      expect(await notifier.send('queued question'), isTrue);
      expect(notifier.state.isQueued, isTrue);
      expect(notifier.state.lastDisposition, AssistantDisposition.queued);

      for (final phase in const ['compact', 'attachment']) {
        expect(
          await notifier.refreshForThread(
            AssistantThreadSummary(
              sessionId: 1,
              activeRunId: 21,
              activeRunStatus: 'running',
              activeRunPhase: phase,
            ),
          ),
          isTrue,
        );
        expect(notifier.state.activeRunPhase, phase);
        expect(notifier.state.isQueued, isTrue);
        expect(notifier.state.lastDisposition, AssistantDisposition.queued);
      }

      expect(
        await notifier.refreshForThread(
          const AssistantThreadSummary(
            sessionId: 1,
            activeRunId: 21,
            activeRunStatus: 'running',
            activeRunPhase: 'model_request',
          ),
        ),
        isTrue,
      );
      expect(notifier.state.activeRunPhase, 'model_request');
      expect(notifier.state.isQueued, isFalse);
      expect(notifier.state.lastDisposition, isNull);
    },
  );

  test('restored active run Stop only cancels its placeholder', () async {
    final events = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(events.close);
    final source = FakeAssistantSource()
      ..thread = const AssistantThreadSummary(
        sessionId: 1,
        lastMessageId: 9,
        activeRunId: 21,
        activeRunStatus: 'running',
        activeRunPhase: 'model_request',
      )
      ..messages = const [
        AssistantHistoryMessage(
          id: 8,
          sessionId: 1,
          runId: 20,
          role: 'assistant',
          content: 'previous answer',
        ),
        AssistantHistoryMessage(
          id: 9,
          sessionId: 1,
          role: 'user',
          content: 'active question',
        ),
        AssistantHistoryMessage(
          id: 10,
          sessionId: 1,
          runId: 21,
          role: 'assistant',
          kind: 'tool',
          content: 'persisted tool preamble',
        ),
      ]
      ..eventsHandler = ({required runId, required afterSeq}) => events.stream;
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);

    await notifier.load();
    expect(await notifier.stop(), isTrue);

    final previous = notifier.state.messages.singleWhere(
      (message) => message.id == '8',
    );
    final tool = notifier.state.messages.singleWhere(
      (message) => message.id == '10',
    );
    final canceled = notifier.state.messages.singleWhere(
      (message) => message.id == 'run-21',
    );
    expect(previous.text, 'previous answer');
    expect(previous.isCanceled, isFalse);
    expect(tool.text, 'persisted tool preamble');
    expect(tool.isCanceled, isFalse);
    expect(canceled.text, '已取消');
    expect(canceled.isCanceled, isTrue);
    expect(canceled.isStreaming, isFalse);
    expect(source.lastCancelRunId, 21);
  });

  test(
    'restored active run connection failures only degrade its placeholder',
    () async {
      final source = FakeAssistantSource()
        ..thread = const AssistantThreadSummary(
          sessionId: 1,
          lastMessageId: 9,
          activeRunId: 21,
          activeRunStatus: 'running',
          activeRunPhase: 'model_request',
        )
        ..messages = const [
          AssistantHistoryMessage(
            id: 8,
            sessionId: 1,
            runId: 20,
            role: 'assistant',
            content: 'previous answer',
          ),
          AssistantHistoryMessage(
            id: 9,
            sessionId: 1,
            role: 'user',
            content: 'active question',
          ),
          AssistantHistoryMessage(
            id: 10,
            sessionId: 1,
            runId: 21,
            role: 'assistant',
            kind: 'tool',
            content: 'persisted tool preamble',
          ),
        ]
        ..eventsHandler = ({required runId, required afterSeq}) =>
            Stream<AssistantRunEvent>.error(
              const AssistantStreamException('connection failed'),
            );
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);

      await notifier.load();
      await pumpEventQueue();

      final previous = notifier.state.messages.singleWhere(
        (message) => message.id == '8',
      );
      final tool = notifier.state.messages.singleWhere(
        (message) => message.id == '10',
      );
      final failed = notifier.state.messages.singleWhere(
        (message) => message.id == 'run-21',
      );
      expect(previous.text, 'previous answer');
      expect(previous.degraded, isFalse);
      expect(previous.errorCode, isEmpty);
      expect(tool.text, 'persisted tool preamble');
      expect(tool.degraded, isFalse);
      expect(tool.errorCode, isEmpty);
      expect(failed.text, '响应中断');
      expect(failed.degraded, isTrue);
      expect(failed.errorCode, 'STREAM_DISCONNECTED');
      expect(source.eventCalls, [0, 0]);
    },
  );

  test('concurrent message refreshes coalesce and drain once', () async {
    final firstPage = Completer<AssistantMessagePage>();
    final source = FakeAssistantSource();
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();
    final initialCalls = source.listMessageCalls;
    var incrementalCalls = 0;
    source.listMessagesHandler =
        ({
          required sessionId,
          required afterId,
          required beforeId,
          required limit,
        }) {
          incrementalCalls++;
          if (incrementalCalls == 1) return firstPage.future;
          return Future.value(const AssistantMessagePage());
        };
    const thread = AssistantThreadSummary(sessionId: 1, lastMessageId: 2);

    final first = notifier.refreshForThread(thread);
    await pumpEventQueue();
    final second = notifier.refreshForThread(thread);
    final third = notifier.refreshForThread(thread);
    await pumpEventQueue();
    expect(source.listMessageCalls, initialCalls + 1);

    firstPage.complete(
      const AssistantMessagePage(
        messages: [
          AssistantHistoryMessage(
            id: 2,
            sessionId: 1,
            role: 'assistant',
            kind: 'watch',
            content: 'coalesced update',
          ),
        ],
      ),
    );
    expect(await Future.wait([first, second, third]), everyElement(isTrue));
    expect(source.listMessageCalls, initialCalls + 2);
    expect(notifier.state.messages.single.text, 'coalesced update');
  });

  test('coalesced refresh reports a failure from its final drain', () async {
    final firstPage = Completer<AssistantMessagePage>();
    final source = FakeAssistantSource();
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();
    var incrementalCalls = 0;
    source.listMessagesHandler =
        ({
          required sessionId,
          required afterId,
          required beforeId,
          required limit,
        }) {
          incrementalCalls++;
          if (incrementalCalls == 1) return firstPage.future;
          throw const ApiException('final drain failed');
        };

    final first = notifier.refreshMessages();
    await pumpEventQueue();
    final joined = notifier.refreshMessages();
    firstPage.complete(
      const AssistantMessagePage(
        messages: [
          AssistantHistoryMessage(
            id: 2,
            sessionId: 1,
            role: 'assistant',
            kind: 'watch',
            content: 'first drain update',
          ),
        ],
      ),
    );

    expect(await Future.wait([first, joined]), everyElement(isFalse));
    expect(incrementalCalls, 2);
    expect(notifier.state.messages.single.text, 'first drain update');
    expect(notifier.state.connectionError, 'final drain failed');
  });

  test(
    'restored run rejects a stale thread and waits for its terminal event',
    () async {
      final events = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(events.close);
      final source = FakeAssistantSource()
        ..thread = const AssistantThreadSummary(
          sessionId: 1,
          lastMessageId: 10,
          activeRunId: 21,
          activeRunStatus: 'running',
          activeRunPhase: 'model_request',
        )
        ..messages = const [
          AssistantHistoryMessage(
            id: 9,
            sessionId: 1,
            runId: 20,
            role: 'assistant',
            content: 'previous answer',
          ),
          AssistantHistoryMessage(
            id: 10,
            sessionId: 1,
            role: 'user',
            content: 'active question',
          ),
        ]
        ..eventsHandler = ({required runId, required afterSeq}) =>
            events.stream;
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);
      await notifier.load();

      expect(
        await notifier.refreshForThread(
          const AssistantThreadSummary(sessionId: 1, lastMessageId: 9),
        ),
        isFalse,
      );
      expect(notifier.state.activeRunId, 21);
      expect(notifier.state.isStreaming, isTrue);

      expect(
        await notifier.refreshForThread(
          const AssistantThreadSummary(sessionId: 1, lastMessageId: 10),
        ),
        isFalse,
      );
      expect(notifier.state.hasActiveRun, isTrue);

      events.add(
        const AssistantRunEvent(type: AssistantEventType.done, seq: 1),
      );
      await pumpEventQueue();
      expect(notifier.state.hasActiveRun, isFalse);
      expect(notifier.state.isStreaming, isFalse);
      expect(
        notifier.state.messages
            .singleWhere((message) => message.id == '9')
            .text,
        'previous answer',
      );
    },
  );

  test('failed terminal history refresh keeps the active SSE usable', () async {
    final events = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(events.close);
    final source = FakeAssistantSource()
      ..thread = const AssistantThreadSummary(
        sessionId: 1,
        lastMessageId: 10,
        activeRunId: 21,
        activeRunStatus: 'running',
        activeRunPhase: 'model_request',
      )
      ..messages = const [
        AssistantHistoryMessage(
          id: 10,
          sessionId: 1,
          role: 'user',
          content: 'active question',
        ),
      ]
      ..eventsHandler = ({required runId, required afterSeq}) => events.stream;
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();
    source.listMessagesHandler =
        ({
          required sessionId,
          required afterId,
          required beforeId,
          required limit,
        }) async => throw const ApiException('history unavailable');

    expect(
      await notifier.refreshForThread(
        const AssistantThreadSummary(sessionId: 1, lastMessageId: 11),
      ),
      isFalse,
    );
    expect(notifier.state.hasActiveRun, isTrue);
    expect(notifier.state.isStreaming, isTrue);
    expect(notifier.state.connectionError, 'history unavailable');

    events.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: 'still connected',
        seq: 1,
      ),
    );
    await pumpEventQueue();
    expect(
      notifier.state.messages
          .singleWhere((message) => message.id == 'run-21')
          .text,
      'still connected',
    );
    events.add(const AssistantRunEvent(type: AssistantEventType.done, seq: 2));
    await pumpEventQueue();
    expect(notifier.state.connectionError, isNull);
  });

  test('successful incremental history clears its previous error', () async {
    final source = FakeAssistantSource()
      ..thread = const AssistantThreadSummary(sessionId: 1, lastMessageId: 1)
      ..messages = const [
        AssistantHistoryMessage(
          id: 1,
          sessionId: 1,
          role: 'assistant',
          content: 'existing',
        ),
      ];
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();
    source.listMessagesHandler =
        ({
          required sessionId,
          required afterId,
          required beforeId,
          required limit,
        }) async => throw const ApiException('history unavailable');

    const updatedThread = AssistantThreadSummary(
      sessionId: 1,
      lastMessageId: 2,
    );
    expect(await notifier.refreshForThread(updatedThread), isFalse);
    expect(notifier.state.connectionError, 'history unavailable');

    source.listMessagesHandler =
        ({
          required sessionId,
          required afterId,
          required beforeId,
          required limit,
        }) async => const AssistantMessagePage(
          messages: [
            AssistantHistoryMessage(
              id: 2,
              sessionId: 1,
              role: 'assistant',
              kind: 'watch',
              content: 'recovered update',
            ),
          ],
        );

    expect(await notifier.refreshForThread(updatedThread), isTrue);
    expect(notifier.state.connectionError, isNull);
    expect(notifier.state.messages.last.text, 'recovered update');
  });

  test(
    'successful empty incremental history clears its previous error',
    () async {
      final source = FakeAssistantSource()
        ..thread = const AssistantThreadSummary(sessionId: 1, lastMessageId: 1)
        ..messages = const [
          AssistantHistoryMessage(
            id: 1,
            sessionId: 1,
            role: 'assistant',
            content: 'existing',
          ),
        ];
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);
      await notifier.load();
      source.listMessagesHandler =
          ({
            required sessionId,
            required afterId,
            required beforeId,
            required limit,
          }) async => throw const ApiException('history unavailable');

      const updatedThread = AssistantThreadSummary(
        sessionId: 1,
        lastMessageId: 2,
      );
      expect(await notifier.refreshForThread(updatedThread), isFalse);
      expect(notifier.state.connectionError, 'history unavailable');

      source.listMessagesHandler =
          ({
            required sessionId,
            required afterId,
            required beforeId,
            required limit,
          }) async => const AssistantMessagePage();

      expect(await notifier.refreshForThread(updatedThread), isTrue);
      expect(notifier.state.connectionError, isNull);
      expect(notifier.state.messages.single.text, 'existing');
    },
  );

  test(
    'same-run thread refresh resumes a disconnected stream from its cursor',
    () async {
      final first = StreamController<AssistantRunEvent>();
      final automaticRetry = StreamController<AssistantRunEvent>();
      final refreshed = StreamController<AssistantRunEvent>();
      addTearDown(first.close);
      addTearDown(automaticRetry.close);
      addTearDown(refreshed.close);
      var calls = 0;
      final source = FakeAssistantSource()
        ..thread = const AssistantThreadSummary(
          sessionId: 1,
          activeRunId: 21,
          activeRunStatus: 'running',
          activeRunPhase: 'model_request',
        )
        ..eventsHandler = ({required runId, required afterSeq}) {
          calls++;
          return switch (calls) {
            1 => first.stream,
            2 => automaticRetry.stream,
            _ => refreshed.stream,
          };
        };
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);

      await notifier.load();
      first.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'partial',
          seq: 7,
        ),
      );
      await pumpEventQueue();
      first.addError(const AssistantStreamException('first disconnect'));
      await pumpEventQueue();
      automaticRetry.addError(
        const AssistantStreamException('second disconnect'),
      );
      await pumpEventQueue();

      expect(source.eventCalls, [0, 7]);
      expect(notifier.state.hasActiveRun, isTrue);
      expect(notifier.state.isStreaming, isFalse);
      expect(notifier.state.connectionError, isNotNull);

      expect(
        await notifier.refreshForThread(
          const AssistantThreadSummary(
            sessionId: 1,
            activeRunId: 21,
            activeRunStatus: 'running',
            activeRunPhase: 'tool_executing',
          ),
        ),
        isTrue,
      );
      expect(source.eventCalls, [0, 7, 7]);
      expect(notifier.state.activeRunPhase, 'tool_executing');
      expect(notifier.state.isStreaming, isTrue);
      expect(notifier.state.connectionError, isNotNull);

      refreshed.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: ' resumed',
          seq: 8,
        ),
      );
      refreshed.add(
        const AssistantRunEvent(type: AssistantEventType.done, seq: 9),
      );
      await pumpEventQueue();

      expect(notifier.state.messages.last.text, 'partial resumed');
      expect(notifier.state.hasActiveRun, isFalse);
      expect(notifier.state.isStreaming, isFalse);
      expect(notifier.state.connectionError, isNull);
    },
  );

  test(
    'rejected retired-stream events do not claim transport recovery',
    () async {
      final first = StreamController<AssistantRunEvent>();
      final automaticRetry = StreamController<AssistantRunEvent>();
      final reconnected = StreamController<AssistantRunEvent>();
      addTearDown(first.close);
      addTearDown(automaticRetry.close);
      addTearDown(reconnected.close);
      var calls = 0;
      final source = FakeAssistantSource()
        ..eventsHandler = ({required runId, required afterSeq}) {
          calls++;
          return switch (calls) {
            1 => first.stream,
            2 => automaticRetry.stream,
            _ => reconnected.stream,
          };
        };
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);

      await notifier.load();
      expect(await notifier.send('question'), isTrue);
      first.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'discarded',
          streamId: 'attempt-a',
          seq: 1,
        ),
      );
      first.add(
        const AssistantRunEvent(
          type: AssistantEventType.responseReset,
          streamId: 'attempt-a',
          seq: 2,
        ),
      );
      first.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: 'winner',
          streamId: 'attempt-b',
          seq: 3,
        ),
      );
      await pumpEventQueue();
      first.addError(const AssistantStreamException('first disconnect'));
      await pumpEventQueue();
      automaticRetry.addError(
        const AssistantStreamException('second disconnect'),
      );
      await pumpEventQueue();

      expect(notifier.state.connectionError, isNotNull);
      expect(notifier.state.messages.last.errorCode, 'STREAM_DISCONNECTED');
      expect(notifier.state.messages.last.degraded, isTrue);
      expect(notifier.reconnectActiveRun(), isTrue);
      expect(source.eventCalls, [0, 3, 3]);

      reconnected.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: ' stale',
          streamId: 'attempt-a',
          seq: 4,
        ),
      );
      await pumpEventQueue();

      expect(notifier.state.connectionError, isNotNull);
      expect(notifier.state.messages.last.text, 'winner');
      expect(notifier.state.messages.last.errorCode, 'STREAM_DISCONNECTED');
      expect(notifier.state.messages.last.degraded, isTrue);

      reconnected.add(
        const AssistantRunEvent(
          type: AssistantEventType.token,
          text: ' resumed',
          streamId: 'attempt-b',
          seq: 5,
        ),
      );
      await pumpEventQueue();

      expect(notifier.state.connectionError, isNull);
      expect(notifier.state.messages.last.text, 'winner resumed');
      expect(notifier.state.messages.last.errorCode, isEmpty);
    },
  );

  test('persisted final is not degraded by a later transport error', () async {
    final events = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(events.close);
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) => events.stream;
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();
    expect(await notifier.send('question'), isTrue);

    source.messages = const [
      AssistantHistoryMessage(
        id: 11,
        sessionId: 1,
        runId: 21,
        role: 'user',
        content: 'question',
      ),
      AssistantHistoryMessage(
        id: 12,
        sessionId: 1,
        runId: 21,
        role: 'assistant',
        kind: 'message',
        content: 'persisted final',
      ),
    ];
    expect(await notifier.refreshMessages(), isTrue);

    events.addError(const AssistantStreamException('first disconnect'));
    await pumpEventQueue();
    events.addError(const AssistantStreamException('second disconnect'));
    await pumpEventQueue();

    final answer = notifier.state.messages.singleWhere(
      (message) => message.id == '12',
    );
    expect(answer.text, 'persisted final');
    expect(answer.degraded, isFalse);
    expect(answer.errorCode, isEmpty);
    expect(notifier.state.hasActiveRun, isFalse);
    expect(notifier.state.isStreaming, isFalse);
    expect(notifier.state.connectionError, isNull);
  });

  test(
    'history-first memory change ignores the same late SSE change',
    () async {
      final events = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(events.close);
      final source = FakeAssistantSource()
        ..thread = const AssistantThreadSummary(sessionId: 1, lastMessageId: 1)
        ..messages = const [
          AssistantHistoryMessage(
            id: 1,
            sessionId: 1,
            role: 'system',
            kind: 'memory_changed',
            content: 'persisted memory change',
            changeId: 12,
          ),
        ]
        ..eventsHandler = ({required runId, required afterSeq}) =>
            events.stream;
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);
      await notifier.load();
      expect(await notifier.send('remember this'), isTrue);

      events.add(
        const AssistantRunEvent(
          type: AssistantEventType.memoryChanged,
          text: 'late stream memory change',
          changeId: 12,
          seq: 1,
        ),
      );
      await pumpEventQueue();

      final memoryChanges = notifier.state.messages.where(
        (message) => message.isMemoryChanged,
      );
      expect(memoryChanges, hasLength(1));
      expect(memoryChanges.single.id, '1');
      expect(memoryChanges.single.text, 'persisted memory change');
    },
  );

  test('SSE-first memory change is replaced by the persisted change', () async {
    final events = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(events.close);
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) => events.stream;
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();
    expect(await notifier.send('remember this'), isTrue);
    events.add(
      const AssistantRunEvent(
        type: AssistantEventType.memoryChanged,
        text: 'stream memory change',
        changeId: 12,
        seq: 1,
      ),
    );
    await pumpEventQueue();

    source.messages = const [
      AssistantHistoryMessage(
        id: 11,
        sessionId: 1,
        runId: 21,
        role: 'user',
        content: 'remember this',
      ),
      AssistantHistoryMessage(
        id: 12,
        sessionId: 1,
        runId: 21,
        role: 'system',
        kind: 'memory_changed',
        content: 'persisted memory change',
        changeId: 12,
      ),
    ];
    expect(await notifier.refreshMessages(), isTrue);

    final memoryChanges = notifier.state.messages.where(
      (message) => message.isMemoryChanged,
    );
    expect(memoryChanges, hasLength(1));
    expect(memoryChanges.single.id, '12');
    expect(memoryChanges.single.text, 'persisted memory change');
  });

  test('same-session thread refresh adopts a different active run', () async {
    final events = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(events.close);
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) => events.stream;
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();
    source
      ..thread = const AssistantThreadSummary(
        sessionId: 1,
        lastMessageId: 2,
        activeRunId: 21,
        activeRunStatus: 'running',
        activeRunPhase: 'model_request',
      )
      ..messages = const [
        AssistantHistoryMessage(
          id: 2,
          sessionId: 1,
          role: 'user',
          content: 'started elsewhere',
        ),
      ];

    expect(await notifier.refreshForThread(source.thread), isTrue);
    expect(notifier.state.activeRunId, 21);
    expect(notifier.state.isStreaming, isTrue);
    expect(
      notifier.state.messages.any((message) => message.id == 'run-21'),
      isTrue,
    );
    expect(source.eventCalls, [0]);
  });

  test('active run takeover cannot retry the previous run command', () async {
    final firstEvents = StreamController<AssistantRunEvent>.broadcast();
    final secondEvents = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(firstEvents.close);
    addTearDown(secondEvents.close);
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) =>
          jsonInt64Id(runId) == '21' ? firstEvents.stream : secondEvents.stream;
    final notifier = AssistantNotifier(repository: source);
    addTearDown(notifier.dispose);
    await notifier.load();
    expect(await notifier.send('old command'), isTrue);

    source
      ..thread = const AssistantThreadSummary(
        sessionId: 1,
        lastMessageId: 12,
        activeRunId: 22,
        activeRunStatus: 'running',
        activeRunPhase: 'model_request',
      )
      ..messages = const [
        AssistantHistoryMessage(
          id: 12,
          sessionId: 1,
          runId: 22,
          role: 'user',
          content: 'new command from another tab',
        ),
      ];
    expect(await notifier.refreshForThread(source.thread), isTrue);

    secondEvents.add(
      const AssistantRunEvent(
        type: AssistantEventType.error,
        text: 'authorization required',
        errorCode: 'AGENT_NOT_AUTHORIZED',
        seq: 1,
      ),
    );
    await pumpEventQueue();

    expect(notifier.state.agentAuthorizationRequired, isTrue);
    expect(notifier.state.pendingRetryCommand, isNull);
  });

  test(
    'terminal SSE metadata survives persisted history reconciliation',
    () async {
      final events = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(events.close);
      final source = FakeAssistantSource()
        ..eventsHandler = ({required runId, required afterSeq}) =>
            events.stream;
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);
      await notifier.load();
      expect(await notifier.send('question'), isTrue);
      events.add(
        const AssistantRunEvent(
          type: AssistantEventType.done,
          degraded: true,
          seq: 1,
        ),
      );
      await pumpEventQueue();
      source.messages = const [
        AssistantHistoryMessage(
          id: 11,
          sessionId: 1,
          role: 'user',
          content: 'question',
        ),
        AssistantHistoryMessage(
          id: 12,
          sessionId: 1,
          runId: 21,
          role: 'assistant',
          kind: 'message',
          content: 'degraded answer',
        ),
      ];

      expect(
        await notifier.refreshForThread(
          const AssistantThreadSummary(sessionId: 1, lastMessageId: 12),
        ),
        isTrue,
      );
      final answer = notifier.state.messages.singleWhere(
        (message) => message.id == '12',
      );
      expect(answer.text, 'degraded answer');
      expect(answer.degraded, isTrue);
      expect(answer.terminalEventReceived, isTrue);
    },
  );

  test(
    'full load trusts a persisted final over a stale active snapshot',
    () async {
      final source = FakeAssistantSource()
        ..thread = const AssistantThreadSummary(
          sessionId: 1,
          lastMessageId: 13,
          activeRunId: 21,
          activeRunStatus: 'running',
          activeRunPhase: 'model_request',
        )
        ..messages = const [
          AssistantHistoryMessage(
            id: 11,
            sessionId: 1,
            role: 'user',
            content: 'question',
          ),
          AssistantHistoryMessage(
            id: 12,
            sessionId: 1,
            runId: 21,
            role: 'assistant',
            kind: 'tool',
            content: 'tool preamble',
          ),
          AssistantHistoryMessage(
            id: 13,
            sessionId: 1,
            runId: 21,
            role: 'assistant',
            kind: 'message',
            content: 'final answer',
          ),
        ];
      final notifier = AssistantNotifier(repository: source);
      addTearDown(notifier.dispose);

      await notifier.load();

      expect(notifier.state.hasActiveRun, isFalse);
      expect(notifier.state.isStreaming, isFalse);
      expect(
        notifier.state.messages
            .where((message) => message.role == AssistantMessageRole.assistant)
            .map((message) => message.id),
        ['12', '13'],
      );
      expect(
        notifier.state.messages.any((message) => message.id == 'run-21'),
        isFalse,
      );
      expect(source.eventCalls, isEmpty);
    },
  );

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

  test('terminal SSE cancels the live stream subscription', () async {
    final canceled = Completer<void>();
    final controller = StreamController<AssistantRunEvent>.broadcast(
      onCancel: () {
        if (!canceled.isCompleted) canceled.complete();
      },
    );
    addTearDown(controller.close);
    final repository = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) =>
          controller.stream;
    final notifier = AssistantNotifier(repository: repository);
    addTearDown(notifier.dispose);

    expect(await notifier.send('hello'), isTrue);
    controller.add(
      const AssistantRunEvent(type: AssistantEventType.done, seq: 1),
    );
    await expectLater(canceled.future, completes);

    expect(notifier.state.hasActiveRun, isFalse);
    expect(notifier.state.isStreaming, isFalse);
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
      addTearDown(notifier.dispose);

      await notifier.load();
      await notifier.send('hello');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.isStreaming, isFalse);
      expect(notifier.state.connectionError, contains('中断'));
      expect(notifier.state.messages.last.errorCode, 'STREAM_DISCONNECTED');
      expect(repository.eventCalls, isNotEmpty);

      expect(
        await notifier.refreshForThread(
          const AssistantThreadSummary(sessionId: 1, lastMessageId: 11),
        ),
        isTrue,
      );
      expect(notifier.state.connectionError, isNull);
      expect(notifier.state.hasActiveRun, isFalse);
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
