// --/home/dev/projects/little/little-white-box-content-community/app/gateway/gateway--

class AssistantChatEvent {
  final String type;

  final String text;

  final AssistantSourceReference? source;

  final bool degraded;

  final String errorCode;

  final String conversationId;
  AssistantChatEvent({
    required this.type,
    required this.text,
    required this.source,
    required this.degraded,
    required this.errorCode,
    required this.conversationId,
  });
  factory AssistantChatEvent.fromJson(Map<String, dynamic> m) {
    return AssistantChatEvent(
      type: m['type'] ?? "",
      text: m['text'] ?? "",
      source: m['source'] == null
          ? null
          : AssistantSourceReference?.fromJson(m['source']),
      degraded: m['degraded'] ?? false,
      errorCode: m['errorCode'] ?? "",
      conversationId: m['conversationId'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'text': text,
      'source': source?.toJson(),
      'degraded': degraded,
      'errorCode': errorCode,
      'conversationId': conversationId,
    };
  }
}

class AssistantChatReq {
  final String conversationId;

  final String message;

  final String requestId;
  AssistantChatReq({
    required this.conversationId,
    required this.message,
    required this.requestId,
  });
  factory AssistantChatReq.fromJson(Map<String, dynamic> m) {
    return AssistantChatReq(
      conversationId: m['conversationId'] ?? "",
      message: m['message'] ?? "",
      requestId: m['requestId'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'message': message,
      'requestId': requestId,
    };
  }
}

class AssistantSourceReference {
  final String sourceType;

  final String sourceId;

  final String title;

  final num revision;
  AssistantSourceReference({
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.revision,
  });
  factory AssistantSourceReference.fromJson(Map<String, dynamic> m) {
    return AssistantSourceReference(
      sourceType: m['sourceType'] ?? "",
      sourceId: m['sourceId'] ?? "",
      title: m['title'] ?? "",
      revision: m['revision'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'sourceType': sourceType,
      'sourceId': sourceId,
      'title': title,
      'revision': revision,
    };
  }
}

class BehaviorEvent {
  final String clientEventId;

  final num occurredAt;

  final String action;

  final num targetId;

  final String targetType;

  final String scene;

  final String requestId;

  final int? position;

  final int? durationMs;

  final String recallSource;

  final String modelVersion;

  final String experimentId;
  BehaviorEvent({
    required this.clientEventId,
    required this.occurredAt,
    required this.action,
    required this.targetId,
    required this.targetType,
    required this.scene,
    required this.requestId,
    required this.position,
    required this.durationMs,
    required this.recallSource,
    required this.modelVersion,
    required this.experimentId,
  });
  factory BehaviorEvent.fromJson(Map<String, dynamic> m) {
    return BehaviorEvent(
      clientEventId: m['clientEventId'] ?? "",
      occurredAt: m['occurredAt'] ?? 0,
      action: m['action'] ?? "",
      targetId: m['targetId'] ?? 0,
      targetType: m['targetType'] ?? "",
      scene: m['scene'] ?? "",
      requestId: m['requestId'] ?? "",
      position: m['position'] == null ? null : (m['position'] is num) ? (m['position'] as num).toInt() : null,
      durationMs: m['durationMs'] == null
          ? null
          : (m['durationMs'] is num) ? (m['durationMs'] as num).toInt() : null,
      recallSource: m['recallSource'] ?? "",
      modelVersion: m['modelVersion'] ?? "",
      experimentId: m['experimentId'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'clientEventId': clientEventId,
      'occurredAt': occurredAt,
      'action': action,
      'targetId': targetId,
      'targetType': targetType,
      'scene': scene,
      'requestId': requestId,
      'position': position,
      'durationMs': durationMs,
      'recallSource': recallSource,
      'modelVersion': modelVersion,
      'experimentId': experimentId,
    };
  }
}

class BehaviorEventResult {
  final String clientEventId;

  final num eventId;

  final bool accepted;

  final num code;

  final String reason;
  BehaviorEventResult({
    required this.clientEventId,
    required this.eventId,
    required this.accepted,
    required this.code,
    required this.reason,
  });
  factory BehaviorEventResult.fromJson(Map<String, dynamic> m) {
    return BehaviorEventResult(
      clientEventId: m['clientEventId'] ?? "",
      eventId: m['eventId'] ?? 0,
      accepted: m['accepted'] ?? false,
      code: m['code'] ?? 0,
      reason: m['reason'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'clientEventId': clientEventId,
      'eventId': eventId,
      'accepted': accepted,
      'code': code,
      'reason': reason,
    };
  }
}

class CommentItem {
  final num id;

  final num userId;

  final String userName;

  final String userAvatar;

  final num parentId;

  final num replyUserId;

  final String content;

  final num likeCount;

  final num createdAt;
  CommentItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.parentId,
    required this.replyUserId,
    required this.content,
    required this.likeCount,
    required this.createdAt,
  });
  factory CommentItem.fromJson(Map<String, dynamic> m) {
    return CommentItem(
      id: m['id'] ?? 0,
      userId: m['userId'] ?? 0,
      userName: m['userName'] ?? "",
      userAvatar: m['userAvatar'] ?? "",
      parentId: m['parentId'] ?? 0,
      replyUserId: m['replyUserId'] ?? 0,
      content: m['content'] ?? "",
      likeCount: m['likeCount'] ?? 0,
      createdAt: m['createdAt'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'parentId': parentId,
      'replyUserId': replyUserId,
      'content': content,
      'likeCount': likeCount,
      'createdAt': createdAt,
    };
  }
}

class ConversationItem {
  final num id;

  final num targetUserId;

  final String targetUserName;

  final String targetUserAvatar;

  final String lastMessage;

  final num lastMessageTime;

