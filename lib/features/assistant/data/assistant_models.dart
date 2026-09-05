import '../../../core/api/json_int64.dart';

part 'assistant_research_models.dart';

enum AssistantEventType {
  runStarted,
  token,
  responseReset,
  toolCall,
  toolResult,
  confirmRequired,
  sourceCard,
  memoryChanged,
  questionsRequired,
  questionsResolved,
  answerCommitted,
  done,
  error,
  unknown,
}

enum AssistantDisposition { started, redirected, steered, queued, unknown }

const memoryTargets = {'memory', 'user'};

const watchConditionTargetTypes = {
  'author_new_post': 'author',
  'tag_new_post': 'tag',
  'keyword_new_post': 'keyword',
  'post_revised': 'post',
};

class AssistantAttachment {
  final Object mediaId;
  final String url;

  const AssistantAttachment({required this.mediaId, required this.url});

  Map<String, dynamic> toJson() => {'mediaId': mediaId, 'url': url};
}

class AssistantThreadSummary {
  final AssistantQuestionRequest? questionRequest;
  final Object sessionId;
  final int unreadCount;
  final Object lastMessageId;
  final String lastMessagePreview;
  final int lastMessageAtMs;
  final Object activeRunId;
  final String activeRunStatus;
  final String activeRunPhase;

  const AssistantThreadSummary({
    this.questionRequest,
    this.sessionId = 0,
    this.unreadCount = 0,
    this.lastMessageId = 0,
    this.lastMessagePreview = '',
    this.lastMessageAtMs = 0,
    this.activeRunId = 0,
    this.activeRunStatus = '',
    this.activeRunPhase = '',
  });

  bool get hasActiveRun => jsonInt64IsPositive(activeRunId);

  factory AssistantThreadSummary.fromJson(Map<String, dynamic> json) {
    return AssistantThreadSummary(
      questionRequest: _researchObject(
        json['questionRequest'],
        AssistantQuestionRequest.fromJson,
      ),
      sessionId: json['sessionId'] ?? 0,
      unreadCount: _integer(json['unreadCount']),
      lastMessageId: json['lastMessageId'] ?? 0,
      lastMessagePreview: _string(json['lastMessagePreview']),
      lastMessageAtMs: _integer(json['lastMessageAtMs']),
      activeRunId: json['activeRunId'] ?? 0,
      activeRunStatus: _string(json['activeRunStatus']),
      activeRunPhase: _string(json['activeRunPhase']),
    );
  }
}

class AssistantHistoryMessage {
  final AssistantQuestionRequest? questionRequest;
  final AssistantAnswerPresentation? answerPresentation;
  final Object id;
  final Object sessionId;
  final Object runId;
  final String role;
  final String kind;
  final String content;
  final bool unread;
  final int createdAtMs;
  final Object changeId;

  const AssistantHistoryMessage({
    this.questionRequest,
    this.answerPresentation,
    required this.id,
    this.sessionId = 0,
    this.runId = 0,
    this.role = '',
    this.kind = '',
    this.content = '',
    this.unread = false,
    this.createdAtMs = 0,
    this.changeId = 0,
  });

  factory AssistantHistoryMessage.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id == null) {
      throw const FormatException('invalid assistant message');
    }
    return AssistantHistoryMessage(
      questionRequest: _researchObject(
        json['questionRequest'],
        AssistantQuestionRequest.fromJson,
      ),
      answerPresentation: _researchObject(
        json['answerPresentation'],
        AssistantAnswerPresentation.fromJson,
      ),
      id: id,
      sessionId: json['sessionId'] ?? 0,
      runId: json['runId'] ?? 0,
      role: _string(json['role']),
      kind: _string(json['kind']),
      content: _string(json['content']),
      unread: json['unread'] == true,
      createdAtMs: _integer(json['createdAtMs']),
      changeId: json['changeId'] ?? 0,
    );
  }
}

