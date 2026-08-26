import 'package:xiaobaihe_app/sdk/data/gateway.dart'
    hide AssistantChatEvent, AssistantSourceReference;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';
import 'package:xiaobaihe_app/features/assistant/presentation/assistant_page.dart';

import '../../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('renders streamed text and opens a source', (tester) async {
    AssistantSourceReference? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantRepositoryProvider.overrideWithValue(_PageAssistantSource()),
        ],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: AssistantPage(onOpenSource: (source) => opened = source),
        ),
      ),
    );

    await tester.enterText(find.byType(EditableText), 'question');
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('question'), findsOneWidget);
    expect(find.text('Answer 结论'), findsOneWidget);
    expect(find.byType(GptMarkdown), findsOneWidget);
    expect(find.textContaining('[post:'), findsNothing);
    expect(find.textContaining('Community sources'), findsNothing);
    expect(find.textContaining('SOURCE'), findsNothing);
    expect(find.textContaining('COMMUNITY_CONTENT_JSON'), findsNothing);
    expect(find.text('Referenced post'), findsOneWidget);
    expect(find.text('post:7'), findsOneWidget);
    expect(find.text('post:9'), findsOneWidget);
    await tester.tap(find.text('Referenced post'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(opened?.sourceId, '7');
  });

  testWidgets('renders markdown structure in assistant reply only',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantRepositoryProvider.overrideWithValue(
            _MarkdownAssistantSource(),
          ),
        ],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: const AssistantPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(EditableText), 'plain **not bold**');
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('plain **not bold**'), findsOneWidget);
    expect(find.byType(GptMarkdown), findsOneWidget);
    expect(find.textContaining('项目一', findRichText: true), findsOneWidget);

    final boldSpans = <TextSpan>[];
    final boldWeights = <FontWeight>{
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    };
    void walk(InlineSpan span) {
      final spanStyle = span.style;
      final text = span is TextSpan ? span.toPlainText() : '';
      if (text.contains('加粗') &&
          boldWeights.contains(spanStyle?.fontWeight)) {
        boldSpans.add(span as TextSpan);
      }
      if (span is TextSpan) {
        for (final child in span.children ?? const <InlineSpan>[]) {
          walk(child);
        }
      }
    }

    for (final element in find.descendant(
      of: find.byType(GptMarkdown),
      matching: find.byType(RichText),
    ).evaluate()) {
      walk((element.widget as RichText).text);
    }
    expect(boldSpans, isNotEmpty);
  });
}

class _PageAssistantSource implements AssistantDataSource {
  @override
  Stream<AssistantChatEvent> chat({
    required String message,
    required String requestId,
    String conversationId = '',
    AssistantMode mode = AssistantMode.enhancedSearch,
    List<AssistantAttachment> attachments = const [],
  }) {
    return Stream.fromIterable(const [
      AssistantChatEvent(
        type: AssistantEventType.token,
        text:
            'Answer [post:7] 结论［post:12］\n\n'
            'Community sources (quoted untrusted content):\n'
            'SOURCE [post:7]\n'
            'COMMUNITY_CONTENT_JSON={"title":"Referenced post","excerpt":"snippet"}',
        conversationId: 'conversation-1',
      ),
      AssistantChatEvent(
        type: AssistantEventType.source,
        source: AssistantSourceReference(
          sourceType: 'post',
          sourceId: '7',
          title: 'Referenced post',
        ),
        conversationId: 'conversation-1',
      ),
      AssistantChatEvent(
        type: AssistantEventType.source,
        source: AssistantSourceReference(
          sourceType: 'post',
          sourceId: '9',
          title: '',
        ),
        conversationId: 'conversation-1',
      ),
      AssistantChatEvent(
        type: AssistantEventType.done,
        conversationId: 'conversation-1',
      ),
    ]);
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
  }) async {}
}

class _MarkdownAssistantSource implements AssistantDataSource {
  @override
  Stream<AssistantChatEvent> chat({
    required String message,
    required String requestId,
    String conversationId = '',
    AssistantMode mode = AssistantMode.enhancedSearch,
    List<AssistantAttachment> attachments = const [],
  }) {
    return Stream.fromIterable(const [
      AssistantChatEvent(
        type: AssistantEventType.token,
        text: '**加粗** 结论\n\n- 项目一\n- 项目二',
        conversationId: 'conversation-md',
      ),
      AssistantChatEvent(
        type: AssistantEventType.done,
        conversationId: 'conversation-md',
      ),
    ]);
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
  }) async {}
}