  final num unreadCount;
  ConversationItem({
    required this.id,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetUserAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
  });
  factory ConversationItem.fromJson(Map<String, dynamic> m) {
    return ConversationItem(
      id: m['id'] ?? 0,
      targetUserId: m['targetUserId'] ?? 0,
      targetUserName: m['targetUserName'] ?? "",
      targetUserAvatar: m['targetUserAvatar'] ?? "",
      lastMessage: m['lastMessage'] ?? "",
      lastMessageTime: m['lastMessageTime'] ?? 0,
      unreadCount: m['unreadCount'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'targetUserId': targetUserId,
      'targetUserName': targetUserName,
      'targetUserAvatar': targetUserAvatar,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'unreadCount': unreadCount,
    };
  }
}

class CreateCommentReq {
  final num postId;

  final num parentId;

  final num replyUserId;

  final String content;

  final String idempotencyKey;
  CreateCommentReq({
    required this.postId,
    required this.parentId,
    required this.replyUserId,
    required this.content,
    required this.idempotencyKey,
  });
  factory CreateCommentReq.fromJson(Map<String, dynamic> m) {
    return CreateCommentReq(
      postId: m['postId'] ?? 0,
      parentId: m['parentId'] ?? 0,
      replyUserId: m['replyUserId'] ?? 0,
      content: m['content'] ?? "",
      idempotencyKey: m['idempotencyKey'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'parentId': parentId,
      'replyUserId': replyUserId,
      'content': content,
      'idempotencyKey': idempotencyKey,
    };
  }
}

class CreateCommentResp {
  final num commentId;
  CreateCommentResp({required this.commentId});
  factory CreateCommentResp.fromJson(Map<String, dynamic> m) {
    return CreateCommentResp(commentId: m['commentId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'commentId': commentId};
  }
}

class CreatePostReq {
  final String title;

  final String content;

  final List<String> images;

  final List<String> tags;

  // 0:草稿 1:发布
  final num status;

  final String idempotencyKey;

  final List<int> mediaIds;
  CreatePostReq({
    required this.title,
    required this.content,
    required this.images,
    required this.tags,
    required this.status,
    required this.idempotencyKey,
    required this.mediaIds,
  });
  factory CreatePostReq.fromJson(Map<String, dynamic> m) {
    return CreatePostReq(
      title: m['title'] ?? "",
      content: m['content'] ?? "",
      images: m['images']?.cast<String>() ?? [],
      tags: m['tags']?.cast<String>() ?? [],
      status: m['status'] ?? 0,
      idempotencyKey: m['idempotencyKey'] ?? "",
      mediaIds: m['mediaIds']?.cast<int>() ?? [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'images': images,
      'tags': tags,
      'status': status,
      'idempotencyKey': idempotencyKey,
      'mediaIds': mediaIds,
    };
  }
}

class CreatePostResp {
  final num postId;

  final num status;

  final num revision;
  CreatePostResp({
    required this.postId,
    required this.status,
    required this.revision,
  });
  factory CreatePostResp.fromJson(Map<String, dynamic> m) {
    return CreatePostResp(
      postId: m['postId'] ?? 0,
      status: m['status'] ?? 0,
      revision: m['revision'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'postId': postId, 'status': status, 'revision': revision};
  }
}

class DeleteCommentReq {
  final num commentId;
  DeleteCommentReq({required this.commentId});
  factory DeleteCommentReq.fromJson(Map<String, dynamic> m) {
    return DeleteCommentReq(commentId: m['commentId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'commentId': commentId};
  }
}

class DeleteCommentResp {
  DeleteCommentResp();
  factory DeleteCommentResp.fromJson(Map<String, dynamic> m) {
    return DeleteCommentResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class DeletePostResp {
  DeletePostResp();
  factory DeletePostResp.fromJson(Map<String, dynamic> m) {
    return DeletePostResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class DeletePostV2Req {
  final num postId;

  // 必填；缺失/0 → 参数错误
  final num expectedRevision;
  DeletePostV2Req({required this.postId, required this.expectedRevision});
  factory DeletePostV2Req.fromJson(Map<String, dynamic> m) {
    return DeletePostV2Req(
      postId: m['postId'] ?? 0,
      expectedRevision: m['expectedRevision'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'postId': postId, 'expectedRevision': expectedRevision};
  }
}

class FavoriteReq {
  final num postId;
  FavoriteReq({required this.postId});
  factory FavoriteReq.fromJson(Map<String, dynamic> m) {
    return FavoriteReq(postId: m['postId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'postId': postId};
  }
}

class FavoriteResp {
  FavoriteResp();
  factory FavoriteResp.fromJson(Map<String, dynamic> m) {
    return FavoriteResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class FeedItem {
  final num postId;

  final num authorId;

  final String authorName;

  final String authorAvatar;

  final num createdAt;

  final num feedType;

  final String title;

  final String content;

  final List<String> images;

  final List<String> tags;

  final num viewCount;

  final num likeCount;

  final num commentCount;

  final num favoriteCount;

  final bool isLiked;
  FeedItem({
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.createdAt,
    required this.feedType,
    required this.title,
    required this.content,
    required this.images,
    required this.tags,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    required this.isLiked,
  });
  factory FeedItem.fromJson(Map<String, dynamic> m) {
    return FeedItem(
      postId: m['postId'] ?? 0,
      authorId: m['authorId'] ?? 0,
      authorName: m['authorName'] ?? "",
      authorAvatar: m['authorAvatar'] ?? "",
      createdAt: m['createdAt'] ?? 0,
      feedType: m['feedType'] ?? 0,
      title: m['title'] ?? "",
      content: m['content'] ?? "",
      images: m['images']?.cast<String>() ?? [],
      tags: m['tags']?.cast<String>() ?? [],
      viewCount: m['viewCount'] ?? 0,
      likeCount: m['likeCount'] ?? 0,
      commentCount: m['commentCount'] ?? 0,
      favoriteCount: m['favoriteCount'] ?? 0,
      isLiked: m['isLiked'] ?? false,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'createdAt': createdAt,
      'feedType': feedType,
      'title': title,
      'content': content,
      'images': images,
      'tags': tags,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'favoriteCount': favoriteCount,
      'isLiked': isLiked,
    };
  }
}

class FollowReq {
  final num targetUserId;
  FollowReq({required this.targetUserId});
  factory FollowReq.fromJson(Map<String, dynamic> m) {
    return FollowReq(targetUserId: m['targetUserId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'targetUserId': targetUserId};
  }
}

class FollowResp {
  FollowResp();
  factory FollowResp.fromJson(Map<String, dynamic> m) {
    return FollowResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class GetCommentListReq {
  final num postId;

  final num page;

  final num pageSize;

  // 1:最新 2:最热
  final num sortBy;
  GetCommentListReq({
    required this.postId,
    required this.page,
    required this.pageSize,
    required this.sortBy,
  });
  factory GetCommentListReq.fromJson(Map<String, dynamic> m) {
    return GetCommentListReq(
      postId: m['postId'] ?? 0,
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
      sortBy: m['sortBy'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'page': page,
      'pageSize': pageSize,
      'sortBy': sortBy,
    };
  }
}

class GetCommentListResp {
  final List<CommentItem> list;

  final num total;

  final num page;

  final num pageSize;
  GetCommentListResp({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  factory GetCommentListResp.fromJson(Map<String, dynamic> m) {
    return GetCommentListResp(
      list: ((m['list'] ?? []) as List<dynamic>)
          .map((i) => CommentItem.fromJson(i))
          .toList(),
      total: m['total'] ?? 0,
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'list': list.map((i) => i.toJson()),
      'total': total,
      'page': page,
      'pageSize': pageSize,
    };
  }
}

class GetConversationsReq {
  final num page;

  final num pageSize;
  GetConversationsReq({required this.page, required this.pageSize});
  factory GetConversationsReq.fromJson(Map<String, dynamic> m) {
    return GetConversationsReq(
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'page': page, 'pageSize': pageSize};
  }
}

class GetConversationsResp {
  final List<ConversationItem> conversations;

  final num total;
  GetConversationsResp({required this.conversations, required this.total});
  factory GetConversationsResp.fromJson(Map<String, dynamic> m) {
    return GetConversationsResp(
      conversations: ((m['conversations'] ?? []) as List<dynamic>)
          .map((i) => ConversationItem.fromJson(i))
          .toList(),
      total: m['total'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'conversations': conversations.map((i) => i.toJson()),
      'total': total,
    };
  }
}

class GetFollowFeedReq {
  final num cursorCreatedAt;

  final num cursorPostId;

  final num pageSize;
  GetFollowFeedReq({
    required this.cursorCreatedAt,
    required this.cursorPostId,
    required this.pageSize,
  });
  factory GetFollowFeedReq.fromJson(Map<String, dynamic> m) {
    return GetFollowFeedReq(
      cursorCreatedAt: m['cursorCreatedAt'] ?? 0,
      cursorPostId: m['cursorPostId'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'cursorCreatedAt': cursorCreatedAt,
      'cursorPostId': cursorPostId,
      'pageSize': pageSize,
    };
  }
}

class GetFollowFeedResp {
  final List<FeedItem> items;

  final bool hasMore;

  final num nextCursorCreatedAt;

  final num nextCursorPostId;
  GetFollowFeedResp({
    required this.items,
    required this.hasMore,
    required this.nextCursorCreatedAt,
    required this.nextCursorPostId,
  });
  factory GetFollowFeedResp.fromJson(Map<String, dynamic> m) {
    return GetFollowFeedResp(
      items: ((m['items'] ?? []) as List<dynamic>)
          .map((i) => FeedItem.fromJson(i))
          .toList(),
      hasMore: m['hasMore'] ?? false,
      nextCursorCreatedAt: m['nextCursorCreatedAt'] ?? 0,
      nextCursorPostId: m['nextCursorPostId'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'items': items.map((i) => i.toJson()),
      'hasMore': hasMore,
      'nextCursorCreatedAt': nextCursorCreatedAt,
      'nextCursorPostId': nextCursorPostId,
    };
  }
}

class GetMessagesReq {
  final num conversationId;

  final num lastId;

  final num pageSize;
  GetMessagesReq({
    required this.conversationId,
    required this.lastId,
    required this.pageSize,
  });
  factory GetMessagesReq.fromJson(Map<String, dynamic> m) {
    return GetMessagesReq(
      conversationId: m['id'] ?? 0,
      lastId: m['lastId'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'id': conversationId, 'lastId': lastId, 'pageSize': pageSize};
  }
}

class GetMessagesResp {
  final List<MessageItem> messages;

  final bool hasMore;
  GetMessagesResp({required this.messages, required this.hasMore});
  factory GetMessagesResp.fromJson(Map<String, dynamic> m) {
    return GetMessagesResp(
      messages: ((m['messages'] ?? []) as List<dynamic>)
          .map((i) => MessageItem.fromJson(i))
          .toList(),
      hasMore: m['hasMore'] ?? false,
    );
  }
  Map<String, dynamic> toJson() {
    return {'messages': messages.map((i) => i.toJson()), 'hasMore': hasMore};
  }
}

class GetPersonalizationPreferenceResp {
  final bool enabled;

  final num optedOutAt;
  GetPersonalizationPreferenceResp({
    required this.enabled,
    required this.optedOutAt,
  });
  factory GetPersonalizationPreferenceResp.fromJson(Map<String, dynamic> m) {
    return GetPersonalizationPreferenceResp(
      enabled: m['enabled'] ?? false,
      optedOutAt: m['optedOutAt'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'enabled': enabled, 'optedOutAt': optedOutAt};
  }
}

class GetPostListReq {
  final num page;

  final num pageSize;

  // 1:最新 2:热门 3:推荐
  final num sortBy;
  GetPostListReq({
    required this.page,
    required this.pageSize,
    required this.sortBy,
  });
  factory GetPostListReq.fromJson(Map<String, dynamic> m) {
    return GetPostListReq(
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
      sortBy: m['sortBy'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'page': page, 'pageSize': pageSize, 'sortBy': sortBy};
  }
}

class GetPostListResp {
  final List<PostItem> list;

  final num total;

  final num page;

  final num pageSize;
  GetPostListResp({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  factory GetPostListResp.fromJson(Map<String, dynamic> m) {
    return GetPostListResp(
      list: ((m['list'] ?? []) as List<dynamic>)
          .map((i) => PostItem.fromJson(i))
          .toList(),
      total: m['total'] ?? 0,
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'list': list.map((i) => i.toJson()),
      'total': total,
      'page': page,
      'pageSize': pageSize,
    };
  }
}

class GetPostReq {
  final num postId;
  GetPostReq({required this.postId});
  factory GetPostReq.fromJson(Map<String, dynamic> m) {
    return GetPostReq(postId: m['postId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'postId': postId};
  }
}

class GetPostResp {
  final num id;

  final num authorId;

  final String authorName;

  final String authorAvatar;

  final String title;

  final String content;

  final List<String> images;

  final List<String> tags;

  final num status;

  final num viewCount;

  final num likeCount;

  final num commentCount;

  final num favoriteCount;

  final bool isLiked;

  final bool isFavorited;

  final num revision;

  final num createdAt;
  GetPostResp({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.title,
    required this.content,
    required this.images,
    required this.tags,
    required this.status,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    required this.isLiked,
    required this.isFavorited,
    required this.revision,
    required this.createdAt,
  });
  factory GetPostResp.fromJson(Map<String, dynamic> m) {
    return GetPostResp(
      id: m['id'] ?? 0,
      authorId: m['authorId'] ?? 0,
      authorName: m['authorName'] ?? "",
      authorAvatar: m['authorAvatar'] ?? "",
      title: m['title'] ?? "",
      content: m['content'] ?? "",
      images: m['images']?.cast<String>() ?? [],
      tags: m['tags']?.cast<String>() ?? [],
      status: m['status'] ?? 0,
      viewCount: m['viewCount'] ?? 0,
      likeCount: m['likeCount'] ?? 0,
      commentCount: m['commentCount'] ?? 0,
      favoriteCount: m['favoriteCount'] ?? 0,
      isLiked: m['isLiked'] ?? false,
      isFavorited: m['isFavorited'] ?? false,
      revision: m['revision'] ?? 0,
      createdAt: m['createdAt'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'title': title,
      'content': content,
      'images': images,
      'tags': tags,
      'status': status,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'favoriteCount': favoriteCount,
      'isLiked': isLiked,
      'isFavorited': isFavorited,
      'revision': revision,
      'createdAt': createdAt,
    };
  }
}

class GetRecommendFeedReq {
  final String anonymousId;

  final String scene;

  final String requestId;

  final String sessionId;

  final String cursor;

  final num pageSize;

  final String experimentId;
  GetRecommendFeedReq({
    required this.anonymousId,
    required this.scene,
    required this.requestId,
    required this.sessionId,
    required this.cursor,
    required this.pageSize,
    required this.experimentId,
  });
  factory GetRecommendFeedReq.fromJson(Map<String, dynamic> m) {
    return GetRecommendFeedReq(
      anonymousId: m['anonymousId'] ?? "",
      scene: m['scene'] ?? "",
      requestId: m['requestId'] ?? "",
      sessionId: m['sessionId'] ?? "",
      cursor: m['cursor'] ?? "",
      pageSize: m['pageSize'] ?? 0,
      experimentId: m['experimentId'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'anonymousId': anonymousId,
      'scene': scene,
      'requestId': requestId,
      'sessionId': sessionId,
      'cursor': cursor,
      'pageSize': pageSize,
      'experimentId': experimentId,
    };
  }
}

class GetRecommendFeedResp {
  final List<RecommendFeedItem> items;

  final String nextCursor;

  final bool hasMore;

  final String requestId;
  GetRecommendFeedResp({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.requestId,
  });
  factory GetRecommendFeedResp.fromJson(Map<String, dynamic> m) {
    return GetRecommendFeedResp(
      items: ((m['items'] ?? []) as List<dynamic>)
          .map((i) => RecommendFeedItem.fromJson(i))
          .toList(),
      nextCursor: m['nextCursor'] ?? "",
      hasMore: m['hasMore'] ?? false,
      requestId: m['requestId'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'items': items.map((i) => i.toJson()),
      'nextCursor': nextCursor,
      'hasMore': hasMore,
      'requestId': requestId,
    };
  }
}

class GetUnreadSummaryResp {
  final num messageUnread;

  final num notificationUnread;
  GetUnreadSummaryResp({
    required this.messageUnread,
    required this.notificationUnread,
  });
  factory GetUnreadSummaryResp.fromJson(Map<String, dynamic> m) {
    return GetUnreadSummaryResp(
      messageUnread: m['messageUnread'] ?? 0,
      notificationUnread: m['notificationUnread'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'messageUnread': messageUnread,
      'notificationUnread': notificationUnread,
    };
  }
}

class GetUserFavoritesReq {
  final num userId;

  final num page;

  final num pageSize;
  GetUserFavoritesReq({
    required this.userId,
    required this.page,
    required this.pageSize,
  });
  factory GetUserFavoritesReq.fromJson(Map<String, dynamic> m) {
    return GetUserFavoritesReq(
      userId: m['userId'] ?? 0,
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'userId': userId, 'page': page, 'pageSize': pageSize};
  }
}

class GetUserPostsReq {
  final num userId;

  final num page;

  final num pageSize;

  final num sortBy;
  GetUserPostsReq({
    required this.userId,
    required this.page,
    required this.pageSize,
    required this.sortBy,
  });
  factory GetUserPostsReq.fromJson(Map<String, dynamic> m) {
    return GetUserPostsReq(
      userId: m['userId'] ?? 0,
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
      sortBy: m['sortBy'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'page': page,
      'pageSize': pageSize,
      'sortBy': sortBy,
    };
  }
}

class GetUserReq {
  final num userId;
  GetUserReq({required this.userId});
  factory GetUserReq.fromJson(Map<String, dynamic> m) {
    return GetUserReq(userId: m['userId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'userId': userId};
  }
}

class GetUserResp {
  final num id;

  final String username;

  final String nickname;

  final String avatarUrl;

  final String bio;

  final num level;

  final num followerCount;

  final num followingCount;

  final num postCount;

  final bool favoritesVisible;
  GetUserResp({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatarUrl,
    required this.bio,
    required this.level,
    required this.followerCount,
    required this.followingCount,
    required this.postCount,
    required this.favoritesVisible,
  });
  factory GetUserResp.fromJson(Map<String, dynamic> m) {
    return GetUserResp(
      id: m['id'] ?? 0,
      username: m['username'] ?? "",
      nickname: m['nickname'] ?? "",
      avatarUrl: m['avatarUrl'] ?? "",
      bio: m['bio'] ?? "",
      level: m['level'] ?? 0,
      followerCount: m['followerCount'] ?? 0,
      followingCount: m['followingCount'] ?? 0,
      postCount: m['postCount'] ?? 0,
      favoritesVisible: m['favoritesVisible'] ?? false,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'level': level,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'postCount': postCount,
      'favoritesVisible': favoritesVisible,
    };
  }
}

class HealthReadyResp {
  // ready | degraded | unavailable
  final String status;

  // name -> ok | down
  final Map<String, String> dependencies;
  HealthReadyResp({required this.status, required this.dependencies});
  factory HealthReadyResp.fromJson(Map<String, dynamic> m) {
    return HealthReadyResp(
      status: m['status'] ?? "",
      dependencies: Map<String, String>.from(m['dependencies'] ?? {}),
    );
  }
  Map<String, dynamic> toJson() {
    return {'status': status, 'dependencies': dependencies};
  }
}

class HealthReq {
  HealthReq();
  factory HealthReq.fromJson(Map<String, dynamic> m) {
    return HealthReq();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class HealthResp {
  final String status;
  HealthResp({required this.status});
  factory HealthResp.fromJson(Map<String, dynamic> m) {
    return HealthResp(status: m['status'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'status': status};
  }
}

class LikeReq {
  final num targetId;

  // 1:帖子 2:评论
  final num targetType;
  LikeReq({required this.targetId, required this.targetType});
  factory LikeReq.fromJson(Map<String, dynamic> m) {
    return LikeReq(
      targetId: m['targetId'] ?? 0,
      targetType: m['targetType'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'targetId': targetId, 'targetType': targetType};
  }
}

class LikeResp {
  LikeResp();
  factory LikeResp.fromJson(Map<String, dynamic> m) {
    return LikeResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class LoginReq {
  final String username;

  final String password;

  final String phone;

  final String verifyCode;

  // 1:密码登录 2:验证码登录
  final num loginType;
  LoginReq({
    required this.username,
    required this.password,
    required this.phone,
    required this.verifyCode,
    required this.loginType,
  });
  factory LoginReq.fromJson(Map<String, dynamic> m) {
    return LoginReq(
      username: m['username'] ?? "",
      password: m['password'] ?? "",
      phone: m['phone'] ?? "",
      verifyCode: m['verifyCode'] ?? "",
      loginType: m['loginType'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'phone': phone,
      'verifyCode': verifyCode,
      'loginType': loginType,
    };
  }
}

class LoginResp {
  final num userId;

  final String token;
  LoginResp({required this.userId, required this.token});
  factory LoginResp.fromJson(Map<String, dynamic> m) {
    return LoginResp(userId: m['userId'] ?? 0, token: m['token'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'userId': userId, 'token': token};
  }
}

class MarkConversationReadReq {
  final num conversationId;
  MarkConversationReadReq({required this.conversationId});
  factory MarkConversationReadReq.fromJson(Map<String, dynamic> m) {
    return MarkConversationReadReq(conversationId: m['id'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'id': conversationId};
  }
}

class MarkConversationReadResp {
  MarkConversationReadResp();
  factory MarkConversationReadResp.fromJson(Map<String, dynamic> m) {
    return MarkConversationReadResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class MessageItem {
  final num id;

  final num conversationId;

  final num senderId;

  final num receiverId;

  final String content;

  final num msgType;

  final num status;

  final num createdAt;
  MessageItem({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.msgType,
    required this.status,
    required this.createdAt,
  });
  factory MessageItem.fromJson(Map<String, dynamic> m) {
    return MessageItem(
      id: m['id'] ?? 0,
      conversationId: m['conversationId'] ?? 0,
      senderId: m['senderId'] ?? 0,
      receiverId: m['receiverId'] ?? 0,
      content: m['content'] ?? "",
      msgType: m['msgType'] ?? 0,
      status: m['status'] ?? 0,
      createdAt: m['createdAt'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'msgType': msgType,
      'status': status,
      'createdAt': createdAt,
    };
  }
}

class PostItem {
  final num id;

  final num authorId;

  final String authorName;

  final String authorAvatar;

  final String title;

  final String content;

  final List<String> images;

  final List<String> tags;

  final num status;

  final num viewCount;

  final num likeCount;

  final num commentCount;

  final num favoriteCount;

  final bool isLiked;

  final bool isFavorited;

  final num revision;

  final num createdAt;
  PostItem({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.title,
    required this.content,
    required this.images,
    required this.tags,
    required this.status,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    required this.isLiked,
    required this.isFavorited,
    required this.revision,
    required this.createdAt,
  });
  factory PostItem.fromJson(Map<String, dynamic> m) {
    return PostItem(
      id: m['id'] ?? 0,
      authorId: m['authorId'] ?? 0,
      authorName: m['authorName'] ?? "",
      authorAvatar: m['authorAvatar'] ?? "",
      title: m['title'] ?? "",
      content: m['content'] ?? "",
      images: m['images']?.cast<String>() ?? [],
      tags: m['tags']?.cast<String>() ?? [],
      status: m['status'] ?? 0,
      viewCount: m['viewCount'] ?? 0,
      likeCount: m['likeCount'] ?? 0,
      commentCount: m['commentCount'] ?? 0,
      favoriteCount: m['favoriteCount'] ?? 0,
      isLiked: m['isLiked'] ?? false,
      isFavorited: m['isFavorited'] ?? false,
      revision: m['revision'] ?? 0,
      createdAt: m['createdAt'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'title': title,
      'content': content,
      'images': images,
      'tags': tags,
      'status': status,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'favoriteCount': favoriteCount,
      'isLiked': isLiked,
      'isFavorited': isFavorited,
      'revision': revision,
      'createdAt': createdAt,
    };
  }
}

class RecommendFeedItem {
  final num postId;

  final num authorId;

  final String authorName;

  final String authorAvatar;

  final num createdAt;

  final num feedType;

  final String title;

  final String content;

  final List<String> images;

  final List<String> tags;

  final num viewCount;

  final num likeCount;

  final num commentCount;

  final num favoriteCount;

  final bool isLiked;

  final num score;

  final String reason;

  final String recallSource;

  final String modelVersion;

  final String experimentId;

  final num position;
  RecommendFeedItem({
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.createdAt,
    required this.feedType,
    required this.title,
    required this.content,
    required this.images,
    required this.tags,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    required this.isLiked,
    required this.score,
    required this.reason,
    required this.recallSource,
    required this.modelVersion,
    required this.experimentId,
    required this.position,
  });
  factory RecommendFeedItem.fromJson(Map<String, dynamic> m) {
    return RecommendFeedItem(
      postId: m['postId'] ?? 0,
      authorId: m['authorId'] ?? 0,
      authorName: m['authorName'] ?? "",
      authorAvatar: m['authorAvatar'] ?? "",
      createdAt: m['createdAt'] ?? 0,
      feedType: m['feedType'] ?? 0,
      title: m['title'] ?? "",
      content: m['content'] ?? "",
      images: m['images']?.cast<String>() ?? [],
      tags: m['tags']?.cast<String>() ?? [],
      viewCount: m['viewCount'] ?? 0,
      likeCount: m['likeCount'] ?? 0,
      commentCount: m['commentCount'] ?? 0,
      favoriteCount: m['favoriteCount'] ?? 0,
      isLiked: m['isLiked'] ?? false,
      score: m['score'] ?? 0.0,
      reason: m['reason'] ?? "",
      recallSource: m['recallSource'] ?? "",
      modelVersion: m['modelVersion'] ?? "",
      experimentId: m['experimentId'] ?? "",
      position: m['position'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'createdAt': createdAt,
      'feedType': feedType,
      'title': title,
      'content': content,
      'images': images,
      'tags': tags,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'favoriteCount': favoriteCount,
      'isLiked': isLiked,
      'score': score,
      'reason': reason,
      'recallSource': recallSource,
      'modelVersion': modelVersion,
      'experimentId': experimentId,
      'position': position,
    };
  }
}

class RecordBehaviorEventsReq {
  final String anonymousId;

  final String sessionId;

  final List<BehaviorEvent> events;
  RecordBehaviorEventsReq({
    required this.anonymousId,
    required this.sessionId,
    required this.events,
  });
  factory RecordBehaviorEventsReq.fromJson(Map<String, dynamic> m) {
    return RecordBehaviorEventsReq(
      anonymousId: m['anonymousId'] ?? "",
      sessionId: m['sessionId'] ?? "",
      events: ((m['events'] ?? []) as List<dynamic>)
          .map((i) => BehaviorEvent.fromJson(i))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'anonymousId': anonymousId,
      'sessionId': sessionId,
      'events': events.map((i) => i.toJson()),
    };
  }
}

class RecordBehaviorEventsResp {
  final List<BehaviorEventResult> results;

  final num acceptedCount;

  final num rejectedCount;
  RecordBehaviorEventsResp({
    required this.results,
    required this.acceptedCount,
    required this.rejectedCount,
  });
  factory RecordBehaviorEventsResp.fromJson(Map<String, dynamic> m) {
    return RecordBehaviorEventsResp(
      results: ((m['results'] ?? []) as List<dynamic>)
          .map((i) => BehaviorEventResult.fromJson(i))
          .toList(),
      acceptedCount: m['acceptedCount'] ?? 0,
      rejectedCount: m['rejectedCount'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'results': results.map((i) => i.toJson()),
      'acceptedCount': acceptedCount,
      'rejectedCount': rejectedCount,
    };
  }
}

class RegisterReq {
  final String username;

  final String password;

  final String phone;

  final String verifyCode;
  RegisterReq({
    required this.username,
    required this.password,
    required this.phone,
    required this.verifyCode,
  });
  factory RegisterReq.fromJson(Map<String, dynamic> m) {
    return RegisterReq(
      username: m['username'] ?? "",
      password: m['password'] ?? "",
      phone: m['phone'] ?? "",
      verifyCode: m['verifyCode'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'phone': phone,
      'verifyCode': verifyCode,
    };
  }
}

class RegisterResp {
  final num userId;

  final String token;
  RegisterResp({required this.userId, required this.token});
  factory RegisterResp.fromJson(Map<String, dynamic> m) {
    return RegisterResp(userId: m['userId'] ?? 0, token: m['token'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'userId': userId, 'token': token};
  }
}

class SearchPostItem {
  final num id;

  final String title;

  final String contentHighlight;

  final num authorId;

  final String authorName;

  final String authorAvatar;

  final num likeCount;

  final num commentCount;

  final num createdAt;
  SearchPostItem({
    required this.id,
    required this.title,
    required this.contentHighlight,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
  });
  factory SearchPostItem.fromJson(Map<String, dynamic> m) {
    return SearchPostItem(
      id: m['id'] ?? 0,
      title: m['title'] ?? "",
      contentHighlight: m['contentHighlight'] ?? "",
      authorId: m['authorId'] ?? 0,
      authorName: m['authorName'] ?? "",
      authorAvatar: m['authorAvatar'] ?? "",
      likeCount: m['likeCount'] ?? 0,
      commentCount: m['commentCount'] ?? 0,
      createdAt: m['createdAt'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'contentHighlight': contentHighlight,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'createdAt': createdAt,
    };
  }
}

class SearchReq {
  final String keyword;

  final num page;

  final num pageSize;
  SearchReq({
    required this.keyword,
    required this.page,
    required this.pageSize,
  });
  factory SearchReq.fromJson(Map<String, dynamic> m) {
    return SearchReq(
      keyword: m['keyword'] ?? "",
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'keyword': keyword, 'page': page, 'pageSize': pageSize};
  }
}

class SearchResp {
  final List<SearchPostItem> posts;

  final List<SearchUserItem> users;

  final List<SearchTagItem> tags;

  final bool degraded;

  final List<String> unavailableTypes;
  SearchResp({
    required this.posts,
    required this.users,
    required this.tags,
    required this.degraded,
    required this.unavailableTypes,
  });
  factory SearchResp.fromJson(Map<String, dynamic> m) {
    return SearchResp(
      posts: ((m['posts'] ?? []) as List<dynamic>)
          .map((i) => SearchPostItem.fromJson(i))
          .toList(),
      users: ((m['users'] ?? []) as List<dynamic>)
          .map((i) => SearchUserItem.fromJson(i))
          .toList(),
      tags: ((m['tags'] ?? []) as List<dynamic>)
          .map((i) => SearchTagItem.fromJson(i))
          .toList(),
      degraded: m['degraded'] ?? false,
      unavailableTypes: m['unavailableTypes']?.cast<String>() ?? [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'posts': posts.map((i) => i.toJson()),
      'users': users.map((i) => i.toJson()),
      'tags': tags.map((i) => i.toJson()),
      'degraded': degraded,
      'unavailableTypes': unavailableTypes,
    };
  }
}

class SearchTagItem {
  final String name;

  final num postCount;
  SearchTagItem({required this.name, required this.postCount});
  factory SearchTagItem.fromJson(Map<String, dynamic> m) {
    return SearchTagItem(name: m['name'] ?? "", postCount: m['postCount'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'name': name, 'postCount': postCount};
  }
}

class SearchTagsReq {
  final String keyword;

  final num limit;
  SearchTagsReq({required this.keyword, required this.limit});
  factory SearchTagsReq.fromJson(Map<String, dynamic> m) {
    return SearchTagsReq(keyword: m['keyword'] ?? "", limit: m['limit'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'keyword': keyword, 'limit': limit};
  }
}

class SearchTagsResp {
  final List<SearchTagItem> tags;
  SearchTagsResp({required this.tags});
  factory SearchTagsResp.fromJson(Map<String, dynamic> m) {
    return SearchTagsResp(
      tags: ((m['tags'] ?? []) as List<dynamic>)
          .map((i) => SearchTagItem.fromJson(i))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() {
    return {'tags': tags.map((i) => i.toJson())};
  }
}

class SearchUserItem {
  final num id;

  final String username;

  final String nickname;

  final String avatarUrl;

  final String bio;

  final num followerCount;
  SearchUserItem({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatarUrl,
    required this.bio,
    required this.followerCount,
  });
  factory SearchUserItem.fromJson(Map<String, dynamic> m) {
    return SearchUserItem(
      id: m['id'] ?? 0,
      username: m['username'] ?? "",
      nickname: m['nickname'] ?? "",
      avatarUrl: m['avatarUrl'] ?? "",
      bio: m['bio'] ?? "",
      followerCount: m['followerCount'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'followerCount': followerCount,
    };
  }
}

class SearchUsersReq {
  final String keyword;

  final num page;

  final num pageSize;
  SearchUsersReq({
    required this.keyword,
    required this.page,
    required this.pageSize,
  });
  factory SearchUsersReq.fromJson(Map<String, dynamic> m) {
    return SearchUsersReq(
      keyword: m['keyword'] ?? "",
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'keyword': keyword, 'page': page, 'pageSize': pageSize};
  }
}

class SearchUsersResp {
  final List<SearchUserItem> users;

  final num total;
  SearchUsersResp({required this.users, required this.total});
  factory SearchUsersResp.fromJson(Map<String, dynamic> m) {
    return SearchUsersResp(
      users: ((m['users'] ?? []) as List<dynamic>)
          .map((i) => SearchUserItem.fromJson(i))
          .toList(),
      total: m['total'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'users': users.map((i) => i.toJson()), 'total': total};
  }
}

class SendMessageReq {
  final num receiverId;

  final String content;

  final num msgType;

  final String idempotencyKey;

  final num mediaId;
  SendMessageReq({
    required this.receiverId,
    required this.content,
    required this.msgType,
    required this.idempotencyKey,
    required this.mediaId,
  });
  factory SendMessageReq.fromJson(Map<String, dynamic> m) {
    return SendMessageReq(
      receiverId: m['receiverId'] ?? 0,
      content: m['content'] ?? "",
      msgType: m['msgType'] ?? 0,
      idempotencyKey: m['idempotencyKey'] ?? "",
      mediaId: m['mediaId'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'receiverId': receiverId,
      'content': content,
      'msgType': msgType,
      'idempotencyKey': idempotencyKey,
      'mediaId': mediaId,
    };
  }
}

class SendMessageResp {
  final num messageId;
  SendMessageResp({required this.messageId});
  factory SendMessageResp.fromJson(Map<String, dynamic> m) {
    return SendMessageResp(messageId: m['messageId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'messageId': messageId};
  }
}

class SendVerifyCodeReq {
  final String phone;

  // 1:注册 2:登录 3:重置密码
  final num type;
  SendVerifyCodeReq({required this.phone, required this.type});
  factory SendVerifyCodeReq.fromJson(Map<String, dynamic> m) {
    return SendVerifyCodeReq(phone: m['phone'] ?? "", type: m['type'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'phone': phone, 'type': type};
  }
}

class SendVerifyCodeResp {
  SendVerifyCodeResp();
  factory SendVerifyCodeResp.fromJson(Map<String, dynamic> m) {
    return SendVerifyCodeResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class SetPersonalizationPreferenceReq {
  final bool enabled;
  SetPersonalizationPreferenceReq({required this.enabled});
  factory SetPersonalizationPreferenceReq.fromJson(Map<String, dynamic> m) {
    return SetPersonalizationPreferenceReq(enabled: m['enabled'] ?? false);
  }
  Map<String, dynamic> toJson() {
    return {'enabled': enabled};
  }
}

class SetPersonalizationPreferenceResp {
  SetPersonalizationPreferenceResp();
  factory SetPersonalizationPreferenceResp.fromJson(Map<String, dynamic> m) {
    return SetPersonalizationPreferenceResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UnfavoriteReq {
  final num postId;
  UnfavoriteReq({required this.postId});
  factory UnfavoriteReq.fromJson(Map<String, dynamic> m) {
    return UnfavoriteReq(postId: m['postId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'postId': postId};
  }
}

class UnfavoriteResp {
  UnfavoriteResp();
  factory UnfavoriteResp.fromJson(Map<String, dynamic> m) {
    return UnfavoriteResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UnfollowReq {
  final num targetUserId;
  UnfollowReq({required this.targetUserId});
  factory UnfollowReq.fromJson(Map<String, dynamic> m) {
    return UnfollowReq(targetUserId: m['targetUserId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'targetUserId': targetUserId};
  }
}

class UnfollowResp {
  UnfollowResp();
  factory UnfollowResp.fromJson(Map<String, dynamic> m) {
    return UnfollowResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UnlikeReq {
  final num targetId;

  final num targetType;
  UnlikeReq({required this.targetId, required this.targetType});
  factory UnlikeReq.fromJson(Map<String, dynamic> m) {
    return UnlikeReq(
      targetId: m['targetId'] ?? 0,
      targetType: m['targetType'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'targetId': targetId, 'targetType': targetType};
  }
}

class UnlikeResp {
  UnlikeResp();
  factory UnlikeResp.fromJson(Map<String, dynamic> m) {
    return UnlikeResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UpdatePostResp {
  final num status;

  final num revision;
  UpdatePostResp({required this.status, required this.revision});
  factory UpdatePostResp.fromJson(Map<String, dynamic> m) {
    return UpdatePostResp(
      status: m['status'] ?? 0,
      revision: m['revision'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'status': status, 'revision': revision};
  }
}

class UpdatePostV2Req {
  final num postId;

  final String title;

  final String content;

  final List<String> images;

  final List<String> tags;

  final int? status;

  // 必填；缺失/0 → 参数错误
  final num expectedRevision;

  final List<int> mediaIds;
  UpdatePostV2Req({
    required this.postId,
    required this.title,
    required this.content,
    required this.images,
    required this.tags,
    required this.status,
    required this.expectedRevision,
    required this.mediaIds,
  });
  factory UpdatePostV2Req.fromJson(Map<String, dynamic> m) {
    return UpdatePostV2Req(
      postId: m['postId'] ?? 0,
      title: m['title'] ?? "",
      content: m['content'] ?? "",
      images: m['images']?.cast<String>() ?? [],
      tags: m['tags']?.cast<String>() ?? [],
      status: m['status'] == null ? null : (m['status'] is num) ? (m['status'] as num).toInt() : null,
      expectedRevision: m['expectedRevision'] ?? 0,
      mediaIds: m['mediaIds']?.cast<int>() ?? [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'title': title,
      'content': content,
      'images': images,
      'tags': tags,
      'status': status,
      'expectedRevision': expectedRevision,
      'mediaIds': mediaIds,
    };
  }
}

class UpdateProfileReq {
  final String nickname;

  final String avatarUrl;

  final String bio;
  UpdateProfileReq({
    required this.nickname,
    required this.avatarUrl,
    required this.bio,
  });
  factory UpdateProfileReq.fromJson(Map<String, dynamic> m) {
    return UpdateProfileReq(
      nickname: m['nickname'] ?? "",
      avatarUrl: m['avatarUrl'] ?? "",
      bio: m['bio'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {'nickname': nickname, 'avatarUrl': avatarUrl, 'bio': bio};
  }
}

class UpdateProfileResp {
  UpdateProfileResp();
  factory UpdateProfileResp.fromJson(Map<String, dynamic> m) {
    return UpdateProfileResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UploadImageReq {
  UploadImageReq();
  factory UploadImageReq.fromJson(Map<String, dynamic> m) {
    return UploadImageReq();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UploadImageResp {
  final num mediaId;

  final String url;

  final String thumbnailUrl;
  UploadImageResp({
    required this.mediaId,
    required this.url,
    required this.thumbnailUrl,
  });
  factory UploadImageResp.fromJson(Map<String, dynamic> m) {
    return UploadImageResp(
      mediaId: m['mediaId'] ?? 0,
      url: m['url'] ?? "",
      thumbnailUrl: m['thumbnailUrl'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {'mediaId': mediaId, 'url': url, 'thumbnailUrl': thumbnailUrl};
  }
}
