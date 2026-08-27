import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/application/memory_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/application/watch_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';

import '../helpers/fake_assistant_source.dart';

void main() {
  test('mode defaults to enhanced_search and switches on request', () {
    final source = FakeAssistantSource();
    final notifier = AssistantNotifier(repository: source);
    expect(notifier.mode, AssistantMode.enhancedSearch);
    notifier.setMode(AssistantMode.agent);
    expect(notifier.mode, AssistantMode.agent);
  });

  test('agent send forwards mode plus attachments and clears pending', () {
    final source = FakeAssistantSource()
      ..chatHandler =
          ({
            required message,
            required requestId,
            required conversationId,
            required mode,
            required attachments,
          }) => const Stream.empty();
    final notifier = AssistantNotifier(repository: source)
      ..setMode(AssistantMode.agent)
      ..addPendingAttachment(
        const PendingChatImage(mediaId: 11, url: 'http://x/11'),
      );
    final accepted = notifier.send('发一个帖子');
    expect(accepted, isTrue);
    expect(source.lastMode, AssistantMode.agent);
    expect(source.lastAttachments, hasLength(1));
    expect(source.lastAttachments.first.mediaId, 11);
    expect(notifier.state.pendingAttachments, isEmpty);
    expect(notifier.state.messages.first.attachments.single.mediaId, 11);
  });

  test('tool call events build steps and confirmation resolves once', () async {
    final controller = StreamController<AssistantChatEvent>();
    addTearDown(controller.close);
    final source = FakeAssistantSource()
      ..chatHandler =
          ({
            required message,
            required requestId,
            required conversationId,
            required mode,
            required attachments,
          }) => controller.stream;
    final notifier = AssistantNotifier(repository: source)
      ..setMode(AssistantMode.agent);
    notifier.send('删掉帖子 9');
    final responseId = notifier.state.messages.last.id;

    controller.add(
      const AssistantChatEvent(
        type: AssistantEventType.toolCall,
        toolCall: AssistantToolCall(
          callId: 'c1',
          tool: 'search_posts',
          summary: '搜索帖子：9',
        ),
        conversationId: 'c-0',
      ),
    );
    controller.add(
      const AssistantChatEvent(
        type: AssistantEventType.confirmRequired,
        toolCall: AssistantToolCall(
          callId: 'c2',
          tool: 'delete_post',
          summary: '请求删除帖子 #9',
        ),
        conversationId: 'c-0',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    var message = notifier.state.messages.last;
    expect(message.toolSteps.map((step) => step.status), [
      AssistantToolStatus.running,
      AssistantToolStatus.awaitingConfirmation,
    ]);
    expect(message.hasPendingConfirmation, isTrue);

    await notifier.respondToConfirmation('c2', true);
    expect(source.confirmCalls, 1);
    expect(source.lastApproved, isTrue);
    message = notifier.state.messages.last;
    expect(message.toolSteps.last.status, AssistantToolStatus.confirmed);

    controller.add(
      const AssistantChatEvent(
        type: AssistantEventType.done,
        conversationId: 'c-0',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    message = notifier.state.messages.last;
    expect(message.toolSteps.map((step) => step.status), [
      AssistantToolStatus.completed,
      AssistantToolStatus.confirmed,
    ]);
    expect(message.isStreaming, isFalse);
    expect(responseId, isNotEmpty);
  });

  test('AGENT_NOT_AUTHORIZED error raises authorization flag', () async {
    final controller = StreamController<AssistantChatEvent>();
    addTearDown(controller.close);
    final source = FakeAssistantSource()
      ..chatHandler =
          ({
            required message,
            required requestId,
            required conversationId,
            required mode,
            required attachments,
          }) => controller.stream;
    final notifier = AssistantNotifier(repository: source)
      ..setMode(AssistantMode.agent);
    notifier.send('hello');
    controller.add(
      const AssistantChatEvent(
        type: AssistantEventType.error,
        text: '需要授权',
        errorCode: 'AGENT_NOT_AUTHORIZED',
        conversationId: 'c-0',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.agentAuthorizationRequired, isTrue);
    expect(notifier.state.isStreaming, isFalse);
  });

  test(
    'unknown events are ignored while card actions and watch hits apply',
    () async {
      final controller = StreamController<AssistantChatEvent>();
      addTearDown(controller.close);
      final source = FakeAssistantSource()
        ..chatHandler =
            ({
              required message,
              required requestId,
              required conversationId,
              required mode,
              required attachments,
            }) => controller.stream;
      final notifier = AssistantNotifier(repository: source);
      notifier.send('recommend');

      controller.add(
        const AssistantChatEvent(type: AssistantEventType.unknown),
      );
      controller.add(
        const AssistantChatEvent(
          type: AssistantEventType.card,
          card: AssistantStructuredCard(
            cardType: 'recommend',
            postId: '7',
            title: '推荐帖',
          ),
          conversationId: 'c-0',
        ),
      );
      controller.add(
        const AssistantChatEvent(
          type: AssistantEventType.actions,
          actions: [
            AssistantStructuredAction(action: 'open_post', postId: '7'),
          ],
          conversationId: 'c-0',
        ),
      );
      controller.add(
        const AssistantChatEvent(
          type: AssistantEventType.watchHit,
          watchHit: AssistantWatchHitNotice(
            hitId: '1',
            taskId: '1',
            postId: '7',
            title: '新帖',
          ),
          conversationId: 'c-0',
        ),
      );
      controller.add(
        const AssistantChatEvent(
          type: AssistantEventType.done,
          conversationId: 'c-0',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final message = notifier.state.messages.last;
      expect(message.cards.single.postId, '7');
      expect(message.actions.single.action, 'open_post');
      expect(message.watchHits.single.postId, '7');
      expect(message.isStreaming, isFalse);
      expect(notifier.state.connectionError, isNull);
    },
  );

  test('consent upgrade is required when granted version is stale', () async {
    final source = FakeAssistantSource()
      ..granted = true
      ..consentVersion = 1
      ..currentVersion = 2;
    final notifier = AgentConsentNotifier(repository: source);
    await notifier.ensureLoaded();
    expect(notifier.state.granted, isTrue);
    expect(notifier.state.needsUpgrade, isTrue);
    expect(notifier.state.canUseMemoryWatch, isFalse);

    await notifier.grant();
    expect(notifier.state.needsUpgrade, isFalse);
    expect(notifier.state.canUseMemoryWatch, isTrue);
    expect(notifier.state.consentVersion, 2);
  });

  test('memory notifier surfaces errors instead of empty success', () async {
    final source = FakeAssistantSource()
      ..lastError = const ApiException('无权访问');
    final notifier = MemoryListNotifier(repository: source);
    await notifier.load();
    expect(notifier.state.items, isEmpty);
    expect(notifier.state.error, contains('无权访问'));
  });

  test(
    'watch notifier creates, toggles, deletes and marks hits read',
    () async {
      final source = FakeAssistantSource()
        ..watches = [
          const WatchTask(
            id: 1,
            conditionType: 'author_new_post',
            targetType: 'author',
            targetId: '2',
          ),
        ]
        ..hits = [const WatchHit(id: 9, taskId: 1, postId: '7', title: '命中')];
      final list = WatchListNotifier(repository: source);
      final hits = WatchHitsNotifier(repository: source);
      await list.load();
      await hits.load();
      expect(list.state.items, hasLength(1));
      expect(hits.state.items.single.read, isFalse);

      await list.setEnabled(list.state.items.single, false);
      expect(source.watches.single.enabled, isFalse);

      await hits.markHitRead(hits.state.items.single);
      expect(source.hits.single.read, isTrue);

      await list.deleteTask(list.state.items.single);
      expect(source.watches, isEmpty);
    },
  );
}
