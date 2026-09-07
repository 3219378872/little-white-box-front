part of 'mock_router.dart';

Map<String, dynamic> _conversationList(Map<String, String> query) {
  final page = _queryInt(query, 'page', defaultValue: 1);
  final pageSize = _queryInt(query, 'pageSize', defaultValue: 20);
  if (page <= 0 || pageSize <= 0 || pageSize > 100) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final sorted = [..._conversations]
    ..sort(
      (a, b) =>
          (b['lastMessageTime'] as int).compareTo(a['lastMessageTime'] as int),
    );
  final offset = (page - 1) * pageSize;
  return {
    'conversations': sorted.skip(offset).take(pageSize).toList(),
    'total': sorted.length,
  };
}

Map<String, dynamic> _conversationMessages(
  int conversationId,
  Map<String, String> query,
) {
  _conversation(conversationId);
  final lastId = _queryInt(query, 'lastId', defaultValue: 0);
  final pageSize = _queryInt(query, 'pageSize', defaultValue: 20);
  if (lastId < 0 || pageSize <= 0 || pageSize > 100) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final all =
      (_messages[conversationId] ?? const [])
          .where((message) => lastId == 0 || (message['id'] as int) < lastId)
          .map(_copyMap)
          .toList()
        ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
  return {
    'messages': all.take(pageSize).toList(growable: false),
    'hasMore': all.length > pageSize,
  };
}

MockRouterResponse _markRead(int conversationId) {
  _conversation(conversationId)['unreadCount'] = 0;
  return _jsonResponse(const {});
}

Map<String, dynamic> _unreadSummary() {
  final messageUnread = _conversations.fold<int>(
    0,
    (total, conversation) =>
        total + ((conversation['unreadCount'] as num?)?.toInt() ?? 0),
  );
  return {'messageUnread': messageUnread, 'notificationUnread': 0};
}

Map<String, dynamic> _sendMessage(int userId, Map<String, dynamic> body) {
  final receiverId = (body['receiverId'] as num?)?.toInt();
  final content = body['content']?.toString().trim() ?? '';
  final msgType = (body['msgType'] as num?)?.toInt() ?? 0;
  final idempotencyKey = body['idempotencyKey']?.toString().trim() ?? '';
  if (receiverId == null ||
      receiverId <= 0 ||
      content.isEmpty ||
      content.length > 1000 ||
      msgType < 1 ||
      msgType > 4 ||
      idempotencyKey.isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  if (!_users.containsKey(receiverId)) {
    throw const _MockBiz(404, 1001, '用户不存在');
  }
  final existing = _messageIdempotencyKeys[idempotencyKey];
  if (existing != null) return {'messageId': existing};
  Map<String, dynamic>? conversation;
  for (final item in _conversations) {
    if (item['targetUserId'] == receiverId) {
      conversation = item;
      break;
    }
  }
  if (conversation == null) {
    final user = _users[receiverId]!;
    conversation = {
      'id': _nextConversationId++,
      'targetUserId': receiverId,
      'targetUserName': user['nickname'],
      'targetUserAvatar': user['avatarUrl'] ?? '',
      'lastMessage': '',
      'lastMessageTime': 0,
      'unreadCount': 0,
    };
    _conversations.add(conversation);
  }
  final messageId = _nextMessageId++;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final conversationId = conversation['id'] as int;
  _messages.putIfAbsent(conversationId, () => []).add({
    'id': messageId,
    'conversationId': conversationId,
    'senderId': userId,
    'receiverId': receiverId,
    'content': content,
    'msgType': msgType,
    'status': 1,
    'createdAt': now,
  });
  conversation['lastMessage'] = content;
  conversation['lastMessageTime'] = now;
  _messageIdempotencyKeys[idempotencyKey] = messageId;
  return {'messageId': messageId};
}

Map<String, dynamic> _conversation(int conversationId) {
  return _conversations.firstWhere(
    (item) => item['id'] == conversationId,
    orElse: () => throw const _MockBiz(404, 4, '资源不存在'),
  );
}