class AssistantMessagePage {
  final List<AssistantHistoryMessage> messages;
  final bool hasMore;
  final Object nextBeforeId;

  const AssistantMessagePage({
    this.messages = const [],
    this.hasMore = false,
    this.nextBeforeId = 0,
  });
}

class AssistantPostResult {
  final Object messageId;
  final Object sessionId;
  final Object runId;
  final AssistantDisposition disposition;

  const AssistantPostResult({
    required this.messageId,
    required this.sessionId,
    required this.runId,
    required this.disposition,
  });

  factory AssistantPostResult.fromJson(Map<String, dynamic> json) {
    return AssistantPostResult(
      messageId: json['messageId'] ?? 0,
      sessionId: json['sessionId'] ?? 0,
      runId: json['runId'] ?? 0,
      disposition: AssistantDisposition.values.firstWhere(
        (value) => value.name == _string(json['disposition']),
        orElse: () => AssistantDisposition.unknown,
      ),
    );
  }
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

class AssistantSourceCard {
  final String handle;
  final String kind;
  final String authorityId;
  final String title;
  final int revision;
  final String payloadJson;

  const AssistantSourceCard({
    required this.handle,
    required this.kind,
    required this.authorityId,
    this.title = '',
    this.revision = 0,
    this.payloadJson = '',
  });

  bool get isVerifiedPost => kind == 'post' && jsonInt64IsPositive(authorityId);

  bool get isRecommend => kind == 'recommend' || kind == 'post';

  Object? get postId => isVerifiedPost ? jsonInt64Id(authorityId) : null;

