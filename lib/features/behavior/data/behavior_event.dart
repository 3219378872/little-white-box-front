class ClientBehaviorEvent {
  final String clientEventId;
  final int occurredAt;
  final String action;
  final int targetId;
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
      targetId: (json['targetId'] as num?)?.toInt() ?? 0,
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

class QueuedBehaviorEvent {
  final String anonymousId;
  final String sessionId;
  final ClientBehaviorEvent event;

  const QueuedBehaviorEvent({
    required this.anonymousId,
    required this.sessionId,
    required this.event,
  });

  factory QueuedBehaviorEvent.fromJson(Map<String, dynamic> json) {
    return QueuedBehaviorEvent(
      anonymousId: json['anonymousId'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      event: ClientBehaviorEvent.fromJson(
        Map<String, dynamic>.from(json['event'] as Map? ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'anonymousId': anonymousId,
      'sessionId': sessionId,
      'event': event.toJson(),
    };
  }
}

class BehaviorBatch {
  final String anonymousId;
  final String sessionId;
  final List<ClientBehaviorEvent> events;

  const BehaviorBatch({
    required this.anonymousId,
    required this.sessionId,
    required this.events,
  });
}

class BehaviorSendResult {
  final Set<String> acceptedEventIds;
  final Set<String> permanentlyRejectedEventIds;

  const BehaviorSendResult(
    this.acceptedEventIds, [
    this.permanentlyRejectedEventIds = const {},
  ]);

  Set<String> get terminalEventIds => {
    ...acceptedEventIds,
    ...permanentlyRejectedEventIds,
  };
}
