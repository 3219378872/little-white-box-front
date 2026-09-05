import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/v2_api_client.dart';
import 'package:xiaobaihe_app/features/message/data/message_models.dart';
import 'package:xiaobaihe_app/features/message/data/message_repository.dart';

void main() {
  test(
    'uses conversation, detail cursor, and idempotent send contracts',
    () async {
      final client = _StubV2ApiClient(
        getResponses: [
          {
            'conversations': [conversationJson(8)],
            'total': 1,
          },
          {
            'messages': [messageJson(20)],
            'hasMore': true,
          },
          {'messageUnread': 3, 'notificationUnread': 4},
        ],
        postResponses: [
          {'messageId': 21},
          {},
        ],
      );
      final repository = MessageRepository(client: client);

      final conversations = await repository.getConversations(
        page: 2,
        pageSize: 10,
      );
      final messages = await repository.getMessages(
        conversationId: 8,
        lastId: 30,
        pageSize: 10,
      );
      final messageId = await repository.sendMessage(
        const SendMessageCommand(
          receiverId: 7,
          content: ' hello ',
          idempotencyKey: 'message-key-1',
        ),
      );
      await repository.markConversationRead(8);
      final unread = await repository.getUnreadSummary();

      expect(client.getCalls[0].path, '/api/v2/messages/conversations');
      expect(client.getCalls[0].query, {'page': 2, 'pageSize': 10});
      expect(client.getCalls[1].path, '/api/v2/messages/conversations/8');
      expect(client.getCalls[1].query, {'lastId': '30', 'pageSize': 10});
      expect(client.postCalls.first.body, {
        'receiverId': '7',
        'content': 'hello',
        'msgType': 1,
        'idempotencyKey': 'message-key-1',
      });
      expect(client.postCalls[1].path, '/api/v2/messages/conversations/8/read');
      expect(client.postCalls[1].body, isEmpty);
      expect(client.getCalls[2].path, '/api/v2/messages/unread');
      expect(conversations.conversations.single.id, 8);
      expect(messages.messages.single.id, 20);
      expect(messages.messages.single.mediaId, '9007199254740993');
      expect(messages.hasMore, isTrue);
      expect(messageId, 21);
      expect(unread.messageUnread, 3);
      expect(unread.notificationUnread, 4);
    },
  );
}

Map<String, dynamic> conversationJson(int id) => {
  'id': id,
  'targetUserId': 7,
  'targetUserName': 'Target',
  'targetUserAvatar': '',
  'lastMessage': 'hello',
  'lastMessageTime': 1700000000,
  'unreadCount': 1,
};

Map<String, dynamic> messageJson(int id) => {
  'id': id,
  'conversationId': 8,
  'senderId': 1,
  'receiverId': 7,
  'content': 'hello',
  'msgType': 1,
  'status': 0,
  'createdAt': 1700000000,
  'mediaId': '9007199254740993',
};

class _GetCall {
  final String path;
  final Map<String, Object?> query;

  const _GetCall(this.path, this.query);
}

class _PostCall {
  final String path;
  final Map<String, dynamic> body;

  const _PostCall(this.path, this.body);
}

class _StubV2ApiClient extends V2ApiClient {
  final List<Map<String, dynamic>> getResponses;
  final List<Map<String, dynamic>> postResponses;
  final List<_GetCall> getCalls = [];
  final List<_PostCall> postCalls = [];

  _StubV2ApiClient({required this.getResponses, required this.postResponses});

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    getCalls.add(_GetCall(path, Map.of(query)));
    return getResponses.removeAt(0);
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    postCalls.add(_PostCall(path, Map.of(body)));
    return postResponses.removeAt(0);
  }
}
