import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/message/application/message_notifiers.dart';
import 'package:xiaobaihe_app/features/message/data/message_models.dart';
import 'package:xiaobaihe_app/features/message/data/message_repository.dart';
import 'package:xiaobaihe_app/features/message/presentation/conversations_page.dart';

import '../../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('renders and opens a conversation', (tester) async {
    ConversationSummary? opened;
    final source = _ConversationSource();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageRepositoryProvider.overrideWithValue(source),
          conversationListProvider.overrideWith(
            (ref) => ConversationListNotifier(repository: source),
          ),
          unreadSummaryProvider.overrideWith(
            (ref) => UnreadSummaryNotifier(repository: source),
          ),
        ],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: ConversationsPage(
            onOpenConversation: (value) => opened = value,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Target user'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('通知 3'), findsOneWidget);
    expect(find.bySemanticsLabel('打开 Assistant'), findsOneWidget);
    await tester.tap(find.text('Target user'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(opened?.id, 8);
  });
}

class _ConversationSource implements MessageDataSource {
  @override
  Future<ConversationPage> getConversations({
    int page = 1,
    int pageSize = 20,
  }) async {
    return const ConversationPage(
      conversations: [
        ConversationSummary(
          id: 8,
          targetUserId: 7,
          targetUserName: 'Target user',
          targetUserAvatar: '',
          lastMessage: 'Last message',
          lastMessageTime: 0,
          unreadCount: 2,
        ),
      ],
      total: 1,
    );
  }

  @override
  Future<MessagePage> getMessages({
    required int conversationId,
    int lastId = 0,
    int pageSize = 20,
  }) => throw UnimplementedError();

  @override
  Future<int> sendMessage(SendMessageCommand command) =>
      throw UnimplementedError();

  @override
  Future<void> markConversationRead(int conversationId) async {}

  @override
  Future<UnreadSummary> getUnreadSummary() async {
    return const UnreadSummary(messageUnread: 2, notificationUnread: 3);
  }
}
