/// 行为目标类型；广告曝光与点击使用独立的 `ad`（FX-104）。
const behaviorTargetPost = 'post';
const behaviorTargetAd = 'ad';

/// 一条客户端行为事件，字段与网关行为上报接口一致；[occurredAt] 为毫秒时间戳，
/// 推荐解释字段（召回来源、模型版本、实验 ID）取自推荐响应，原样回传给服务端。
class ClientBehaviorEvent {
  final String clientEventId;
  final int occurredAt;
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

  const ClientBehaviorEvent({
    required this.clientEventId,
    required this.occurredAt,
    required this.action,
    required this.targetId,
    required this.targetType,
    required this.scene,
    required this.requestId,
    required this.recallSource,
    required this.modelVersion,
    required this.experimentId,
    this.position,
    this.durationMs,
  });

  factory ClientBehaviorEvent.fromJson(Map<String, dynamic> json) {
    return ClientBehaviorEvent(
      clientEventId: json['clientEventId'] as String? ?? '',
      occurredAt: (json['occurredAt'] as num?)?.toInt() ?? 0,
      action: json['action'] as String? ?? '',
      targetId: json['targetId'] ?? 0,
      targetType: json['targetType'] as String? ?? '',
      scene: json['scene'] as String? ?? '',
      requestId: json['requestId'] as String? ?? '',
      position: (json['position'] as num?)?.toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      recallSource: json['recallSource'] as String? ?? '',
      modelVersion: json['modelVersion'] as String? ?? '',
      experimentId: json['experimentId'] as String? ?? '',
    );
  }

  /// 请求体与本地持久化共用的 JSON；空的可选字段不输出。
  Map<String, dynamic> toJson() {
    return {
      'clientEventId': clientEventId,
      'occurredAt': occurredAt,
      'action': action,
      'targetId': targetId,
      'targetType': targetType,
      if (scene.isNotEmpty) 'scene': scene,
      if (requestId.isNotEmpty) 'requestId': requestId,
      if (position != null) 'position': position,
      if (durationMs != null) 'durationMs': durationMs,
      if (recallSource.isNotEmpty) 'recallSource': recallSource,
      if (modelVersion.isNotEmpty) 'modelVersion': modelVersion,
      if (experimentId.isNotEmpty) 'experimentId': experimentId,
    };
  }
}

/// 队列中的事件及其归属与客户端身份；发送时只把同一归属、同一匿名/会话 ID 的事件合批。
class QueuedBehaviorEvent {
  final String? ownerIdentity;
  final String anonymousId;
  final String sessionId;
  final ClientBehaviorEvent event;

  const QueuedBehaviorEvent({
    this.ownerIdentity,
    required this.anonymousId,
    required this.sessionId,
    required this.event,
  });

  factory QueuedBehaviorEvent.fromJson(Map<String, dynamic> json) {
    return QueuedBehaviorEvent(
      ownerIdentity: json['ownerIdentity'] as String?,
      anonymousId: json['anonymousId'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      event: ClientBehaviorEvent.fromJson(
        Map<String, dynamic>.from(json['event'] as Map? ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (ownerIdentity != null) 'ownerIdentity': ownerIdentity,
      'anonymousId': anonymousId,
      'sessionId': sessionId,
      'event': event.toJson(),
    };
  }
}

/// 一次发送的事件批次，所有事件共享同一归属与客户端身份。
class BehaviorBatch {
  final String? ownerIdentity;
  final String anonymousId;
  final String sessionId;
  final List<ClientBehaviorEvent> events;

  const BehaviorBatch({
    this.ownerIdentity,
    required this.anonymousId,
    required this.sessionId,
    required this.events,
  });
}

/// 一次发送的逐条结果：已受理与永久拒绝的事件都可出队，其余留待重试。
class BehaviorSendResult {
  final Set<String> acceptedEventIds;
  final Set<String> permanentlyRejectedEventIds;

  const BehaviorSendResult(
    this.acceptedEventIds, [
    this.permanentlyRejectedEventIds = const {},
  ]);

  /// 可从队列移除的事件 ID。
  Set<String> get terminalEventIds => {
    ...acceptedEventIds,
    ...permanentlyRejectedEventIds,
  };
}
