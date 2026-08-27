import '../../../core/api/json_int64.dart';

enum AssistantEventType {
  token,
  source,
  toolCall,
  confirmRequired,
  card,
  actions,
  watchHit,
  done,
  error,
  unknown,
}

/// Assistant 模式（AGNT-001）：enhanced_search 为缺省，agent 需要授权。
enum AssistantMode {
  enhancedSearch('enhanced_search'),
  agent('agent');

  const AssistantMode(this.wireValue);

  final String wireValue;

  static AssistantMode fromWire(String? value) =>
      value == AssistantMode.agent.wireValue
      ? AssistantMode.agent
      : AssistantMode.enhancedSearch;
}

const memoryListLayers = {'profile', 'interest', 'task'};

const watchConditionTargetTypes = {
  'author_new_post': 'author',
  'tag_new_post': 'tag',
  'keyword_new_post': 'keyword',
  'post_revised': 'post',
};

class AssistantToolCall {
  final String callId;
  final String tool;
  final String summary;
  final String payloadJson;

  const AssistantToolCall({
    required this.callId,
    required this.tool,
    this.summary = '',
    this.payloadJson = '',
  });

  factory AssistantToolCall.fromJson(Map<String, dynamic> json) {
    final callId = _string(json['callId']).trim();
    final tool = _string(json['tool']).trim();
    if (callId.isEmpty || tool.isEmpty) {
      throw const FormatException('invalid assistant tool call');
    }
    return AssistantToolCall(
      callId: callId,
      tool: tool,
      summary: _string(json['summary']),
      payloadJson: _string(json['payloadJson']),
    );
  }
}

class AssistantSourceReference {
  final String sourceType;
  final String sourceId;
  final String title;
  final int revision;

  const AssistantSourceReference({
    required this.sourceType,
    required this.sourceId,
    required this.title,
    this.revision = 0,
  });

  bool get isVerifiedPost => sourceType == 'post' && sourceId.isNotEmpty;

