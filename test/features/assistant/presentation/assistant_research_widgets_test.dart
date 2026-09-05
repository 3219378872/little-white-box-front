import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/presentation/assistant_research_widgets.dart';

import '../../../helpers/forui_test_builder.dart';

void main() {
  AssistantQuestionRequest question() => AssistantQuestionRequest(
    id: 'q1',
    runId: 21,
    messageId: 31,
    status: 'pending',
    deadlineMs: DateTime.now()
        .add(const Duration(minutes: 30))
        .millisecondsSinceEpoch,
    questions: const [
      AssistantQuestion(
        id: 'priority',
        text: '更看重什么？',
        selection: 'multiple',
        options: [
          AssistantQuestionOption(id: 'cost', label: '使用成本'),
          AssistantQuestionOption(id: 'quality', label: '实际体验'),
        ],
      ),
    ],
  );
  Widget wrap(Widget child) => MaterialApp(
    builder: foruiTestBuilder,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    ),
  );

  testWidgets('questions never preselect and explicit skip stays unknown', (
    tester,
  ) async {
    List<AssistantQuestionAnswer>? submitted;
    await tester.pumpWidget(
      wrap(
        AssistantQuestionCard(
          question: question(),
          onAnswer: (q, answers, continueExpired) async {
            submitted = answers;
            return true;
          },
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.ensureVisible(find.byKey(const Key('question-search-q1')));
    await tester.tap(find.byKey(const Key('question-search-q1')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(submitted!.single.disposition, 'skipped');
    expect(submitted!.single.selectedOptionIds, isEmpty);
  });

  testWidgets('choice and text survive a rejected submission', (tester) async {
    final submissions = <List<AssistantQuestionAnswer>>[];
    await tester.pumpWidget(
      wrap(
        AssistantQuestionCard(
          question: question(),
          onAnswer: (q, answers, continueExpired) async {
            submissions.add(answers);
            return false;
          },
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.tap(find.byKey(const Key('question-priority-cost')));
    await tester.enterText(find.byType(EditableText), '长期使用');
    await tester.ensureVisible(find.byKey(const Key('question-submit-q1')));
    await tester.tap(find.byKey(const Key('question-submit-q1')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('question-submit-q1')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(submissions, hasLength(2));
    expect(submissions.last.single.selectedOptionIds, ['cost']);
    expect(submissions.last.single.text, '长期使用');
  });

  testWidgets(
    'citation locates one source card and external links use verified URL',
    (tester) async {
      Uri? opened;
      const answer = AssistantAnswerPresentation(
        messageId: 32,
        runId: 21,
        blocks: [
          AssistantAnswerBlock(
            id: 'b1',
            kind: 'fact',
            text: '引用材料中的结论。 ![untrusted](https://invalid.example/image.png)',
            citations: [
              AssistantAnswerCitation(handle: 'h1', evidenceIds: ['e1']),
            ],
          ),
        ],
        sources: [
          AssistantResearchSource(
            handle: 'h1',
            kind: 'web',
            authorityId: 'https://example.com/article',
            title: '实际取得的来源',
            url: 'https://example.com/article',
            available: true,
            excerpts: [
              AssistantEvidence(id: 'e1', kind: 'web', text: '实际取得的内容片段。'),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        wrap(
          AssistantResearchAnswer(
            answer: answer,
            openExternal: (uri) async {
              opened = uri;
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('citation-b1-h1')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AssistantResearchSourceCard>(
              find.byType(AssistantResearchSourceCard),
            )
            .highlighted,
        isTrue,
      );
      expect(find.byType(Image), findsNothing);
      await tester.tap(find.byKey(const Key('source-open-h1')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(opened, Uri.parse('https://example.com/article'));
    },
  );

  testWidgets(
    'narrow source card expands and unavailable sources hide excerpts',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = AssistantResearchSource(
        handle: 'h1',
        kind: 'web',
        authorityId: 'https://example.com/a',
        title: '这是一个用于验证窄屏布局的很长来源标题，标题不应与摘要或操作按钮发生重叠',
        url: 'https://example.com/a',
        available: true,
        excerpts: [
          AssistantEvidence(
            id: 'e1',
            kind: 'web',
            text: List.filled(12, '来源的实际片段和必要条件。').join(),
          ),
        ],
      );
      await tester.pumpWidget(
        wrap(AssistantResearchSourceCard(source: source, index: 1)),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('source-expand-h1')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('source-excerpt-h1')))
            .maxLines,
        isNull,
      );
      await tester.pumpWidget(
        wrap(
          const AssistantResearchSourceCard(
            source: AssistantResearchSource(
              handle: 'h2',
              kind: 'post',
              authorityId: '9',
              title: '旧标题',
              url: '/post/9',
              available: false,
              excerpts: [
                AssistantEvidence(id: 'e2', kind: 'post', text: '不再可见的旧内容'),
              ],
            ),
            index: 1,
          ),
        ),
      );
      expect(find.text('不再可见的旧内容'), findsNothing);
      expect(find.byKey(const Key('source-open-h2')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
