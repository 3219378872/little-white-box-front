import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/api/v2_api_client.dart';
import 'message_models.dart';

abstract interface class MessageDataSource {
  Future<ConversationPage> getConversations({int page = 1, int pageSize = 20});

  Future<MessagePage> getMessages({
    required Object conversationId,
    Object lastId = 0,
    int pageSize = 20,
  });

  Future<Object> sendMessage(SendMessageCommand command);

  Future<void> markConversationRead(Object conversationId);

  Future<UnreadSummary> getUnreadSummary();
}

class MessageRepository implements MessageDataSource {
  final V2ApiClient _client;

  const MessageRepository({V2ApiClient client = const V2ApiClient()})
    : _client = client;

  @override
  Future<ConversationPage> getConversations({
    int page = 1,
    int pageSize = 20,
  }) async {
    _validatePage(page, pageSize);
    final response = await _client.get(
      '/api/v2/messages/conversations',
      query: {'page': page, 'pageSize': pageSize},
    );
    try {
      return ConversationPage(
        conversations: _list(
          response['conversations'],
          ConversationSummary.fromJson,
        ),
        total: _integer(response['total']),
      );
    } on FormatException {
      throw const ApiException('会话列表响应格式无效');
    }
  }

  @override
  Future<MessagePage> getMessages({
    required Object conversationId,
    Object lastId = 0,
    int pageSize = 20,
  }) async {
    if (!jsonInt64IsPositive(conversationId) ||
        (lastId is num && lastId < 0)) {
      throw const ApiException('会话参数无效');
    }
    _validatePage(1, pageSize);
    final response = await _client.get(
      '/api/v2/messages/conversations/${jsonInt64Id(conversationId)}',
      query: {
        if (jsonInt64IsPositive(lastId)) 'lastId': jsonInt64Id(lastId),
        'pageSize': pageSize,
      },
    );
    try {
      return MessagePage(
        messages: _list(response['messages'], DirectMessage.fromJson),
        hasMore: response['hasMore'] == true,
      );
    } on FormatException {
      throw const ApiException('消息列表响应格式无效');
    }
  }

  @override
  Future<Object> sendMessage(SendMessageCommand command) async {
    final content = command.content.trim();
    final key = command.idempotencyKey.trim();
    if (!jsonInt64IsPositive(command.receiverId) ||
        content.isEmpty ||
        command.msgType < 1 ||
        command.msgType > 4 ||
        (command.msgType == MessageTypes.text && content.length > 1000) ||
        (command.msgType != MessageTypes.text &&
            !jsonInt64IsPositive(command.mediaId)) ||
        key.isEmpty ||
        key.length > 128) {
      throw const ApiException('消息参数无效');
    }
    final response = await _client.post('/api/v2/messages', {
      'receiverId': jsonInt64JsonValue(command.receiverId),
      'content': content,
      'msgType': command.msgType,
      'idempotencyKey': key,
      if (jsonInt64IsPositive(command.mediaId))
        'mediaId': jsonInt64JsonValue(command.mediaId),
    });
    final messageId = response['messageId'];
    if (!jsonInt64IsPositive(messageId)) {
      throw const ApiException('发送消息响应格式无效');
    }
    return messageId;
  }

  @override
  Future<void> markConversationRead(Object conversationId) async {
    if (!jsonInt64IsPositive(conversationId)) {
      throw const ApiException('会话参数无效');
    }
    await _client.post(
      '/api/v2/messages/conversations/${jsonInt64Id(conversationId)}/read',
      const {},
    );
  }

  @override
  Future<UnreadSummary> getUnreadSummary() async {
    final response = await _client.get('/api/v2/messages/unread');
    return UnreadSummary.fromJson(response);
  }

  static void _validatePage(int page, int pageSize) {
    if (page <= 0 || pageSize <= 0 || pageSize > 100) {
      throw const ApiException('消息分页参数无效');
    }
  }

  static List<T> _list<T>(
    Object? value,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (value is! List) throw const FormatException('missing list');
    return value
        .map((item) {
          if (item is! Map) throw const FormatException('invalid list item');
          return decode(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
  }

  static int _integer(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
