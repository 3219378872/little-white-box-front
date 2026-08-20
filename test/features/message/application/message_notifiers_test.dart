import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/message/application/message_notifiers.dart';
import 'package:xiaobaihe_app/features/message/data/message_models.dart';
import 'package:xiaobaihe_app/features/message/data/message_repository.dart';

void main() {
  test('a failed send retries with the same idempotency key', () async {
    final repository = _RetryMessageSource();
    var keyIndex = 0;
    final notifier = MessageThreadNotifier(
      repository: repository,
      conversationId: 8,
      targetUserId: 7,
      currentUserId: 1,
      createKey: () => 'key-${++keyIndex}',
      loadImmediately: false,
    );

    expect(await notifier.send('hello'), isFalse);
    expect(await notifier.retryFailed(), isTrue);
    expect(repository.commands.map((item) => item.idempotencyKey), [
      'key-1',
      'key-1',
    ]);
    expect(notifier.state.messages.single.id, 101);

    expect(await notifier.send('next'), isTrue);
    expect(repository.commands.last.idempotencyKey, 'key-2');
  });

  test(
    'loads older messages before the current page without duplicates',
    () async {
      final repository = _PagedMessageSource();
      final notifier = MessageThreadNotifier(
        repository: repository,
        conversationId: 8,
        targetUserId: 7,
        currentUserId: 1,
        loadImmediately: false,
      );

      await notifier.refresh();
      await notifier.loadOlder();

      expect(notifier.state.messages.map((item) => item.id), [1, 2, 3]);
      expect(repository.lastIds, [0, 2]);
      expect(repository.markReadCalls, 1);
      expect(notifier.state.hasMore, isFalse);
    },
  );

  test('loads the unread summary and exposes both counters', () async {
    final notifier = UnreadSummaryNotifier(
      repository: _UnreadMessageSource(),
      loadImmediately: false,
    );

    await notifier.refresh();

    expect(notifier.state.summary.messageUnread, 5);
    expect(notifier.state.summary.notificationUnread, 2);
    expect(notifier.state.error, isNull);
  });
}

DirectMessage message(int id) => DirectMessage(
  id: id,
  conversationId: 8,
  senderId: id.isEven ? 1 : 7,
  receiverId: id.isEven ? 7 : 1,
  content: 'message $id',
  msgType: 1,
  status: 0,
  createdAt: id,
);

class _RetryMessageSource implements MessageDataSource {
  final List<SendMessageCommand> commands = [];

  @override
  Future<Object> sendMessage(SendMessageCommand command) async {
    commands.add(command);
    if (commands.length == 1) throw Exception('offline');
    return 99 + commands.length;
  }

  @override
  Future<ConversationPage> getConversations({
    int page = 1,
    int pageSize = 20,
  }) => throw UnimplementedError();

  @override
  Future<MessagePage> getMessages({
    required Object conversationId,
    Object lastId = 0,
    int pageSize = 20,
  }) => throw UnimplementedError();

  @override
  Future<void> markConversationRead(Object conversationId) async {}

  @override
  Future<UnreadSummary> getUnreadSummary() => throw UnimplementedError();
}

class _PagedMessageSource implements MessageDataSource {
  final List<Object> lastIds = [];
  int markReadCalls = 0;

  @override
  Future<MessagePage> getMessages({
    required Object conversationId,
    Object lastId = 0,
    int pageSize = 20,
  }) async {
    lastIds.add(lastId);
    return lastId == 0
        ? MessagePage(messages: [message(3), message(2)], hasMore: true)
        : MessagePage(messages: [message(2), message(1)], hasMore: false);
  }

  @override
  Future<ConversationPage> getConversations({
    int page = 1,
    int pageSize = 20,
  }) => throw UnimplementedError();

  @override
  Future<Object> sendMessage(SendMessageCommand command) =>
      throw UnimplementedError();

  @override
  Future<void> markConversationRead(Object conversationId) async {
    markReadCalls++;
  }

  @override
  Future<UnreadSummary> getUnreadSummary() => throw UnimplementedError();
}

class _UnreadMessageSource implements MessageDataSource {
  @override
  Future<UnreadSummary> getUnreadSummary() async {
    return const UnreadSummary(messageUnread: 5, notificationUnread: 2);
  }

  @override
  Future<ConversationPage> getConversations({
    int page = 1,
    int pageSize = 20,
  }) => throw UnimplementedError();

  @override
  Future<MessagePage> getMessages({
    required Object conversationId,
    Object lastId = 0,
    int pageSize = 20,
  }) => throw UnimplementedError();

  @override
  Future<void> markConversationRead(Object conversationId) =>
      throw UnimplementedError();

  @override
  Future<Object> sendMessage(SendMessageCommand command) =>
      throw UnimplementedError();
}
