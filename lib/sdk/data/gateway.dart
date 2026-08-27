// --/home/dev/projects/little/little-white-box-content-community/.worktree/task-audit-fixes/app/gateway/gateway--

class AssistantAction {
  final String action;

  final String payloadJson;
  AssistantAction({required this.action, required this.payloadJson});
  factory AssistantAction.fromJson(Map<String, dynamic> m) {
    return AssistantAction(
      action: m['action'] ?? "",
      payloadJson: m['payloadJson'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {'action': action, 'payloadJson': payloadJson};
  }
}

class AssistantAttachment {
  final Object mediaId;

  final String url;
  AssistantAttachment({required this.mediaId, required this.url});
  factory AssistantAttachment.fromJson(Map<String, dynamic> m) {
    return AssistantAttachment(mediaId: m['mediaId'] ?? 0, url: m['url'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'mediaId': mediaId, 'url': url};
  }
}

class AssistantCard {
  final String cardType;

  final String payloadJson;
  AssistantCard({required this.cardType, required this.payloadJson});
  factory AssistantCard.fromJson(Map<String, dynamic> m) {
    return AssistantCard(
      cardType: m['cardType'] ?? "",
      payloadJson: m['payloadJson'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {'cardType': cardType, 'payloadJson': payloadJson};
  }
}

class AssistantChatEvent {
  final String type;

  final String text;

  final AssistantSourceReference? source;

  final bool degraded;

  final String errorCode;

  final String conversationId;

  final AssistantToolCallInfo? toolCall;

  final AssistantCard? card;

  final List<AssistantAction> actions;

  final AssistantWatchHitEvent? watchHit;
  AssistantChatEvent({
    required this.type,
    required this.text,
    required this.source,
    required this.degraded,
    required this.errorCode,
    required this.conversationId,
    required this.toolCall,
    required this.card,
    required this.actions,
    required this.watchHit,
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
      toolCall: m['toolCall'] == null
          ? null
          : AssistantToolCallInfo?.fromJson(m['toolCall']),
      card: m['card'] == null ? null : AssistantCard?.fromJson(m['card']),
      actions: ((m['actions'] ?? []) as List<dynamic>)
          .map((i) => AssistantAction.fromJson(i))
          .toList(),
      watchHit: m['watchHit'] == null
          ? null
          : AssistantWatchHitEvent?.fromJson(m['watchHit']),
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
      'toolCall': toolCall?.toJson(),
      'card': card?.toJson(),
      'actions': actions.map((i) => i.toJson()),
      'watchHit': watchHit?.toJson(),
    };
  }
}

class AssistantChatReq {
  final String conversationId;

  final String message;

  final String requestId;

  final String mode;

  final List<AssistantAttachment> attachments;

  final Object contextPostId;
  AssistantChatReq({
    required this.conversationId,
    required this.message,
    required this.requestId,
    required this.mode,
    required this.attachments,
    required this.contextPostId,
  });
  factory AssistantChatReq.fromJson(Map<String, dynamic> m) {
    return AssistantChatReq(
      conversationId: m['conversationId'] ?? "",
      message: m['message'] ?? "",
      requestId: m['requestId'] ?? "",
      mode: m['mode'] ?? "",
      attachments: ((m['attachments'] ?? []) as List<dynamic>)
          .map((i) => AssistantAttachment.fromJson(i))
          .toList(),
      contextPostId: m['contextPostId'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'message': message,
      'requestId': requestId,
      'mode': mode,
      'attachments': attachments.map((i) => i.toJson()),
      'contextPostId': contextPostId,
    };
  }
}

class AssistantMemoryItem {
  final Object id;

  final String layer;

  final String dimension;

  final String value;

  final num score;

  final String source;

  final num confidence;

  final bool confirmed;

  final bool suppressed;

  final num updatedAt;
  AssistantMemoryItem({
    required this.id,
    required this.layer,
    required this.dimension,
    required this.value,
    required this.score,
    required this.source,
    required this.confidence,
    required this.confirmed,
    required this.suppressed,
    required this.updatedAt,
  });
  factory AssistantMemoryItem.fromJson(Map<String, dynamic> m) {
    return AssistantMemoryItem(
      id: m['id'] ?? 0,
      layer: m['layer'] ?? "",
      dimension: m['dimension'] ?? "",
      value: m['value'] ?? "",
      score: m['score'] ?? 0.0,
      source: m['source'] ?? "",
      confidence: m['confidence'] ?? 0.0,
      confirmed: m['confirmed'] ?? false,
      suppressed: m['suppressed'] ?? false,
      updatedAt: m['updatedAt'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'layer': layer,
      'dimension': dimension,
      'value': value,
      'score': score,
      'source': source,
      'confidence': confidence,
      'confirmed': confirmed,
      'suppressed': suppressed,
      'updatedAt': updatedAt,
    };
  }
}

class AssistantRecommendFeedbackReq {
  final String requestId;

  final Object postId;

  final String reason;
  AssistantRecommendFeedbackReq({
    required this.requestId,
    required this.postId,
    required this.reason,
  });
  factory AssistantRecommendFeedbackReq.fromJson(Map<String, dynamic> m) {
    return AssistantRecommendFeedbackReq(
      requestId: m['requestId'] ?? "",
      postId: m['postId'] ?? 0,
      reason: m['reason'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {'requestId': requestId, 'postId': postId, 'reason': reason};
  }
}

class AssistantRecommendFeedbackResp {
  AssistantRecommendFeedbackResp();
  factory AssistantRecommendFeedbackResp.fromJson(Map<String, dynamic> m) {
    return AssistantRecommendFeedbackResp();
  }
  Map<String, dynamic> toJson() {
    return {};
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

class AssistantToolCallInfo {
  final String callId;

  final String tool;

  final String summary;

  final String payloadJson;
  AssistantToolCallInfo({
    required this.callId,
    required this.tool,
    required this.summary,
    required this.payloadJson,
  });
  factory AssistantToolCallInfo.fromJson(Map<String, dynamic> m) {
    return AssistantToolCallInfo(
      callId: m['callId'] ?? "",
      tool: m['tool'] ?? "",
      summary: m['summary'] ?? "",
      payloadJson: m['payloadJson'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'tool': tool,
      'summary': summary,
      'payloadJson': payloadJson,
    };
  }
}

class AssistantToolConfirmReq {
  final String requestId;

  final String callId;

  final bool approved;
  AssistantToolConfirmReq({
    required this.requestId,
    required this.callId,
    required this.approved,
  });
  factory AssistantToolConfirmReq.fromJson(Map<String, dynamic> m) {
    return AssistantToolConfirmReq(
      requestId: m['requestId'] ?? "",
      callId: m['callId'] ?? "",
      approved: m['approved'] ?? false,
    );
  }
  Map<String, dynamic> toJson() {
    return {'requestId': requestId, 'callId': callId, 'approved': approved};
  }
}

class AssistantToolConfirmResp {
  AssistantToolConfirmResp();
  factory AssistantToolConfirmResp.fromJson(Map<String, dynamic> m) {
    return AssistantToolConfirmResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class AssistantWatchHit {
  final Object id;

  final Object taskId;

  final Object postId;

  final String title;

  final String summary;

  final num createdAt;

  final bool read;
  AssistantWatchHit({
    required this.id,
    required this.taskId,
    required this.postId,
    required this.title,
    required this.summary,
    required this.createdAt,
    required this.read,
  });
  factory AssistantWatchHit.fromJson(Map<String, dynamic> m) {
    return AssistantWatchHit(
      id: m['id'] ?? 0,
      taskId: m['taskId'] ?? 0,
      postId: m['postId'] ?? 0,
      title: m['title'] ?? "",
      summary: m['summary'] ?? "",
      createdAt: m['createdAt'] ?? 0,
      read: m['read'] ?? false,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'postId': postId,
      'title': title,
      'summary': summary,
      'createdAt': createdAt,
      'read': read,
    };
  }
}

class AssistantWatchHitEvent {
  final Object hitId;

  final Object taskId;

  final Object postId;

  final String title;

  final String summary;
  AssistantWatchHitEvent({
    required this.hitId,
    required this.taskId,
    required this.postId,
    required this.title,
    required this.summary,
  });
  factory AssistantWatchHitEvent.fromJson(Map<String, dynamic> m) {
    return AssistantWatchHitEvent(
      hitId: m['hitId'] ?? 0,
      taskId: m['taskId'] ?? 0,
      postId: m['postId'] ?? 0,
      title: m['title'] ?? "",
      summary: m['summary'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'hitId': hitId,
      'taskId': taskId,
      'postId': postId,
      'title': title,
      'summary': summary,
    };
  }
}

class AssistantWatchTask {
  final Object id;

  final String conditionType;

  final String targetType;

  final Object targetId;

  final String targetText;

  final bool enabled;

  final num createdAt;
  AssistantWatchTask({
    required this.id,
    required this.conditionType,
    required this.targetType,
    required this.targetId,
    required this.targetText,
    required this.enabled,
    required this.createdAt,
  });
  factory AssistantWatchTask.fromJson(Map<String, dynamic> m) {
    return AssistantWatchTask(
      id: m['id'] ?? 0,
      conditionType: m['conditionType'] ?? "",
      targetType: m['targetType'] ?? "",
      targetId: m['targetId'] ?? 0,
      targetText: m['targetText'] ?? "",
      enabled: m['enabled'] ?? false,
      createdAt: m['createdAt'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conditionType': conditionType,
      'targetType': targetType,
      'targetId': targetId,
      'targetText': targetText,
      'enabled': enabled,
      'createdAt': createdAt,
    };
  }
}

class BehaviorEvent {
  final String clientEventId;

  final num occurredAt;

  final String action;

  final Object targetId;

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
      position: m['position'] == null
          ? null
          : (m['position'] is num)
          ? (m['position'] as num).toInt()
          : null,
      durationMs: m['durationMs'] == null
          ? null
          : (m['durationMs'] is num)
          ? (m['durationMs'] as num).toInt()
          : null,
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

  final Object eventId;

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
  final Object id;

  final Object userId;

  final String userName;

  final String userAvatar;

  final Object parentId;

  final Object replyUserId;

  final String content;

  final num likeCount;

  final num createdAt;

  // 楼中楼回复总数，仅顶级评论有值
  final num replyCount;

  // 内嵌回复预览（前 N 条），仅顶级评论有值
  final List<CommentItem> replies;
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
    required this.replyCount,
    required this.replies,
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
      replyCount: m['replyCount'] ?? 0,
      replies: ((m['replies'] ?? []) as List<dynamic>)
          .map((i) => CommentItem.fromJson(i))
          .toList(),
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
      'replyCount': replyCount,
      'replies': replies.map((i) => i.toJson()),
    };
  }
}

class ConversationItem {
  final Object id;

  final Object targetUserId;

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

class CreateAssistantWatchReq {
  final String conditionType;

  final String targetType;

  final Object targetId;

  final String targetText;
  CreateAssistantWatchReq({
    required this.conditionType,
    required this.targetType,
    required this.targetId,
    required this.targetText,
  });
  factory CreateAssistantWatchReq.fromJson(Map<String, dynamic> m) {
    return CreateAssistantWatchReq(
      conditionType: m['conditionType'] ?? "",
      targetType: m['targetType'] ?? "",
      targetId: m['targetId'] ?? 0,
      targetText: m['targetText'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'conditionType': conditionType,
      'targetType': targetType,
      'targetId': targetId,
      'targetText': targetText,
    };
  }
}

class CreateAssistantWatchResp {
  final AssistantWatchTask task;
  CreateAssistantWatchResp({required this.task});
  factory CreateAssistantWatchResp.fromJson(Map<String, dynamic> m) {
    return CreateAssistantWatchResp(
      task: AssistantWatchTask.fromJson(m['task']),
    );
  }
  Map<String, dynamic> toJson() {
    return {'task': task.toJson()};
  }
}

class CreateCommentReq {
  final Object postId;

  final Object parentId;

  final Object replyUserId;

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
  final Object commentId;
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

  final List<Object> mediaIds;
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
      mediaIds: m['mediaIds'] is List
          ? List<Object>.from(m['mediaIds'] as List)
          : <Object>[],
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
  final Object postId;

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

class DeleteAssistantMemoryReq {
  final Object id;
  DeleteAssistantMemoryReq({required this.id});
  factory DeleteAssistantMemoryReq.fromJson(Map<String, dynamic> m) {
    return DeleteAssistantMemoryReq(id: m['id'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'id': id};
  }
}

class DeleteAssistantMemoryResp {
  DeleteAssistantMemoryResp();
  factory DeleteAssistantMemoryResp.fromJson(Map<String, dynamic> m) {
    return DeleteAssistantMemoryResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class DeleteAssistantWatchReq {
  final Object id;
  DeleteAssistantWatchReq({required this.id});
  factory DeleteAssistantWatchReq.fromJson(Map<String, dynamic> m) {
    return DeleteAssistantWatchReq(id: m['id'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'id': id};
  }
}

class DeleteAssistantWatchResp {
  DeleteAssistantWatchResp();
  factory DeleteAssistantWatchResp.fromJson(Map<String, dynamic> m) {
    return DeleteAssistantWatchResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class DeleteCommentReq {
  final Object commentId;
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
  final Object postId;

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
  final Object postId;
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
  final Object postId;

  final Object authorId;

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
  final Object targetUserId;
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

class GetAgentConsentResp {
  final bool granted;

  final num grantedAt;

  final num revokedAt;

  final num consentVersion;

  final num currentVersion;
  GetAgentConsentResp({
    required this.granted,
    required this.grantedAt,
    required this.revokedAt,
    required this.consentVersion,
    required this.currentVersion,
  });
  factory GetAgentConsentResp.fromJson(Map<String, dynamic> m) {
    return GetAgentConsentResp(
      granted: m['granted'] ?? false,
      grantedAt: m['grantedAt'] ?? 0,
      revokedAt: m['revokedAt'] ?? 0,
      consentVersion: m['consentVersion'] ?? 0,
      currentVersion: m['currentVersion'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'granted': granted,
      'grantedAt': grantedAt,
      'revokedAt': revokedAt,
      'consentVersion': consentVersion,
      'currentVersion': currentVersion,
    };
  }
}

class GetCommentListReq {
  final Object postId;

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

class GetCommentRepliesReq {
  final Object commentId;

  final num page;

  final num pageSize;
  GetCommentRepliesReq({
    required this.commentId,
    required this.page,
    required this.pageSize,
  });
  factory GetCommentRepliesReq.fromJson(Map<String, dynamic> m) {
    return GetCommentRepliesReq(
      commentId: m['commentId'] ?? 0,
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'commentId': commentId, 'page': page, 'pageSize': pageSize};
  }
}

class GetCommentRepliesResp {
  final List<CommentItem> list;

  final num total;

  final num page;

  final num pageSize;
  GetCommentRepliesResp({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  factory GetCommentRepliesResp.fromJson(Map<String, dynamic> m) {
    return GetCommentRepliesResp(
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

  final Object cursorPostId;

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

  final Object nextCursorPostId;
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
  final Object conversationId;

  final Object lastId;

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
  final num pageSize;

  // 1:最新 2:热门 3:推荐
  final num sortBy;

  // 不透明游标；首页传空
  final String cursor;
  GetPostListReq({
    required this.pageSize,
    required this.sortBy,
    required this.cursor,
  });
  factory GetPostListReq.fromJson(Map<String, dynamic> m) {
    return GetPostListReq(
      pageSize: m['pageSize'] ?? 0,
      sortBy: m['sortBy'] ?? 0,
      cursor: m['cursor'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {'pageSize': pageSize, 'sortBy': sortBy, 'cursor': cursor};
  }
}

class GetPostListResp {
  final List<PostItem> list;

  // 为空表示没有更多
  final String nextCursor;
  GetPostListResp({required this.list, required this.nextCursor});
  factory GetPostListResp.fromJson(Map<String, dynamic> m) {
    return GetPostListResp(
      list: ((m['list'] ?? []) as List<dynamic>)
          .map((i) => PostItem.fromJson(i))
          .toList(),
      nextCursor: m['nextCursor'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {'list': list.map((i) => i.toJson()), 'nextCursor': nextCursor};
  }
}

class GetPostReq {
  final Object postId;
  GetPostReq({required this.postId});
  factory GetPostReq.fromJson(Map<String, dynamic> m) {
    return GetPostReq(postId: m['postId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'postId': postId};
  }
}

class GetPostResp {
  final Object id;

  final Object authorId;

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
  final Object userId;

  final num page;

  final num pageSize;

  // 统一游标形状；内部换算页码
  final String cursor;
  GetUserFavoritesReq({
    required this.userId,
    required this.page,
    required this.pageSize,
    required this.cursor,
  });
  factory GetUserFavoritesReq.fromJson(Map<String, dynamic> m) {
    return GetUserFavoritesReq(
      userId: m['userId'] ?? 0,
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
      cursor: m['cursor'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'page': page,
      'pageSize': pageSize,
      'cursor': cursor,
    };
  }
}

class GetUserPostsReq {
  final Object userId;

  final num pageSize;

  final num sortBy;

  // 不透明游标；首页传空
  final String cursor;
  GetUserPostsReq({
    required this.userId,
    required this.pageSize,
    required this.sortBy,
    required this.cursor,
  });
  factory GetUserPostsReq.fromJson(Map<String, dynamic> m) {
    return GetUserPostsReq(
      userId: m['userId'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
      sortBy: m['sortBy'] ?? 0,
      cursor: m['cursor'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'pageSize': pageSize,
      'sortBy': sortBy,
      'cursor': cursor,
    };
  }
}

class GetUserReq {
  final Object userId;
  GetUserReq({required this.userId});
  factory GetUserReq.fromJson(Map<String, dynamic> m) {
    return GetUserReq(userId: m['userId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'userId': userId};
  }
}

class GetUserResp {
  final Object id;

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
  final Object targetId;

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

class ListAssistantMemoryReq {
  final String layer;
  ListAssistantMemoryReq({required this.layer});
  factory ListAssistantMemoryReq.fromJson(Map<String, dynamic> m) {
    return ListAssistantMemoryReq(layer: m['layer'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'layer': layer};
  }
}

class ListAssistantMemoryResp {
  final List<AssistantMemoryItem> items;
  ListAssistantMemoryResp({required this.items});
  factory ListAssistantMemoryResp.fromJson(Map<String, dynamic> m) {
    return ListAssistantMemoryResp(
      items: ((m['items'] ?? []) as List<dynamic>)
          .map((i) => AssistantMemoryItem.fromJson(i))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() {
    return {'items': items.map((i) => i.toJson())};
  }
}

class ListAssistantWatchHitsReq {
  final bool unreadOnly;
  ListAssistantWatchHitsReq({required this.unreadOnly});
  factory ListAssistantWatchHitsReq.fromJson(Map<String, dynamic> m) {
    return ListAssistantWatchHitsReq(unreadOnly: m['unreadOnly'] ?? false);
  }
  Map<String, dynamic> toJson() {
    return {'unreadOnly': unreadOnly};
  }
}

class ListAssistantWatchHitsResp {
  final List<AssistantWatchHit> hits;
  ListAssistantWatchHitsResp({required this.hits});
  factory ListAssistantWatchHitsResp.fromJson(Map<String, dynamic> m) {
    return ListAssistantWatchHitsResp(
      hits: ((m['hits'] ?? []) as List<dynamic>)
          .map((i) => AssistantWatchHit.fromJson(i))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() {
    return {'hits': hits.map((i) => i.toJson())};
  }
}

class ListAssistantWatchReq {
  ListAssistantWatchReq();
  factory ListAssistantWatchReq.fromJson(Map<String, dynamic> m) {
    return ListAssistantWatchReq();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class ListAssistantWatchResp {
  final List<AssistantWatchTask> tasks;
  ListAssistantWatchResp({required this.tasks});
  factory ListAssistantWatchResp.fromJson(Map<String, dynamic> m) {
    return ListAssistantWatchResp(
      tasks: ((m['tasks'] ?? []) as List<dynamic>)
          .map((i) => AssistantWatchTask.fromJson(i))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() {
    return {'tasks': tasks.map((i) => i.toJson())};
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
  final Object userId;

  final String token;

  final String refreshToken;
  LoginResp({
    required this.userId,
    required this.token,
    required this.refreshToken,
  });
  factory LoginResp.fromJson(Map<String, dynamic> m) {
    return LoginResp(
      userId: m['userId'] ?? 0,
      token: m['token'] ?? "",
      refreshToken: m['refreshToken'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {'userId': userId, 'token': token, 'refreshToken': refreshToken};
  }
}

class MarkAssistantWatchHitsReadReq {
  final List<Object> hitIds;
  MarkAssistantWatchHitsReadReq({required this.hitIds});
  factory MarkAssistantWatchHitsReadReq.fromJson(Map<String, dynamic> m) {
    return MarkAssistantWatchHitsReadReq(
      hitIds: m['hitIds'] is List
          ? List<Object>.from(m['hitIds'] as List)
          : <Object>[],
    );
  }
  Map<String, dynamic> toJson() {
    return {'hitIds': hitIds};
  }
}

class MarkAssistantWatchHitsReadResp {
  MarkAssistantWatchHitsReadResp();
  factory MarkAssistantWatchHitsReadResp.fromJson(Map<String, dynamic> m) {
    return MarkAssistantWatchHitsReadResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class MarkConversationReadReq {
  final Object conversationId;
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
  final Object id;

  final Object conversationId;

  final Object senderId;

  final Object receiverId;

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
  final Object id;

  final Object authorId;

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
  final Object postId;

  final Object authorId;

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

class RefreshTokenReq {
  final String refreshToken;
  RefreshTokenReq({required this.refreshToken});
  factory RefreshTokenReq.fromJson(Map<String, dynamic> m) {
    return RefreshTokenReq(refreshToken: m['refreshToken'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'refreshToken': refreshToken};
  }
}

class RefreshTokenResp {
  final String token;

  final String refreshToken;
  RefreshTokenResp({required this.token, required this.refreshToken});
  factory RefreshTokenResp.fromJson(Map<String, dynamic> m) {
    return RefreshTokenResp(
      token: m['token'] ?? "",
      refreshToken: m['refreshToken'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {'token': token, 'refreshToken': refreshToken};
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
  final Object userId;

  final String token;

  final String refreshToken;
  RegisterResp({
    required this.userId,
    required this.token,
    required this.refreshToken,
  });
  factory RegisterResp.fromJson(Map<String, dynamic> m) {
    return RegisterResp(
      userId: m['userId'] ?? 0,
      token: m['token'] ?? "",
      refreshToken: m['refreshToken'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {'userId': userId, 'token': token, 'refreshToken': refreshToken};
  }
}

class SearchPostItem {
  final Object id;

  final String title;

  final String contentHighlight;

  final Object authorId;

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
  final Object id;

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
  final Object receiverId;

  final String content;

  final num msgType;

  final String idempotencyKey;

  final Object mediaId;
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
  final Object messageId;
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

class SetAgentConsentReq {
  final bool granted;
  SetAgentConsentReq({required this.granted});
  factory SetAgentConsentReq.fromJson(Map<String, dynamic> m) {
    return SetAgentConsentReq(granted: m['granted'] ?? false);
  }
  Map<String, dynamic> toJson() {
    return {'granted': granted};
  }
}

class SetAgentConsentResp {
  SetAgentConsentResp();
  factory SetAgentConsentResp.fromJson(Map<String, dynamic> m) {
    return SetAgentConsentResp();
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
  final Object postId;
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
  final Object targetUserId;
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
  final Object targetId;

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

class UpdateAssistantMemoryReq {
  final Object id;

  final String? value;

  final double? score;

  final bool? suppressed;
  UpdateAssistantMemoryReq({
    required this.id,
    required this.value,
    required this.score,
    required this.suppressed,
  });
  factory UpdateAssistantMemoryReq.fromJson(Map<String, dynamic> m) {
    return UpdateAssistantMemoryReq(
      id: m['id'] ?? 0,
      value: m['value'] == null ? null : m['value']?.toString(),
      score: m['score'] == null
          ? null
          : (m['score'] is num)
          ? (m['score'] as num).toDouble()
          : null,
      suppressed: m['suppressed'] == null
          ? null
          : (m['suppressed'] is bool)
          ? m['suppressed'] as bool
          : null,
    );
  }
  Map<String, dynamic> toJson() {
    return {'id': id, 'value': value, 'score': score, 'suppressed': suppressed};
  }
}

class UpdateAssistantMemoryResp {
  UpdateAssistantMemoryResp();
  factory UpdateAssistantMemoryResp.fromJson(Map<String, dynamic> m) {
    return UpdateAssistantMemoryResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UpdateAssistantWatchReq {
  final Object id;

  final bool enabled;
  UpdateAssistantWatchReq({required this.id, required this.enabled});
  factory UpdateAssistantWatchReq.fromJson(Map<String, dynamic> m) {
    return UpdateAssistantWatchReq(
      id: m['id'] ?? 0,
      enabled: m['enabled'] ?? false,
    );
  }
  Map<String, dynamic> toJson() {
    return {'id': id, 'enabled': enabled};
  }
}

class UpdateAssistantWatchResp {
  UpdateAssistantWatchResp();
  factory UpdateAssistantWatchResp.fromJson(Map<String, dynamic> m) {
    return UpdateAssistantWatchResp();
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
  final Object postId;

  final String title;

  final String content;

  final List<String> images;

  final List<String> tags;

  final int? status;

  // 必填；缺失/0 → 参数错误
  final num expectedRevision;

  final List<Object> mediaIds;
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
      status: m['status'] == null
          ? null
          : (m['status'] is num)
          ? (m['status'] as num).toInt()
          : null,
      expectedRevision: m['expectedRevision'] ?? 0,
      mediaIds: m['mediaIds'] is List
          ? List<Object>.from(m['mediaIds'] as List)
          : <Object>[],
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
  final Object mediaId;

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