  factory AssistantSourceCard.fromJson(Map<String, dynamic> json) {
    final handle = _string(json['handle']).trim();
    final kind = _string(json['kind']).trim();
    final authorityId = _string(json['authorityId']).trim();
    if (handle.isEmpty || kind.isEmpty) {
      throw const FormatException('invalid assistant source card');
    }
    return AssistantSourceCard(
      handle: handle,
      kind: kind,
      authorityId: authorityId,
      title: _string(json['title']),
      revision: _integer(json['revision']),
      payloadJson: _string(json['payloadJson']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AssistantSourceCard &&
        other.handle == handle &&
        other.kind == kind &&
        other.authorityId == authorityId;
  }

  @override
  int get hashCode => Object.hash(handle, kind, authorityId);
}

class AssistantRunEvent {
  final AssistantQuestionRequest? questionRequest;
  final AssistantAnswerPresentation? answerPresentation;
  final Object runId;
  final int seq;
  final AssistantEventType type;
  final String text;
  final bool degraded;
  final String errorCode;
  final Object sessionId;
  final AssistantToolCall? toolCall;
  final AssistantSourceCard? sourceCard;
  final Object changeId;
  final String streamId;

  const AssistantRunEvent({
    this.questionRequest,
    this.answerPresentation,
    required this.type,
    this.runId = 0,
    this.seq = 0,
    this.text = '',
    this.degraded = false,
    this.errorCode = '',
    this.sessionId = 0,
    this.toolCall,
    this.sourceCard,
    this.changeId = 0,
    this.streamId = '',
  });

  bool get isTerminal =>
      type == AssistantEventType.done || type == AssistantEventType.error;

  factory AssistantRunEvent.fromJson(Map<String, dynamic> json) {
    final rawType = _string(json['type']);
    final type = switch (rawType) {
      'run_started' => AssistantEventType.runStarted,
      'token' => AssistantEventType.token,
      'response_reset' => AssistantEventType.responseReset,
      'tool_call' => AssistantEventType.toolCall,
      'tool_result' => AssistantEventType.toolResult,
      'confirm_required' => AssistantEventType.confirmRequired,
      'source_card' => AssistantEventType.sourceCard,
      'memory_changed' => AssistantEventType.memoryChanged,
      'questions_required' => AssistantEventType.questionsRequired,
      'questions_resolved' => AssistantEventType.questionsResolved,
      'answer_committed' => AssistantEventType.answerCommitted,
      'done' => AssistantEventType.done,
      'error' => AssistantEventType.error,
      _ => AssistantEventType.unknown,
    };
    if (type == AssistantEventType.unknown) {
      return AssistantRunEvent(
        type: type,
        runId: json['runId'] ?? 0,
        seq: _integer(json['seq']),
        sessionId: json['sessionId'] ?? 0,
      );
    }
    final text = _string(json['text']);
    final question = _researchObject(
      json['questionRequest'],
      AssistantQuestionRequest.fromJson,
    );
    final answer = _researchObject(
      json['answerPresentation'],
      AssistantAnswerPresentation.fromJson,
    );
    if ((type == AssistantEventType.questionsRequired ||
            type == AssistantEventType.questionsResolved) &&
        question == null) {
      throw const FormatException('missing assistant question');
    }
    if (type == AssistantEventType.answerCommitted && answer == null) {
      throw const FormatException('missing assistant answer presentation');
    }
    final rawToolCall = json['toolCall'];
    final toolCall = rawToolCall is Map
        ? AssistantToolCall.fromJson(Map<String, dynamic>.from(rawToolCall))
        : null;
    final rawSourceCard = json['sourceCard'];
    final sourceCard = rawSourceCard is Map
        ? AssistantSourceCard.fromJson(Map<String, dynamic>.from(rawSourceCard))
        : null;
    final errorCode = _string(json['errorCode']);
    final streamId = _string(json['streamId']).trim();
    if (type == AssistantEventType.token && text.isEmpty) {
      throw const FormatException('empty assistant token');
    }
    if (type == AssistantEventType.responseReset && streamId.isEmpty) {
      throw const FormatException('missing assistant stream id');
    }
    if ((type == AssistantEventType.toolCall ||
            type == AssistantEventType.toolResult ||
            type == AssistantEventType.confirmRequired) &&
        toolCall == null) {
      throw const FormatException('missing assistant tool call');
    }
    if (type == AssistantEventType.sourceCard && sourceCard == null) {
      throw const FormatException('missing assistant source card');
    }
    if (type == AssistantEventType.error &&
        (text.isEmpty || errorCode.isEmpty)) {
      throw const FormatException('invalid assistant error');
    }
    return AssistantRunEvent(
      questionRequest: question,
      answerPresentation: answer,
      runId: json['runId'] ?? 0,
      seq: _integer(json['seq']),
      type: type,
      text: text,
      degraded: json['degraded'] == true,
      errorCode: errorCode,
      sessionId: json['sessionId'] ?? 0,
      toolCall: toolCall,
      sourceCard: sourceCard,
      changeId: json['changeId'] ?? 0,
      streamId: streamId,
    );
  }
}

class MemoryRecord {
  final Object id;
  final String target;
  final String content;
  final int version;
  final int createdAtMs;
  final int updatedAtMs;

  const MemoryRecord({
    required this.id,
    required this.target,
    required this.content,
    this.version = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  String get idText => jsonInt64Id(id);
}

class MemoryCapacity {
  final String target;
  final int used;
  final int limit;

  const MemoryCapacity({
    required this.target,
    required this.used,
    required this.limit,
  });
}

class MemoryWriteResult {
  final MemoryRecord? entry;
  final Object changeId;

  const MemoryWriteResult({this.entry, this.changeId = 0});
}

class WatchTask {
  final Object id;
  final String conditionType;
  final String targetType;
  final Object targetId;
  final String targetText;
  final bool enabled;
  final int version;
  final int createdAt;

  const WatchTask({
    required this.id,
    required this.conditionType,
    required this.targetType,
    this.targetId = 0,
    this.targetText = '',
    this.enabled = true,
    this.version = 0,
    this.createdAt = 0,
  });

  String get idText => jsonInt64Id(id);
}

String _string(Object? value) => value?.toString() ?? '';

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
