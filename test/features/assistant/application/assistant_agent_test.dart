import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/api/error_codes.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_thread_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/application/memory_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/application/watch_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';

import '../helpers/fake_assistant_source.dart';

void main() {
  test('busy send still posts and Stop is the only hard cancel', () async {
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) =>
          const Stream.empty();
    final notifier = AssistantNotifier(repository: source)
      ..addPendingAttachment(
        const PendingChatImage(mediaId: 11, url: 'http://x/11'),
      );
    expect(await notifier.send('发一个帖子'), isTrue);
    expect(source.lastAttachments, hasLength(1));
    expect(notifier.state.pendingAttachments, isEmpty);
    expect(notifier.state.hasActiveRun, isTrue);
    expect(notifier.state.canSend, isTrue);
    await notifier.stop();
    expect(source.lastCancelRunId, 21);
    expect(notifier.state.hasActiveRun, isFalse);
  });

  test('redirected and queued dispositions update busy UX', () async {
    final source = FakeAssistantSource()
      ..postHandler =
          ({
            required message,
            required requestId,
            required attachments,
            required contextPostId,
          }) async {
            if (message.contains('queue')) {
              return const AssistantPostResult(
                messageId: 12,
                sessionId: 1,
                runId: 22,
                disposition: AssistantDisposition.queued,
              );
            }
            return const AssistantPostResult(
              messageId: 13,
              sessionId: 1,
              runId: 23,
              disposition: AssistantDisposition.redirected,
            );
          }
      ..eventsHandler = ({required runId, required afterSeq}) =>
          const Stream.empty();
    final notifier = AssistantNotifier(repository: source);
    expect(await notifier.send('queue-me'), isTrue);
    expect(notifier.state.isQueued, isTrue);
    expect(await notifier.send('redirect-me'), isTrue);
    expect(notifier.state.lastDisposition, AssistantDisposition.redirected);
  });

  test('tool call events build steps and confirmation resolves once', () async {
    final controller = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(controller.close);
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) =>
          controller.stream;
    final notifier = AssistantNotifier(repository: source);
    await notifier.send('删掉帖子 9');

    controller.add(
      const AssistantRunEvent(
        type: AssistantEventType.toolCall,
        toolCall: AssistantToolCall(
          callId: 'c1',
          tool: 'search_posts',
          summary: '搜索帖子：9',
        ),
        seq: 1,
      ),
    );
    controller.add(
      const AssistantRunEvent(
        type: AssistantEventType.confirmRequired,
        toolCall: AssistantToolCall(
          callId: 'c2',
          tool: 'delete_post',
          summary: '请求删除帖子 #9',
        ),
        seq: 2,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    var message = notifier.state.messages.last;
    expect(message.toolSteps.map((step) => step.status), [
      AssistantToolStatus.running,
      AssistantToolStatus.awaitingConfirmation,
    ]);

    await notifier.respondToConfirmation('c2', true);
    expect(source.confirmCalls, 1);
    expect(source.lastApproved, isTrue);
    message = notifier.state.messages.last;
    expect(message.toolSteps.last.status, AssistantToolStatus.confirmed);
  });

  test('AGENT_NOT_AUTHORIZED error raises authorization flag', () async {
    final controller = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(controller.close);
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) =>
          controller.stream;
    final notifier = AssistantNotifier(repository: source);
    await notifier.send('hello');
    controller.add(
      const AssistantRunEvent(
        type: AssistantEventType.error,
        text: '需要授权',
        errorCode: 'AGENT_NOT_AUTHORIZED',
        seq: 1,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.agentAuthorizationRequired, isTrue);
    expect(notifier.state.isStreaming, isFalse);
  });

  test('unknown events are ignored while source cards apply', () async {
    final controller = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(controller.close);
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) =>
          controller.stream;
    final notifier = AssistantNotifier(repository: source);
    await notifier.send('recommend');

    controller.add(const AssistantRunEvent(type: AssistantEventType.unknown));
    controller.add(
      const AssistantRunEvent(
        type: AssistantEventType.sourceCard,
        sourceCard: AssistantSourceCard(
          handle: 'src-7',
          kind: 'post',
          authorityId: '7',
          title: '推荐帖',
        ),
        seq: 1,
      ),
    );
    controller.add(
      const AssistantRunEvent(
        type: AssistantEventType.memoryChanged,
        text: '记忆已更新',
        changeId: 9,
        seq: 2,
      ),
    );
    controller.add(
      const AssistantRunEvent(type: AssistantEventType.done, seq: 3),
    );
    await Future<void>.delayed(Duration.zero);

    final assistant = notifier.state.messages.firstWhere(
      (item) => item.role == AssistantMessageRole.assistant,
    );
    expect(assistant.sources.single.authorityId, '7');
    expect(notifier.state.messages.any((item) => item.isMemoryChanged), isTrue);
    expect(notifier.state.connectionError, isNull);
  });

  test('reconnects SSE with afterSeq after a disconnect', () async {
    var calls = 0;
    final first = StreamController<AssistantRunEvent>();
    final second = StreamController<AssistantRunEvent>();
    addTearDown(first.close);
    addTearDown(second.close);
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) {
        calls++;
        return calls == 1 ? first.stream : second.stream;
      };
    final notifier = AssistantNotifier(repository: source);
    await notifier.send('hello');
    first.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: 'Hel',
        seq: 4,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await first.close();
    await Future<void>.delayed(Duration.zero);
    expect(source.eventCalls.last, 4);
    second.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: 'lo',
        seq: 5,
      ),
    );
    second.add(const AssistantRunEvent(type: AssistantEventType.done, seq: 6));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.messages.last.text, 'Hello');
    expect(notifier.state.isStreaming, isFalse);
  });

  test('clear history keeps memory and watches', () async {
    final source = FakeAssistantSource()
      ..memories = const [
        MemoryRecord(id: 1, target: 'memory', content: '喜欢美食'),
      ]
      ..watches = const [
        WatchTask(
          id: 1,
          conditionType: 'author_new_post',
          targetType: 'author',
          targetId: '2',
        ),
      ];
    final notifier = AssistantNotifier(repository: source);
    await notifier.clearHistory();
    expect(source.historyDeletes, 1);
    expect(source.memories, isNotEmpty);
    expect(source.watches, isNotEmpty);
  });

  test('consent upgrade is required when granted version is stale', () async {
    final source = FakeAssistantSource()
      ..granted = true
      ..consentVersion = 1
      ..currentVersion = 2;
    final notifier = AgentConsentNotifier(repository: source);
    await notifier.ensureLoaded();
    expect(notifier.state.granted, isTrue);
    expect(notifier.state.needsUpgrade, isTrue);
    expect(notifier.state.canStartRun, isFalse);

    await notifier.grant();
    expect(notifier.state.needsUpgrade, isFalse);
    expect(notifier.state.canStartRun, isTrue);
  });

  test('memory notifier lists dual targets and surfaces errors', () async {
    final source = FakeAssistantSource()
      ..memories = const [
        MemoryRecord(id: 1, target: 'memory', content: '喜欢美食', version: 1),
        MemoryRecord(id: 2, target: 'user', content: '用中文', version: 1),
      ]
      ..capacities = const [
        MemoryCapacity(target: 'memory', used: 4, limit: 2200),
      ];
    final notifier = MemoryListNotifier(repository: source);
    await notifier.load();
    expect(notifier.state.items.map((item) => item.target), ['memory', 'user']);
    expect(notifier.state.capacities.single.limit, 2200);

    source.lastError = const ApiException('无权访问');
    final failing = MemoryListNotifier(repository: source);
    await failing.load();
    expect(failing.state.error, contains('无权访问'));
  });

  test('watch notifier creates toggles and deletes without hits', () async {
    final source = FakeAssistantSource()
      ..watches = [
        const WatchTask(
          id: 1,
          conditionType: 'author_new_post',
          targetType: 'author',
          targetId: '2',
          version: 3,
        ),
      ];
    final list = WatchListNotifier(repository: source);
    await list.load();
    expect(list.state.items, hasLength(1));
    await list.setEnabled(list.state.items.single, false);
    expect(source.watches.single.enabled, isFalse);
    expect(source.lastUpdateExpectedVersion, 3);
    expect(list.state.items.single.version, 4);
    await list.deleteTask(list.state.items.single);
    expect(source.lastDeleteExpectedVersion, 4);
    expect(source.watches, isEmpty);
  });

  test(
    'watch update conflict refreshes the task and keeps the error',
    () async {
      const stale = WatchTask(
        id: 1,
        conditionType: 'author_new_post',
        targetType: 'author',
        targetId: '2',
        version: 3,
      );
      final source = FakeAssistantSource()..watches = const [stale];
      final list = WatchListNotifier(repository: source);
      await list.load();
      source
        ..watches = const [
          WatchTask(
            id: 1,
            conditionType: 'author_new_post',
            targetType: 'author',
            targetId: '2',
            enabled: false,
            version: 4,
          ),
        ]
        ..updateWatchError = const ApiException(
          '内容版本冲突',
          code: ErrorCodes.contentVersionConflict,
        );

      await expectLater(
        list.setEnabled(stale, false),
        throwsA(isA<ApiException>()),
      );

      expect(source.lastUpdateExpectedVersion, 3);
      expect(source.listWatchCalls, 2);
      expect(list.state.items.single.version, 4);
      expect(list.state.items.single.enabled, isFalse);
      expect(list.state.error, '内容版本冲突');
    },
  );

  test(
    'watch delete conflict refreshes the task and keeps the error',
    () async {
      const stale = WatchTask(
        id: 1,
        conditionType: 'author_new_post',
        targetType: 'author',
        targetId: '2',
        version: 4,
      );
      final source = FakeAssistantSource()..watches = const [stale];
      final list = WatchListNotifier(repository: source);
      await list.load();
      source
        ..watches = const [
          WatchTask(
            id: 1,
            conditionType: 'author_new_post',
            targetType: 'author',
            targetId: '2',
            version: 5,
          ),
        ]
        ..deleteWatchError = const ApiException(
          '内容版本冲突',
          code: ErrorCodes.contentVersionConflict,
        );

      await expectLater(list.deleteTask(stale), throwsA(isA<ApiException>()));

      expect(source.lastDeleteExpectedVersion, 4);
      expect(source.listWatchCalls, 2);
      expect(list.state.items.single.version, 5);
      expect(list.state.error, '内容版本冲突');
    },
  );

  test(
    'thread notifier merges unread independently of message unread',
    () async {
      final source = FakeAssistantSource()
        ..thread = const AssistantThreadSummary(sessionId: 1, unreadCount: 3);
      final notifier = AssistantThreadNotifier(
        repository: source,
        loadImmediately: false,
      );
      await notifier.refresh();
      expect(notifier.state.thread.unreadCount, 3);
    },
  );

  test(
    'failed send retry reuses request id attachments and context without a duplicate bubble',
    () async {
      var attempts = 0;
      final source = FakeAssistantSource()
        ..postHandler =
            ({
              required message,
              required requestId,
              required attachments,
              required contextPostId,
            }) async {
              attempts++;
              if (attempts == 1) throw const ApiException('network down');
              return const AssistantPostResult(
                messageId: 11,
                sessionId: 1,
                runId: 21,
                disposition: AssistantDisposition.started,
              );
            }
        ..eventsHandler = ({required runId, required afterSeq}) =>
            const Stream.empty();
      final notifier =
          AssistantNotifier(
            repository: source,
            createRequestId: () => 'stable-request',
          )..addPendingAttachment(
            const PendingChatImage(mediaId: 7, url: 'https://media/7'),
          );

      expect(await notifier.send('retry me', contextPostId: '99'), isFalse);
      expect(await notifier.retryPending(), isTrue);

      expect(source.postedRequestIds, ['stable-request', 'stable-request']);
      expect(source.postedContextPostIds, ['99', '99']);
      expect(source.lastAttachments.single.mediaId, 7);
      expect(
        notifier.state.messages.where(
          (item) => item.role == AssistantMessageRole.user,
        ),
        hasLength(1),
      );
      expect(notifier.state.messages.first.attachments.single.mediaId, 7);
    },
  );

  test('cancel and confirm failures keep truthful retryable state', () async {
    final controller = StreamController<AssistantRunEvent>.broadcast();
    addTearDown(controller.close);
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) =>
          controller.stream;
    final notifier = AssistantNotifier(repository: source);
    await notifier.send('delete post');
    controller.add(
      const AssistantRunEvent(
        type: AssistantEventType.confirmRequired,
        toolCall: AssistantToolCall(
          callId: 'delete-1',
          tool: 'delete_post',
          summary: 'delete post 9',
        ),
        seq: 1,
      ),
    );
    await pumpEventQueue();

    source.confirmError = const ApiException('confirm failed');
    expect(await notifier.respondToConfirmation('delete-1', true), isFalse);
    expect(
      notifier.state.messages.last.toolSteps.single.status,
      AssistantToolStatus.awaitingConfirmation,
    );
    source.confirmError = null;
    expect(await notifier.respondToConfirmation('delete-1', true), isTrue);
    expect(
      notifier.state.messages.last.toolSteps.single.status,
      AssistantToolStatus.confirmed,
    );

    source.cancelError = const ApiException('cancel failed');
    expect(await notifier.stop(), isFalse);
    expect(notifier.state.hasActiveRun, isTrue);
    expect(notifier.state.messages.last.isCanceled, isFalse);
    source.cancelError = null;
    expect(await notifier.stop(), isTrue);
    expect(notifier.state.hasActiveRun, isFalse);
    expect(notifier.state.messages.last.isCanceled, isTrue);
  });

  test(
    'memory_changed undo is retryable and settles only after success',
    () async {
      final controller = StreamController<AssistantRunEvent>.broadcast();
      addTearDown(controller.close);
      final source = FakeAssistantSource()
        ..eventsHandler = ({required runId, required afterSeq}) =>
            controller.stream;
      final notifier = AssistantNotifier(repository: source);
      await notifier.send('remember this');
      controller.add(
        const AssistantRunEvent(
          type: AssistantEventType.memoryChanged,
          text: 'memory updated',
          changeId: 12,
          seq: 1,
        ),
      );
      await pumpEventQueue();

      source.undoError = const ApiException('undo failed');
      expect(await notifier.undoMemoryChange(12), isFalse);
      var change = notifier.state.messages.firstWhere(
        (item) => item.isMemoryChanged,
      );
      expect(change.memoryUndone, isFalse);
      expect(change.memoryUndoing, isFalse);

      source.undoError = null;
      expect(await notifier.undoMemoryChange(12), isTrue);
      change = notifier.state.messages.firstWhere(
        (item) => item.isMemoryChanged,
      );
      expect(change.memoryUndone, isTrue);
    },
  );

  test(
    'latest history, older paging, and Watch push refresh stay ordered',
    () async {
      final history = [
        for (var id = 1; id <= 52; id++)
          AssistantHistoryMessage(
            id: id,
            sessionId: 1,
            role: id.isOdd ? 'user' : 'assistant',
            content: 'message $id',
          ),
      ];
      final source = FakeAssistantSource()
        ..thread = const AssistantThreadSummary(sessionId: 1, lastMessageId: 52)
        ..messages = history;
      final notifier = AssistantNotifier(repository: source);

      await notifier.load();
      expect(notifier.state.messages, hasLength(50));
      expect(notifier.state.messages.first.text, 'message 3');
      expect(notifier.state.hasMoreHistory, isTrue);
      expect(await notifier.loadOlderMessages(), isTrue);
      expect(notifier.state.messages, hasLength(52));
      expect(notifier.state.messages.first.text, 'message 1');

      source.messages = [
        ...history,
        const AssistantHistoryMessage(
          id: 53,
          sessionId: 1,
          role: 'assistant',
          kind: 'watch',
          content: 'Watch found a new post',
          unread: true,
        ),
      ];
      expect(
        await notifier.refreshForThread(
          const AssistantThreadSummary(sessionId: 1, lastMessageId: 53),
        ),
        isTrue,
      );
      expect(notifier.state.messages.last.text, 'Watch found a new post');
    },
  );
}
