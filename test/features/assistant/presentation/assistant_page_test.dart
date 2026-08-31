import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_thread_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/presentation/assistant_page.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';

import '../../../helpers/forui_test_builder.dart';
import '../helpers/fake_assistant_source.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders streamed text and opens a source card only', (
    tester,
  ) async {
    AssistantSourceCard? opened;
    final source = _PageAssistantSource();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantUserKeyProvider.overrideWithValue('test-user'),
          assistantRepositoryProvider.overrideWithValue(source),
        ],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: AssistantPage(
            contextPostId: '99',
            onOpenSource: (source) => opened = source,
          ),
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
    expect(source.postedContextPostIds, ['99']);
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
          assistantUserKeyProvider.overrideWithValue('test-user'),
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
        overrides: [
          assistantUserKeyProvider.overrideWithValue('test-user'),
          assistantRepositoryProvider.overrideWithValue(source),
        ],
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

  testWidgets('revoke consent waits for server success', (tester) async {
    final source = FakeAssistantSource();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantUserKeyProvider.overrideWithValue('test-user'),
          assistantRepositoryProvider.overrideWithValue(source),
        ],
        child: const MaterialApp(
          builder: foruiTestBuilder,
          home: AssistantPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('assistant-revoke-consent')), findsOneWidget);
    source.consentError = const ApiException('revoke failed');
    await tester.tap(find.byKey(const Key('assistant-revoke-consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-confirm-revoke-consent')));
    await tester.pumpAndSettle();
    expect(source.granted, isTrue);
    expect(find.byKey(const Key('assistant-revoke-consent')), findsOneWidget);

    source.consentError = null;
    await tester.tap(find.byKey(const Key('assistant-revoke-consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-confirm-revoke-consent')));
    await tester.pumpAndSettle();
    expect(source.granted, isFalse);
    expect(find.byKey(const Key('assistant-revoke-consent')), findsNothing);
  });

  testWidgets('memory_changed offers retryable undo', (tester) async {
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) =>
          Stream.fromIterable(const [
            AssistantRunEvent(
              type: AssistantEventType.memoryChanged,
              text: '记忆已更新',
              changeId: 12,
              seq: 1,
            ),
            AssistantRunEvent(type: AssistantEventType.done, seq: 2),
          ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantUserKeyProvider.overrideWithValue('test-user'),
          assistantRepositoryProvider.overrideWithValue(source),
        ],
        child: const MaterialApp(
          builder: foruiTestBuilder,
          home: AssistantPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'remember');
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pumpAndSettle();

    source.undoError = const ApiException('undo failed');
    await tester.tap(find.text('撤销这次记忆变更'));
    await tester.pumpAndSettle();
    expect(find.text('撤销这次记忆变更'), findsOneWidget);

    source.undoError = null;
    await tester.tap(find.text('撤销这次记忆变更'));
    await tester.pumpAndSettle();
    expect(find.text('记忆变更已撤销'), findsOneWidget);
  });

  testWidgets('open thread receives a new Watch message after thread refresh', (
    tester,
  ) async {
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantUserKeyProvider.overrideWithValue('test-user'),
          assistantRepositoryProvider.overrideWithValue(source),
        ],
        child: const MaterialApp(
          builder: foruiTestBuilder,
          home: AssistantPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('existing'), findsOneWidget);

    source
      ..thread = const AssistantThreadSummary(
        sessionId: 1,
        lastMessageId: 2,
        lastMessagePreview: 'Watch found a new post',
      )
      ..messages = const [
        AssistantHistoryMessage(
          id: 1,
          sessionId: 1,
          role: 'assistant',
          content: 'existing',
        ),
        AssistantHistoryMessage(
          id: 2,
          sessionId: 1,
          role: 'assistant',
          kind: 'watch',
          content: 'Watch found a new post',
          unread: true,
        ),
      ];
    final context = tester.element(find.byType(AssistantPage));
    await ProviderScope.containerOf(
      context,
    ).read(assistantThreadProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(find.text('Watch found a new post'), findsOneWidget);
  });

  testWidgets(
    'mounted page reloads only the new account history after switch',
    (tester) async {
      final source = FakeAssistantSource();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [assistantRepositoryProvider.overrideWithValue(source)],
          child: const MaterialApp(
            builder: foruiTestBuilder,
            home: AssistantPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final context = tester.element(find.byType(AssistantPage));
      final container = ProviderScope.containerOf(context);
      final auth = container.read(authNotifierProvider.notifier);

      source
        ..thread = const AssistantThreadSummary(sessionId: 1, lastMessageId: 1)
        ..messages = const [
          AssistantHistoryMessage(
            id: 1,
            sessionId: 1,
            role: 'assistant',
            content: 'account A private history',
          ),
        ];
      await auth.onLoginSuccess(1, 'account-a-token');
      await tester.pumpAndSettle();
      expect(container.read(authNotifierProvider).isAuthenticated, isTrue);
      expect(container.read(assistantUserKeyProvider), startsWith('user:1:'));
      expect(container.read(assistantNotifierProvider).isLoaded, isTrue);
      expect(find.text('account A private history'), findsOneWidget);

      source
        ..thread = const AssistantThreadSummary(sessionId: 2, lastMessageId: 2)
        ..messages = const [
          AssistantHistoryMessage(
            id: 2,
            sessionId: 2,
            role: 'assistant',
            content: 'account B private history',
          ),
        ];
      await auth.onLoginSuccess(2, 'account-b-token');
      await tester.pumpAndSettle();

      expect(find.text('account A private history'), findsNothing);
      expect(find.text('account B private history'), findsOneWidget);
    },
  );

  testWidgets('has clear history and no new session action', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantUserKeyProvider.overrideWithValue('test-user'),
          assistantRepositoryProvider.overrideWithValue(FakeAssistantSource()),
        ],
        child: const MaterialApp(
          builder: foruiTestBuilder,
          home: AssistantPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('assistant-clear-history')), findsOneWidget);
    expect(find.byKey(const Key('assistant-new-session')), findsNothing);
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
