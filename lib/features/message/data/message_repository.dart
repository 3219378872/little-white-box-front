import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/api/v2_api_client.dart';
import 'message_models.dart';

/// 私信数据源接口，线程、会话列表与未读汇总只依赖它，测试可替换。
abstract interface class MessageDataSource {
  /// 按页码读取会话列表。
  Future<ConversationPage> getConversations({int page = 1, int pageSize = 20});

  /// 读取会话中的消息；[lastId] 为 0 时取最新一页，否则取比它更早的一页。
  Future<MessagePage> getMessages({
    required Object conversationId,
    Object lastId = 0,
    int pageSize = 20,
  });

  /// 发送私信并返回服务端分配的消息 ID。
  Future<Object> sendMessage(SendMessageCommand command);

  /// 把会话标记为已读。
  Future<void> markConversationRead(Object conversationId);

  /// 读取私信与通知未读汇总。
  Future<UnreadSummary> getUnreadSummary();
}

/// 走 Gateway v2 私信接口（`/api/v2/messages/...`）的实现。
///
/// 发请求前先做本地参数校验，响应解析失败统一转成带中文文案的 [ApiException]。
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
    // GET /api/v2/messages/conversations
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
    // 参数校验：会话 ID 必须为正，翻页游标不能为负。
    if (!jsonInt64IsPositive(conversationId) || (lastId is num && lastId < 0)) {
      throw const ApiException('会话参数无效');
    }
    _validatePage(1, pageSize);
    // GET /api/v2/messages/conversations/{id}；lastId 只在为正时作为翻页游标传出。
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
    // 本地参数校验：类型 1~4、文本不超过 1000 字符、媒体消息须带有效 mediaId、幂等键 1~128 字符，不满足则不发请求。
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
    // POST /api/v2/messages；int64 ID 以不丢精度的 JSON 数字发出。
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
    // POST /api/v2/messages/conversations/{id}/read
    await _client.post(
      '/api/v2/messages/conversations/${jsonInt64Id(conversationId)}/read',
      const {},
    );
  }

  @override
  Future<UnreadSummary> getUnreadSummary() async {
    // GET /api/v2/messages/unread
    final response = await _client.get('/api/v2/messages/unread');
    try {
      return UnreadSummary.fromJson(response);
    } on FormatException {
      throw const ApiException('未读数量响应格式无效');
    }
  }

  // 分页参数本地校验，pageSize 上限 100。
  static void _validatePage(int page, int pageSize) {
    if (page <= 0 || pageSize <= 0 || pageSize > 100) {
      throw const ApiException('消息分页参数无效');
    }
  }

  // 解码必填的结果数组；字段缺失或元素不是对象都视为格式错误。
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

  // 宽松读取总数字段，无法解析时记为 0。
  static int _integer(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
