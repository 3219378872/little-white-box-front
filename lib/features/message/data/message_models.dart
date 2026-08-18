class ConversationSummary {
  final int id;
  final int targetUserId;
  final String targetUserName;
  final String targetUserAvatar;
  final String lastMessage;
  final int lastMessageTime;
  final int unreadCount;

  const ConversationSummary({
    required this.id,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetUserAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final id = _integer(json['id']);
    final targetUserId = _integer(json['targetUserId']);
    if (id <= 0 || targetUserId <= 0) {
      throw const FormatException('invalid conversation identity');
    }
    return ConversationSummary(
      id: id,
      targetUserId: targetUserId,
      targetUserName: _string(json['targetUserName']),
      targetUserAvatar: _string(json['targetUserAvatar']),
      lastMessage: _string(json['lastMessage']),
      lastMessageTime: _integer(json['lastMessageTime']),
      unreadCount: _integer(json['unreadCount']),
    );
  }
}

class DirectMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final int receiverId;
  final String content;
  final int msgType;
  final int status;
  final int createdAt;

  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.msgType,
    required this.status,
    required this.createdAt,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    final id = _integer(json['id']);
    final conversationId = _integer(json['conversationId']);
    final senderId = _integer(json['senderId']);
    final receiverId = _integer(json['receiverId']);
    if (id <= 0 || conversationId <= 0 || senderId <= 0 || receiverId <= 0) {
      throw const FormatException('invalid message identity');
    }
    return DirectMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      content: _string(json['content']),
      msgType: _integer(json['msgType']),
      status: _integer(json['status']),
      createdAt: _integer(json['createdAt']),
    );
  }
}

class ConversationPage {
  final List<ConversationSummary> conversations;
  final int total;

  const ConversationPage({required this.conversations, required this.total});
}

class MessagePage {
  final List<DirectMessage> messages;
  final bool hasMore;

  const MessagePage({required this.messages, required this.hasMore});
}

class UnreadSummary {
  final int messageUnread;
  final int notificationUnread;

  const UnreadSummary({this.messageUnread = 0, this.notificationUnread = 0});

  factory UnreadSummary.fromJson(Map<String, dynamic> json) {
    return UnreadSummary(
      messageUnread: _integer(json['messageUnread']),
      notificationUnread: _integer(json['notificationUnread']),
    );
  }
}

class SendMessageCommand {
  final int receiverId;
  final String content;
  final int msgType;
  final String idempotencyKey;
  final int mediaId;

  const SendMessageCommand({
    required this.receiverId,
    required this.content,
    this.msgType = 1,
    required this.idempotencyKey,
    this.mediaId = 0,
  });
}

abstract final class MessageTypes {
  static const int text = 1;
  static const int image = 2;
  static const int video = 3;
  static const int audio = 4;
}

String _string(Object? value) => value?.toString() ?? '';

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
