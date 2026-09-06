import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_thread_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';
import 'package:xiaobaihe_app/features/assistant/presentation/assistant_page.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/post/data/post_repository.dart';

import '../../../helpers/forui_test_builder.dart';
import '../helpers/fake_assistant_source.dart';

final _testAssistantIdentityProvider = StateProvider<String>(
  (ref) => 'account-a',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows loading until the initial history load completes', (
    tester,
  ) async {
    final thread = Completer<AssistantThreadSummary>();
    final source = FakeAssistantSource()..threadHandler = () => thread.future;
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

    expect(find.byKey(const Key('assistant-initial-loading')), findsOneWidget);
    expect(find.byKey(const Key('assistant-empty')), findsNothing);
    expect(find.byKey(const Key('assistant-initial-error')), findsNothing);
    expect(
      tester
          .widget<FButton>(find.byKey(const Key('assistant-send-or-stop')))
          .onPress,
      isNull,
    );
    expect(
      tester
          .widget<FButton>(find.byKey(const Key('assistant-add-attachment')))
          .onPress,
      isNull,
    );
    await tester.tap(find.byKey(const Key('assistant-menu')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<FItem>(find.byKey(const Key('assistant-clear-history')))
          .onPress,
      isNull,
    );
    await tester.tap(find.byKey(const Key('assistant-menu')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pump();
    expect(source.postedRequestIds, isEmpty);

    thread.complete(const AssistantThreadSummary(sessionId: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assistant-initial-loading')), findsNothing);
    expect(find.byKey(const Key('assistant-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-menu')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FItem>(find.byKey(const Key('assistant-clear-history')))
          .onPress,
      isNotNull,
    );
  });

  testWidgets('initial load failure is retryable and not shown as empty', (
    tester,
  ) async {
    final source = FakeAssistantSource()
      ..lastError = const ApiException('首次加载失败');
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
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assistant-initial-error')), findsOneWidget);
    expect(find.byKey(const Key('assistant-empty')), findsNothing);
    expect(find.text('首次加载失败'), findsOneWidget);

    source.lastError = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assistant-initial-error')), findsNothing);
    expect(find.byKey(const Key('assistant-empty')), findsOneWidget);
  });

  testWidgets(
    'send shares a pending granted consent preload without showing grant',
    (tester) async {
      final consent = Completer<AgentConsentStatus>();
      final source = FakeAssistantSource()
        ..loadConsentHandler = () => consent.future;
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
      expect(source.consentReads, 1);

      await tester.enterText(find.byType(EditableText), 'already authorized');
      await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
      await tester.pump();

      expect(source.consentReads, 1);
      expect(source.postedRequestIds, isEmpty);
      expect(find.text('启用小白盒 Agent'), findsNothing);

      consent.complete(
        const AgentConsentStatus(
          granted: true,
          consentVersion: 2,
          currentVersion: 2,
        ),
      );
      await tester.pumpAndSettle();

      expect(source.consentReads, 1);
      expect(source.postedRequestIds, hasLength(1));
      expect(source.lastPostedMessage, 'already authorized');
      expect(find.text('启用小白盒 Agent'), findsNothing);
    },
  );

  testWidgets('send completion preserves text edited while the request waits', (
    tester,
  ) async {
    final response = Completer<AssistantPostResult>();
    final source = FakeAssistantSource()
      ..postHandler =
          ({
            required message,
            required requestId,
            required attachments,
            required contextPostId,
          }) => response.future;
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
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), 'sent text');
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'next draft');

    response.complete(
      const AssistantPostResult(
        messageId: 11,
        sessionId: 1,
        runId: 0,
        disposition: AssistantDisposition.unknown,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(source.lastPostedMessage, 'sent text');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'next draft',
    );
  });

  testWidgets('late send success does not touch a disposed page controller', (
    tester,
  ) async {
    final response = Completer<AssistantPostResult>();
    final source = FakeAssistantSource()
      ..postHandler =
          ({
            required message,
            required requestId,
            required attachments,
            required contextPostId,
          }) => response.future;
    final showPage = ValueNotifier(true);
    addTearDown(showPage.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantUserKeyProvider.overrideWithValue('test-user'),
          assistantRepositoryProvider.overrideWithValue(source),
        ],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: ValueListenableBuilder<bool>(
            valueListenable: showPage,
            builder: (_, visible, _) => visible
                ? const AssistantPage()
                : const Scaffold(body: Text('其他页面')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '迟到响应');
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pump();
    expect(source.postedRequestIds, hasLength(1));

    showPage.value = false;
    await tester.pump();
    response.complete(
      const AssistantPostResult(
        messageId: 1,
        sessionId: 1,
        runId: 0,
        disposition: AssistantDisposition.unknown,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('其他页面'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late authorization grant does not retry from a disposed page', (
    tester,
  ) async {
    var postCalls = 0;
    final source = _DeferredConsentAssistantSource()
      ..postHandler =
          ({
            required message,
            required requestId,
            required attachments,
            required contextPostId,
          }) async {
            postCalls++;
            throw const ApiException('AGENT_NOT_AUTHORIZED');
          };
    final showPage = ValueNotifier(true);
    addTearDown(showPage.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantUserKeyProvider.overrideWithValue('test-user'),
          assistantRepositoryProvider.overrideWithValue(source),
        ],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: ValueListenableBuilder<bool>(
            valueListenable: showPage,
            builder: (_, visible, _) => visible
                ? const AssistantPage()
                : const Scaffold(body: Text('其他页面')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '需要授权');
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意并启用'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(source.consentWriteStarted, isTrue);

    showPage.value = false;
    await tester.pump();
    source.consentWrite.complete();
    await tester.pumpAndSettle();

    expect(postCalls, 1);
    expect(find.text('其他页面'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account switch during consent cannot send the previous draft', (
    tester,
  ) async {
    final source = _DeferredConsentAssistantSource()..granted = false;
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
    await auth.onLoginSuccess(1, 'account-a-token');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(EditableText),
      'account A private draft',
    );
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意并启用'));
    await tester.pump();
    expect(source.consentWriteStarted, isTrue);

    await auth.onLoginSuccess(2, 'account-b-token');
    await tester.pumpAndSettle();
    source.consentWrite.complete();
    await tester.pumpAndSettle();

    expect(source.postedRequestIds, isEmpty);
    expect(find.text('account A private draft'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late attachment upload cannot enter the next account state', (
    tester,
  ) async {
    final source = FakeAssistantSource();
    final uploadRepository = _DeferredUploadRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantRepositoryProvider.overrideWithValue(source),
          assistantImagePickerProvider.overrideWithValue(
            _ImmediateImagePicker(
              XFile.fromData(
                Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47]),
                name: 'account-a.png',
              ),
            ),
          ),
          assistantAttachmentRepositoryProvider.overrideWithValue(
            uploadRepository,
          ),
        ],
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
    await auth.onLoginSuccess(1, 'account-a-token');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assistant-add-attachment')));
    await tester.pump();
    await tester.pump();
    expect(uploadRepository.started, isTrue);

    await auth.onLoginSuccess(2, 'account-b-token');
    await tester.pumpAndSettle();
    uploadRepository.result.complete(
      const UploadedImage(mediaId: 77, url: '/xbh-media/account-a.png'),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(assistantNotifierProvider).pendingAttachments,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid account transitions still clear the previous draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantUserKeyProvider.overrideWith(
            (ref) => ref.watch(_testAssistantIdentityProvider),
          ),
          assistantRepositoryProvider.overrideWithValue(FakeAssistantSource()),
        ],
        child: const MaterialApp(
          builder: foruiTestBuilder,
          home: AssistantPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(AssistantPage));
    final container = ProviderScope.containerOf(context);
    await tester.enterText(
      find.byType(EditableText),
      'account A private draft',
    );

    container.read(_testAssistantIdentityProvider.notifier).state = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      container.read(_testAssistantIdentityProvider.notifier).state =
          'account-b';
    });
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('account A private draft'), findsNothing);
    expect(container.read(assistantUserKeyProvider), 'account-b');
  });

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
    expect(find.text('正在思考'), findsNothing);
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
    expect(find.text('正在思考'), findsNothing);

    await tester.tap(find.byKey(const Key('assistant-card-dislike-7')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(source.lastFeedbackPostId, '7');
    expect(source.lastFeedbackReason, 'dislike');
  });

  testWidgets('reconnect button resumes the active run from its cursor', (
    tester,
  ) async {
    final first = StreamController<AssistantRunEvent>();
    final automaticRetry = StreamController<AssistantRunEvent>();
    final manualReconnect = StreamController<AssistantRunEvent>();
    addTearDown(first.close);
    addTearDown(automaticRetry.close);
    addTearDown(manualReconnect.close);
    var calls = 0;
    final source = FakeAssistantSource()
      ..eventsHandler = ({required runId, required afterSeq}) {
        calls++;
        return switch (calls) {
          1 => first.stream,
          2 => automaticRetry.stream,
          _ => manualReconnect.stream,
        };
      };
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
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), 'reconnect me');
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pump();
    first.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: 'partial',
        seq: 4,
      ),
    );
    await tester.pump();
    first.addError(const AssistantStreamException('first disconnect'));
    await tester.pump();
    automaticRetry.addError(
      const AssistantStreamException('second disconnect'),
    );
    await tester.pumpAndSettle();

    expect(source.eventCalls, [0, 4]);
    expect(find.byKey(const Key('assistant-reconnect')), findsOneWidget);
    expect(find.text('重新连接'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assistant-reconnect')));
    await tester.pump();
    expect(source.eventCalls, [0, 4, 4]);

    manualReconnect.add(
      const AssistantRunEvent(
        type: AssistantEventType.token,
        text: ' recovered',
        seq: 5,
      ),
    );
    manualReconnect.add(
      const AssistantRunEvent(type: AssistantEventType.done, seq: 6),
    );
    await tester.pumpAndSettle();

    expect(find.text('partial recovered'), findsOneWidget);
    expect(find.byKey(const Key('assistant-reconnect')), findsNothing);
  });

  testWidgets('late feedback result is fenced from the next account', (
    tester,
  ) async {
    final source = _DeferredFeedbackAssistantSource();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantUserKeyProvider.overrideWith(
            (ref) => ref.watch(_testAssistantIdentityProvider),
          ),
          assistantRepositoryProvider.overrideWithValue(source),
        ],
        child: const MaterialApp(
          builder: foruiTestBuilder,
          home: AssistantPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'recommend');
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-card-dislike-7')));
    await tester.pump();
    expect(source.feedbackStarted, isTrue);

    final context = tester.element(find.byType(AssistantPage));
    final container = ProviderScope.containerOf(context);
    container.read(_testAssistantIdentityProvider.notifier).state = 'account-b';
    await tester.pumpAndSettle();
    source.feedbackResult.complete();
    await tester.pumpAndSettle();

    expect(source.lastFeedbackPostId, '7');
    expect(find.text('已记录反馈'), findsNothing);
    expect(tester.takeException(), isNull);
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

    await tester.tap(find.byKey(const Key('assistant-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-revoke-consent')), findsOneWidget);
    source.consentError = const ApiException('revoke failed');
    await tester.tap(find.byKey(const Key('assistant-revoke-consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-confirm-revoke-consent')));
    await tester.pumpAndSettle();
    expect(source.granted, isTrue);
    await tester.tap(find.byKey(const Key('assistant-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-revoke-consent')), findsOneWidget);

    source.consentError = null;
    await tester.tap(find.byKey(const Key('assistant-revoke-consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-confirm-revoke-consent')));
    await tester.pumpAndSettle();
    expect(source.granted, isFalse);
    await tester.tap(find.byKey(const Key('assistant-menu')));
    await tester.pumpAndSettle();
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

  testWidgets('retries an unchanged thread snapshot after send completes', (
    tester,
  ) async {
    final response = Completer<AssistantPostResult>();
    final source = FakeAssistantSource()
      ..thread = const AssistantThreadSummary(sessionId: 1, lastMessageId: 1)
      ..messages = const [
        AssistantHistoryMessage(
          id: 1,
          sessionId: 1,
          role: 'assistant',
          content: 'old session message',
        ),
      ];
    source.postHandler =
        ({
          required message,
          required requestId,
          required attachments,
          required contextPostId,
        }) => response.future;
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
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'session transition');
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(source.postedRequestIds, hasLength(1));

    source
      ..thread = const AssistantThreadSummary(sessionId: 2, lastMessageId: 3)
      ..messages = const [
        AssistantHistoryMessage(
          id: 3,
          sessionId: 2,
          role: 'assistant',
          content: 'new session message',
        ),
      ];
    final context = tester.element(find.byType(AssistantPage));
    final container = ProviderScope.containerOf(context);
    await container.read(assistantThreadProvider.notifier).refresh();
    await tester.pump();
    expect(find.text('new session message'), findsNothing);

    response.complete(
      const AssistantPostResult(
        messageId: 2,
        sessionId: 1,
        runId: 20,
        disposition: AssistantDisposition.unknown,
      ),
    );
    await tester.pump();
    await tester.pump();

    await container.read(assistantThreadProvider.notifier).refresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('new session message'), findsOneWidget);
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
      await tester.enterText(
        find.byType(EditableText),
        'account A private draft',
      );

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
      expect(find.text('account A private draft'), findsNothing);
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
    await tester.tap(find.byKey(const Key('assistant-menu')));
    await tester.pumpAndSettle();
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

class _DeferredFeedbackAssistantSource extends FakeAssistantSource {
  final feedbackResult = Completer<void>();
  var feedbackStarted = false;

  @override
  Stream<AssistantRunEvent> runEvents({
    required Object runId,
    Object afterSeq = 0,
  }) {
    return Stream.fromIterable(const [
      AssistantRunEvent(
        type: AssistantEventType.sourceCard,
        sourceCard: AssistantSourceCard(
          handle: 'src-7',
          kind: 'post',
          authorityId: '7',
          title: 'Recommended post',
        ),
      ),
      AssistantRunEvent(type: AssistantEventType.done),
    ]);
  }

  @override
  Future<void> submitRecommendFeedback({
    required Object postId,
    required String reason,
    String requestId = '',
  }) async {
    lastFeedbackPostId = postId;
    lastFeedbackReason = reason;
    feedbackStarted = true;
    await feedbackResult.future;
  }
}

class _DeferredConsentAssistantSource extends FakeAssistantSource {
  final consentWrite = Completer<void>();
  var consentWriteStarted = false;

  @override
  Future<void> setAgentConsent({required bool granted}) async {
    consentWriteStarted = true;
    await consentWrite.future;
    await super.setAgentConsent(granted: granted);
  }
}

class _ImmediateImagePicker extends ImagePicker {
  final XFile file;

  _ImmediateImagePicker(this.file);

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return file;
  }
}

class _DeferredUploadRepository extends PostRepository {
  final result = Completer<UploadedImage>();
  var started = false;

  @override
  Future<UploadedImage> uploadImageMultipart({
    required List<int> bytes,
    required String filename,
  }) {
    started = true;
    return result.future;
  }
}