  factory AssistantSourceReference.fromJson(Map<String, dynamic> json) {
    final sourceType = _string(json['sourceType']).trim();
    final sourceId = _string(json['sourceId']).trim();
    if (sourceType.isEmpty || sourceId.isEmpty) {
      throw const FormatException('invalid assistant source');
    }
    return AssistantSourceReference(
      sourceType: sourceType,
      sourceId: sourceId,
      title: _string(json['title']),
      revision: _integer(json['revision']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AssistantSourceReference &&
        other.sourceType == sourceType &&
        other.sourceId == sourceId;
  }

  @override
  int get hashCode => Object.hash(sourceType, sourceId);
}

/// SSE card：只采用 payload 里服务端给出的已验证标识（FX-084）。
class AssistantStructuredCard {
  final String cardType;
  final String payloadJson;
  final Object? postId;
  final String title;
  final String summary;

  const AssistantStructuredCard({
    required this.cardType,
    this.payloadJson = '',
    this.postId,
    this.title = '',
    this.summary = '',
  });

  bool get hasVerifiedPost => jsonInt64IsPositive(postId);

  bool get isRecommend =>
      cardType == 'recommend' || cardType == 'post' || cardType == 'posts';

  factory AssistantStructuredCard.fromJson(Map<String, dynamic> json) {
    final cardType = _string(json['cardType']).trim();
    if (cardType.isEmpty) {
      throw const FormatException('invalid assistant card');
    }
    final payloadJson = _string(json['payloadJson']);
    final payload = decodePayloadJson(payloadJson);
    return AssistantStructuredCard(
      cardType: cardType,
      payloadJson: payloadJson,
      postId: verifiedPayloadId(payload, 'postId'),
      title: _string(payload?['title']).trim(),
      summary: _string(payload?['summary']).trim(),
    );
  }
}

class AssistantStructuredAction {
  final String action;
  final String payloadJson;
  final Object? postId;
  final Object? authorId;
  final String targetText;
  final String conditionType;
  final String targetType;
  final Object? targetId;

  const AssistantStructuredAction({
    required this.action,
    this.payloadJson = '',
    this.postId,
    this.authorId,
    this.targetText = '',
    this.conditionType = '',
    this.targetType = '',
    this.targetId,
  });

  factory AssistantStructuredAction.fromJson(Map<String, dynamic> json) {
    final action = _string(json['action']).trim();
    if (action.isEmpty) {
      throw const FormatException('invalid assistant action');
    }
    final payloadJson = _string(json['payloadJson']);
    final payload = decodePayloadJson(payloadJson);
    final conditionType = _string(payload?['conditionType']).trim();
    final targetType = _string(payload?['targetType']).trim();
    return AssistantStructuredAction(
      action: action,
      payloadJson: payloadJson,
      postId: verifiedPayloadId(payload, 'postId'),
      authorId: verifiedPayloadId(payload, 'authorId'),
      targetText: _string(payload?['targetText']).trim().isNotEmpty
          ? _string(payload?['targetText']).trim()
          : _string(payload?['tag']).trim(),
      conditionType: conditionType,
      targetType: targetType,
      targetId: verifiedPayloadId(payload, 'targetId'),
    );
  }
}

class AssistantWatchHitNotice {
  final Object hitId;
  final Object taskId;
  final Object postId;
  final String title;
  final String summary;

  const AssistantWatchHitNotice({
    required this.hitId,
    required this.taskId,
    required this.postId,
    this.title = '',
    this.summary = '',
  });

  bool get hasVerifiedPost => jsonInt64IsPositive(postId);

  factory AssistantWatchHitNotice.fromJson(Map<String, dynamic> json) {
    final hitId = json['hitId'] ?? 0;
    final taskId = json['taskId'] ?? 0;
    final postId = json['postId'] ?? 0;
    if (!jsonInt64IsPositive(hitId) || !jsonInt64IsPositive(postId)) {
      throw const FormatException('invalid assistant watch hit');
    }
    return AssistantWatchHitNotice(
      hitId: jsonInt64Id(hitId),
      taskId: jsonInt64Id(taskId),
      postId: jsonInt64Id(postId),
      title: _string(json['title']),
      summary: _string(json['summary']),
    );
  }
}

class AssistantChatEvent {
  final AssistantEventType type;
  final String text;
  final AssistantSourceReference? source;
  final AssistantToolCall? toolCall;
  final AssistantStructuredCard? card;
  final List<AssistantStructuredAction> actions;
  final AssistantWatchHitNotice? watchHit;
  final bool degraded;
  final String errorCode;
  final String conversationId;

  const AssistantChatEvent({
    required this.type,
    this.text = '',
    this.source,
    this.toolCall,
    this.card,
    this.actions = const [],
    this.watchHit,
    this.degraded = false,
    this.errorCode = '',
    this.conversationId = '',
  });

  bool get isTerminal =>
      type == AssistantEventType.done || type == AssistantEventType.error;

  factory AssistantChatEvent.fromJson(Map<String, dynamic> json) {
    final rawType = _string(json['type']);
    final type = switch (rawType) {
      'token' => AssistantEventType.token,
      'source' => AssistantEventType.source,
      'tool_call' => AssistantEventType.toolCall,
      'confirm_required' => AssistantEventType.confirmRequired,
      'card' => AssistantEventType.card,
      'actions' => AssistantEventType.actions,
      'watch_hit' => AssistantEventType.watchHit,
      'done' => AssistantEventType.done,
      'error' => AssistantEventType.error,
      _ => AssistantEventType.unknown,
    };
    if (type == AssistantEventType.unknown) {
      return AssistantChatEvent(
        type: type,
        conversationId: _string(json['conversationId']),
      );
    }
    final text = _string(json['text']);
    final rawSource = json['source'];
    final source = rawSource is Map
        ? AssistantSourceReference.fromJson(
            Map<String, dynamic>.from(rawSource),
          )
        : null;
    final rawToolCall = json['toolCall'];
    final toolCall = rawToolCall is Map
        ? AssistantToolCall.fromJson(Map<String, dynamic>.from(rawToolCall))
        : null;
    final rawCard = json['card'];
    final card = rawCard is Map
        ? AssistantStructuredCard.fromJson(Map<String, dynamic>.from(rawCard))
        : null;
    final rawActions = json['actions'];
    final actions = <AssistantStructuredAction>[];
    if (rawActions is List) {
      for (final item in rawActions) {
        if (item is! Map) continue;
        final action = AssistantStructuredAction.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (action.action.isNotEmpty) actions.add(action);
      }
    }
    final rawWatchHit = json['watchHit'];
    final watchHit = rawWatchHit is Map
        ? AssistantWatchHitNotice.fromJson(
            Map<String, dynamic>.from(rawWatchHit),
          )
        : null;
    final errorCode = _string(json['errorCode']);
    if (type == AssistantEventType.token && text.isEmpty) {
      throw const FormatException('empty assistant token');
    }
    if (type == AssistantEventType.source && source == null) {
      throw const FormatException('missing assistant source');
    }
    if ((type == AssistantEventType.toolCall ||
            type == AssistantEventType.confirmRequired) &&
        toolCall == null) {
      throw const FormatException('missing assistant tool call');
    }
    if (type == AssistantEventType.card && card == null) {
      throw const FormatException('missing assistant card');
    }
    if (type == AssistantEventType.watchHit && watchHit == null) {
      throw const FormatException('missing assistant watch hit');
    }
    if (type == AssistantEventType.error &&
        (text.isEmpty || errorCode.isEmpty)) {
      throw const FormatException('invalid assistant error');
    }
    return AssistantChatEvent(
      type: type,
      text: text,
      source: source,
      toolCall: toolCall,
      card: card,
      actions: actions,
      watchHit: watchHit,
      degraded: json['degraded'] == true,
      errorCode: errorCode,
      conversationId: _string(json['conversationId']),
    );
  }
}

class MemoryRecord {
  final Object id;
  final String layer;
  final String dimension;
  final String value;
  final double score;
  final String source;
  final double confidence;
  final bool confirmed;
  final bool suppressed;
  final int updatedAt;

  const MemoryRecord({
    required this.id,
    required this.layer,
    required this.dimension,
    required this.value,
    this.score = 0,
    this.source = '',
    this.confidence = 0,
    this.confirmed = false,
    this.suppressed = false,
    this.updatedAt = 0,
  });

  String get idText => jsonInt64Id(id);
}

class WatchTask {
  final Object id;
  final String conditionType;
  final String targetType;
  final Object targetId;
  final String targetText;
  final bool enabled;
  final int createdAt;

  const WatchTask({
    required this.id,
    required this.conditionType,
    required this.targetType,
    this.targetId = 0,
    this.targetText = '',
    this.enabled = true,
    this.createdAt = 0,
  });

  String get idText => jsonInt64Id(id);
}

class WatchHit {
  final Object id;
  final Object taskId;
  final Object postId;
  final String title;
  final String summary;
  final int createdAt;
  final bool read;

  const WatchHit({
    required this.id,
    required this.taskId,
    required this.postId,
    this.title = '',
    this.summary = '',
    this.createdAt = 0,
    this.read = false,
  });

  String get idText => jsonInt64Id(id);

  bool get hasVerifiedPost => jsonInt64IsPositive(postId);
}

Map<String, dynamic>? decodePayloadJson(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = decodeApiJson(trimmed);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
  return null;
}

Object? verifiedPayloadId(Map<String, dynamic>? payload, String key) {
  if (payload == null) return null;
  final value = payload[key];
  if (!jsonInt64IsPositive(value)) return null;
  return jsonInt64Id(value);
}

String _string(Object? value) => value?.toString() ?? '';

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
