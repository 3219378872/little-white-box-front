import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
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
          ({required message, required requestId, required attachments}) async {
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
    expect(
      notifier.state.messages.any((item) => item.isMemoryChanged),
      isTrue,
    );
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

  test('new session and clear history keep memory and watches', () async {
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
    await notifier.startNewSession();
    expect(source.sessionCreates, 1);
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
        ),
      ];
    final list = WatchListNotifier(repository: source);
    await list.load();
    expect(list.state.items, hasLength(1));
    await list.setEnabled(list.state.items.single, false);
    expect(source.watches.single.enabled, isFalse);
    await list.deleteTask(list.state.items.single);
    expect(source.watches, isEmpty);
  });

  test('thread notifier merges unread independently of message unread', () async {
    final source = FakeAssistantSource()
      ..thread = const AssistantThreadSummary(sessionId: 1, unreadCount: 3);
    final notifier = AssistantThreadNotifier(
      repository: source,
      loadImmediately: false,
    );
    await notifier.refresh();
    expect(notifier.state.thread.unreadCount, 3);
  });
}
