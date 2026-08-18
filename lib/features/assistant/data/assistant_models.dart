enum AssistantEventType { token, source, done, error }

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

class AssistantChatEvent {
  final AssistantEventType type;
  final String text;
  final AssistantSourceReference? source;
  final bool degraded;
  final String errorCode;
  final String conversationId;

  const AssistantChatEvent({
    required this.type,
    this.text = '',
    this.source,
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
      'done' => AssistantEventType.done,
      'error' => AssistantEventType.error,
      _ => throw const FormatException('unknown assistant event type'),
    };
    final text = _string(json['text']);
    final rawSource = json['source'];
    final source = rawSource is Map
        ? AssistantSourceReference.fromJson(
            Map<String, dynamic>.from(rawSource),
          )
        : null;
    final errorCode = _string(json['errorCode']);
    if (type == AssistantEventType.token && text.isEmpty) {
      throw const FormatException('empty assistant token');
    }
    if (type == AssistantEventType.source && source == null) {
      throw const FormatException('missing assistant source');
    }
    if (type == AssistantEventType.error &&
        (text.isEmpty || errorCode.isEmpty)) {
      throw const FormatException('invalid assistant error');
    }
    return AssistantChatEvent(
      type: type,
      text: text,
      source: source,
      degraded: json['degraded'] == true,
      errorCode: errorCode,
      conversationId: _string(json['conversationId']),
    );
  }
}

String _string(Object? value) => value?.toString() ?? '';

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
