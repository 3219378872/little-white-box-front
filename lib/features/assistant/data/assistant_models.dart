enum AssistantEventType { token, source, toolCall, confirmRequired, done, error }

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

class AssistantChatEvent {
  final AssistantEventType type;
  final String text;
  final AssistantSourceReference? source;
  final AssistantToolCall? toolCall;
  final bool degraded;
  final String errorCode;
  final String conversationId;

  const AssistantChatEvent({
    required this.type,
    this.text = '',
    this.source,
    this.toolCall,
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
    final rawToolCall = json['toolCall'];
    final toolCall = rawToolCall is Map
        ? AssistantToolCall.fromJson(Map<String, dynamic>.from(rawToolCall))
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
    if (type == AssistantEventType.error &&
        (text.isEmpty || errorCode.isEmpty)) {
      throw const FormatException('invalid assistant error');
    }
    return AssistantChatEvent(
      type: type,
      text: text,
      source: source,
      toolCall: toolCall,
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
