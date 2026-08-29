import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/presentation/assistant_page.dart';

import '../../../helpers/forui_test_builder.dart';
import '../helpers/fake_assistant_source.dart';

void main() {
  testWidgets('renders streamed text and opens a source card only', (
    tester,
  ) async {
    AssistantSourceCard? opened;
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
    await tester.pump();
    await tester.pump();

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
    expect(find.text('Referenced post'), findsOneWidget);
    expect(find.text('增强搜索'), findsNothing);
    await tester.tap(find.text('打开帖子'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(opened?.authorityId, '7');
  });

  testWidgets('renders markdown structure in assistant reply only', (
    tester,
  ) async {
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
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(EditableText), 'plain **not bold**');
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('plain **not bold**'), findsOneWidget);
    expect(find.byType(GptMarkdown), findsOneWidget);
    expect(find.textContaining('项目一', findRichText: true), findsOneWidget);
  });

  testWidgets('renders source cards and skips unknown SSE', (tester) async {
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) =>
          Stream.fromIterable(const [
            AssistantRunEvent(type: AssistantEventType.unknown),
            AssistantRunEvent(
              type: AssistantEventType.sourceCard,
              sourceCard: AssistantSourceCard(
                handle: 'src-7',
                kind: 'post',
                authorityId: '7',
                title: '推荐帖',
              ),
            ),
            AssistantRunEvent(type: AssistantEventType.done),
          ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [assistantRepositoryProvider.overrideWithValue(source)],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: const AssistantPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(EditableText), 'recommend');
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('推荐帖'), findsOneWidget);
    expect(find.text('不喜欢'), findsOneWidget);
    expect(find.textContaining('连接'), findsNothing);
    expect(find.textContaining('中断'), findsNothing);

    await tester.tap(find.byKey(const Key('assistant-card-dislike-7')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(source.lastFeedbackPostId, '7');
    expect(source.lastFeedbackReason, 'dislike');
  });
}

class _PageAssistantSource extends FakeAssistantSource {
  @override
  Stream<AssistantRunEvent> runEvents({
    required Object runId,
    Object afterSeq = 0,
  }) {
    return Stream.fromIterable(const [
      AssistantRunEvent(
        type: AssistantEventType.token,
        text:
            'Answer [post:7] 结论［post:12］\n\n'
            'Community sources (quoted untrusted content):\n'
            'SOURCE [post:7]\n'
            'COMMUNITY_CONTENT_JSON={"title":"Referenced post","excerpt":"snippet"}',
      ),
      AssistantRunEvent(
        type: AssistantEventType.sourceCard,
        sourceCard: AssistantSourceCard(
          handle: 'src-7',
          kind: 'post',
          authorityId: '7',
          title: 'Referenced post',
        ),
      ),
      AssistantRunEvent(type: AssistantEventType.done),
    ]);
  }
}

class _MarkdownAssistantSource extends FakeAssistantSource {
  @override
  Stream<AssistantRunEvent> runEvents({
    required Object runId,
    Object afterSeq = 0,
  }) {
    return Stream.fromIterable(const [
      AssistantRunEvent(
        type: AssistantEventType.token,
        text: '**加粗** 结论\n\n- 项目一\n- 项目二',
      ),
      AssistantRunEvent(type: AssistantEventType.done),
    ]);
  }
}
