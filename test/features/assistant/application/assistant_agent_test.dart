import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart' hide AssistantChatEvent;

class _ScriptedSource implements AssistantDataSource {
  final StreamController<AssistantChatEvent> controller =
      StreamController<AssistantChatEvent>();
  AssistantMode? lastMode;
  List<AssistantAttachment> lastAttachments = const [];
  int confirmCalls = 0;
  bool? lastApproved;

  @override
  Stream<AssistantChatEvent> chat({
    required String message,
    required String requestId,
    String conversationId = '',
    AssistantMode mode = AssistantMode.enhancedSearch,
    List<AssistantAttachment> attachments = const [],
  }) {
    lastMode = mode;
    lastAttachments = attachments;
    return controller.stream;
  }

  @override
  Future<AgentConsentStatus> loadAgentConsent() async =>
      const AgentConsentStatus(granted: false);

  @override
  Future<void> setAgentConsent({required bool granted}) async {}

  @override
  Future<void> confirmTool({
    required String requestId,
    required String callId,
    required bool approved,
  }) async {
    confirmCalls++;
    lastApproved = approved;
  }
}

void main() {
  test('mode defaults to enhanced_search and switches on request', () {
    final source = _ScriptedSource();
    final notifier = AssistantNotifier(repository: source);
    expect(notifier.mode, AssistantMode.enhancedSearch);
    notifier.setMode(AssistantMode.agent);
    expect(notifier.mode, AssistantMode.agent);
  });

  test('agent send forwards mode plus attachments and clears pending', () {
    final source = _ScriptedSource();
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
    // 用户气泡保留附件缩略信息。
    expect(
      notifier.state.messages.first.attachments.single.mediaId,
      11,
    );
  });

  test('tool call events build steps and confirmation resolves once', () async {
    final source = _ScriptedSource();
    final notifier = AssistantNotifier(repository: source)
      ..setMode(AssistantMode.agent);
    notifier.send('删掉帖子 9');
    final responseId = notifier.state.messages.last.id;

    source.controller.add(const AssistantChatEvent(
      type: AssistantEventType.toolCall,
      toolCall: AssistantToolCall(callId: 'c1', tool: 'search_posts', summary: '搜索帖子：9'),
      conversationId: 'c-0',
    ));
    source.controller.add(const AssistantChatEvent(
      type: AssistantEventType.confirmRequired,
      toolCall: AssistantToolCall(callId: 'c2', tool: 'delete_post', summary: '请求删除帖子 #9'),
      conversationId: 'c-0',
    ));
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

    source.controller.add(const AssistantChatEvent(
      type: AssistantEventType.done,
      conversationId: 'c-0',
    ));
    await Future<void>.delayed(Duration.zero);
    message = notifier.state.messages.last;
    // 完成时 running 步骤收敛，已确认卡片保持原状。
    expect(message.toolSteps.map((step) => step.status), [
      AssistantToolStatus.completed,
      AssistantToolStatus.confirmed,
    ]);
    expect(message.isStreaming, isFalse);
    expect(responseId, isNotEmpty);
  });

  test('AGENT_NOT_AUTHORIZED error raises authorization flag', () async {
    final source = _ScriptedSource();
    final notifier = AssistantNotifier(repository: source)
      ..setMode(AssistantMode.agent);
    notifier.send('hello');
    source.controller.add(const AssistantChatEvent(
      type: AssistantEventType.error,
      text: '需要授权',
      errorCode: 'AGENT_NOT_AUTHORIZED',
      conversationId: 'c-0',
    ));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.agentAuthorizationRequired, isTrue);
    expect(notifier.state.isStreaming, isFalse);
  });
}
