import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/message/application/message_notifiers.dart';
import 'package:xiaobaihe_app/features/message/data/message_models.dart';
import 'package:xiaobaihe_app/features/message/data/message_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  test('a successful send wins over an older in-flight thread load', () async {
    final repository = _SendDuringLoadSource();
    final notifier = MessageThreadNotifier(
      repository: repository,
      conversationId: 8,
      targetUserId: 7,
      currentUserId: 1,
      loadImmediately: false,
    );

    final load = notifier.refresh();
    await pumpEventQueue();
    expect(await notifier.send('new message'), isTrue);

    repository.pendingLoad.complete(
      MessagePage(messages: [message(1)], hasMore: false),
    );
    await load;

    expect(notifier.state.messages, hasLength(1));
    expect(notifier.state.messages.single.content, 'new message');
    expect(
      notifier.state.messages.single.createdAt,
      greaterThan(1000000000000),
    );
    expect(repository.markReadCalls, 0);
  });

  test(
    'account switch replaces conversations and ignores the old response',
    () async {
      final first = Completer<ConversationPage>();
      final second = Completer<ConversationPage>();
      final repository = _DelayedConversationSource([first, second]);
      final container = ProviderContainer(
        overrides: [messageRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final auth = container.read(authNotifierProvider.notifier);
      await auth.onLoginSuccess(1, 'access-a', refreshToken: 'refresh-a');
      final subscription = container.listen(
        conversationListProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await pumpEventQueue();
      expect(repository.calls, 1);

      await auth.onLoginSuccess(2, 'access-b', refreshToken: 'refresh-b');
      await pumpEventQueue();
      expect(repository.calls, 2);

      second.complete(_conversationPage(2));
      await pumpEventQueue();
      expect(
        container.read(conversationListProvider).conversations.single.id,
        2,
      );

      first.complete(_conversationPage(1));
      await pumpEventQueue();
      expect(
        container.read(conversationListProvider).conversations.single.id,
        2,
      );
    },
  );
}

ConversationPage _conversationPage(int id) => ConversationPage(
  conversations: [
    ConversationSummary(
      id: id,
      targetUserId: id + 10,
      targetUserName: 'user $id',
      targetUserAvatar: '',
      lastMessage: 'message $id',
      lastMessageTime: id,
      unreadCount: id,
    ),
  ],
  total: 1,
);

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

class _SendDuringLoadSource implements MessageDataSource {
  final pendingLoad = Completer<MessagePage>();
  int markReadCalls = 0;

  @override
  Future<MessagePage> getMessages({
    required Object conversationId,
    Object lastId = 0,
    int pageSize = 20,
  }) => pendingLoad.future;

  @override
  Future<Object> sendMessage(SendMessageCommand command) async => 99;

  @override
  Future<void> markConversationRead(Object conversationId) async {
    markReadCalls++;
  }

  @override
  Future<ConversationPage> getConversations({
    int page = 1,
    int pageSize = 20,
  }) => throw UnimplementedError();

  @override
  Future<UnreadSummary> getUnreadSummary() => throw UnimplementedError();
}

class _DelayedConversationSource implements MessageDataSource {
  final List<Completer<ConversationPage>> responses;
  int calls = 0;

  _DelayedConversationSource(this.responses);

  @override
  Future<ConversationPage> getConversations({int page = 1, int pageSize = 20}) {
    calls++;
    return responses.removeAt(0).future;
  }

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

  @override
  Future<UnreadSummary> getUnreadSummary() => throw UnimplementedError();
}
