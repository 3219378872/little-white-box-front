import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    expect(find.text('question'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
    expect(find.textContaining('[post:'), findsNothing);
    expect(find.text('Referenced post'), findsOneWidget);
    expect(find.text('post:7'), findsOneWidget);
    await tester.tap(find.text('Referenced post'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(opened?.sourceId, '7');
  });

  testWidgets('marker-only answer hides citations but keeps source id', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantRepositoryProvider.overrideWithValue(_PageAssistantSource()),
        ],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: AssistantPage(onOpenSource: (_) {}),
        ),
      ),
    );

    await tester.enterText(find.byType(EditableText), 'question');
    await tester.tap(find.byKey(const Key('assistant-send-or-stop')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Answer [post:'), findsNothing);
    expect(find.text('post:9'), findsOneWidget);
  });
}

class _PageAssistantSource implements AssistantDataSource {
  @override
  Stream<AssistantChatEvent> chat({
    required String message,
    required String requestId,
    String conversationId = '',
  }) {
    return Stream.fromIterable(const [
      AssistantChatEvent(
        type: AssistantEventType.token,
        text: 'Answer [post:7]',
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
        source:           AssistantSourceReference(sourceType: 'post', sourceId: '9', title: ''),
        conversationId: 'conversation-1',
      ),
      AssistantChatEvent(
        type: AssistantEventType.done,
        conversationId: 'conversation-1',
      ),
    ]);
  }
}
