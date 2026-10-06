part of 'assistant_models.dart';

// 研究类载荷的可选对象：null 表示缺省，非对象视为格式错误。
T? _researchObject<T>(Object? value, T Function(Map<String, dynamic>) decode) {
  if (value == null) return null;
  if (value is! Map) throw const FormatException('invalid research object');
  return decode(Map<String, dynamic>.from(value));
}

// 研究类载荷的列表：null 视为空列表，元素必须是非空对象；结果不可变。
List<T> _researchList<T>(
  Object? value,
  T Function(Map<String, dynamic>) decode,
) {
  if (value == null) return const [];
  if (value is! List) throw const FormatException('invalid research list');
  return List.unmodifiable(
    value.map(
      (item) =>
          _researchObject(item, decode) ??
          (throw const FormatException('empty research item')),
    ),
  );
}

/// 提问卡中的一个可选项。
class AssistantQuestionOption {
  final String id;
  final String label;
  const AssistantQuestionOption({required this.id, required this.label});
  factory AssistantQuestionOption.fromJson(Map<String, dynamic> json) =>
      AssistantQuestionOption(
        id: _string(json['id']),
        label: _string(json['label']),
      );
}

/// 提问卡中的一个问题；[selection] 只能是 single 或 multiple。
class AssistantQuestion {
  final String id;
  final String text;
  final String selection;
  final List<AssistantQuestionOption> options;
  const AssistantQuestion({
    required this.id,
    required this.text,
    required this.selection,
    required this.options,
  });
  factory AssistantQuestion.fromJson(Map<String, dynamic> json) {
    final selection = _string(json['selection']);
    if (!{'single', 'multiple'}.contains(selection)) {
      throw const FormatException('invalid question selection');
    }
    return AssistantQuestion(
      id: _string(json['id']),
      text: _string(json['text']),
      selection: selection,
      options: _researchList(json['options'], AssistantQuestionOption.fromJson),
    );
  }
}

/// 用户对一个问题的回答；[disposition] 是作答方式（如 answered），由提问卡填写。
class AssistantQuestionAnswer {
  final String questionId;
  final List<String> selectedOptionIds;
  final String text;
  final String disposition;
  const AssistantQuestionAnswer({
    required this.questionId,
    this.selectedOptionIds = const [],
    this.text = '',
    required this.disposition,
  });
  factory AssistantQuestionAnswer.fromJson(Map<String, dynamic> json) =>
      AssistantQuestionAnswer(
        questionId: _string(json['questionId']),
        selectedOptionIds: [
          for (final id in (json['selectedOptionIds'] as List? ?? const []))
            _string(id),
        ],
        text: _string(json['text']),
        disposition: _string(json['disposition']),
      );

  /// 选项 ID 排序后序列化，使同一回答的指纹与请求体稳定。
  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'selectedOptionIds': [...selectedOptionIds]..sort(),
    'text': text,
    'disposition': disposition,
  };
}

/// run 暂停时向用户发起的一组问题；[status] 为 pending 时等待作答，
/// 过了 [deadlineMs] 视为过期，需走续答。
class AssistantQuestionRequest {
  final String id;
  final Object runId;
  final Object messageId;
  final String status;
  final int deadlineMs;
  final List<AssistantQuestion> questions;
  final List<AssistantQuestionAnswer> answers;
  const AssistantQuestionRequest({
    required this.id,
    required this.runId,
    required this.messageId,
    required this.status,
    required this.deadlineMs,
    required this.questions,
    this.answers = const [],
  });

  /// 仍在等待作答。
  bool get isPending => status == 'pending';

  /// 服务端已标记过期，或仍为 pending 但本地时钟已过截止时间。
  bool get hasExpired =>
      status == 'expired' ||
      (isPending && DateTime.now().millisecondsSinceEpoch >= deadlineMs);
  factory AssistantQuestionRequest.fromJson(Map<String, dynamic> json) {
    final id = _string(json['id']);
    final runId = json['runId'] ?? 0;
    if (id.isEmpty || !jsonInt64IsPositive(runId)) {
      throw const FormatException('invalid question identity');
    }
    return AssistantQuestionRequest(
      id: id,
      runId: runId,
      messageId: json['messageId'] ?? 0,
      status: _string(json['status']),
      deadlineMs: _integer(json['deadlineMs']),
      questions: _researchList(json['questions'], AssistantQuestion.fromJson),
      answers: _researchList(json['answers'], AssistantQuestionAnswer.fromJson),
    );
  }
}

/// 来源中被引用的一段摘录。
class AssistantEvidence {
  final String id;
  final String kind;
  final String text;
  final int retrievedAtMs;
  const AssistantEvidence({
    required this.id,
    required this.kind,
    required this.text,
    this.retrievedAtMs = 0,
  });
  factory AssistantEvidence.fromJson(Map<String, dynamic> json) =>
      AssistantEvidence(
        id: _string(json['id']),
        kind: _string(json['kind']),
        text: _string(json['text']),
        retrievedAtMs: _integer(json['retrievedAtMs']),
      );
}

/// 研究型回答引用的来源；[available] 为 false 时来源已失效，只展示占位。
class AssistantResearchSource {
  final String handle;
  final String kind;
  final String authorityId;
  final String title;
  final String url;
  final String thumbnailUrl;
  final String author;
  final int publishedAtMs;
  final bool available;
  final List<AssistantEvidence> excerpts;
  const AssistantResearchSource({
    required this.handle,
    required this.kind,
    required this.authorityId,
    required this.title,
    required this.url,
    this.thumbnailUrl = '',
    this.author = '',
    this.publishedAtMs = 0,
    required this.available,
    this.excerpts = const [],
  });
  factory AssistantResearchSource.fromJson(Map<String, dynamic> json) =>
      AssistantResearchSource(
        handle: _string(json['handle']),
        kind: _string(json['kind']),
        authorityId: _string(json['authorityId']),
        title: _string(json['title']),
        url: _string(json['url']),
        thumbnailUrl: _string(json['thumbnailUrl']),
        author: _string(json['author']),
        publishedAtMs: _integer(json['publishedAtMs']),
        available: json['available'] == true,
        excerpts: _researchList(json['excerpts'], AssistantEvidence.fromJson),
      );
}

/// 回答块对某个来源的引用，[evidenceIds] 指向该来源的摘录。
class AssistantAnswerCitation {
  final String handle;
  final List<String> evidenceIds;
  const AssistantAnswerCitation({
    required this.handle,
    required this.evidenceIds,
  });
  factory AssistantAnswerCitation.fromJson(Map<String, dynamic> json) =>
      AssistantAnswerCitation(
        handle: _string(json['handle']),
        evidenceIds: [
          for (final id in (json['evidenceIds'] as List? ?? const []))
            _string(id),
        ],
      );
}

/// 结构化回答中的一个段落块及其引用。
class AssistantAnswerBlock {
  final String id;
  final String kind;
  final String text;
  final List<AssistantAnswerCitation> citations;
  const AssistantAnswerBlock({
    required this.id,
    required this.kind,
    required this.text,
    this.citations = const [],
  });
  factory AssistantAnswerBlock.fromJson(Map<String, dynamic> json) =>
      AssistantAnswerBlock(
        id: _string(json['id']),
        kind: _string(json['kind']),
        text: _string(json['text']),
        citations: _researchList(
          json['citations'],
          AssistantAnswerCitation.fromJson,
        ),
      );
}

/// 落库后的结构化回答（仅支持 version 1）：段落块加来源列表。
class AssistantAnswerPresentation {
  final Object messageId;
  final Object runId;
  final List<AssistantAnswerBlock> blocks;
  final List<AssistantResearchSource> sources;
  const AssistantAnswerPresentation({
    required this.messageId,
    required this.runId,
    required this.blocks,
    required this.sources,
  });

  /// 解码并校验：来源最多 10 个且 handle 唯一，每个引用都必须指向已列出的来源。
  factory AssistantAnswerPresentation.fromJson(Map<String, dynamic> json) {
    if (_integer(json['version']) != 1) {
      throw const FormatException('unsupported answer presentation version');
    }
    final value = AssistantAnswerPresentation(
      messageId: json['messageId'] ?? 0,
      runId: json['runId'] ?? 0,
      blocks: _researchList(json['blocks'], AssistantAnswerBlock.fromJson),
      sources: _researchList(json['sources'], AssistantResearchSource.fromJson),
    );
    final handles = {for (final source in value.sources) source.handle};
    if (value.sources.length > 10 || handles.length != value.sources.length) {
      throw const FormatException('invalid source list');
    }
    for (final block in value.blocks) {
      for (final citation in block.citations) {
        if (!handles.contains(citation.handle)) {
          throw const FormatException('unknown citation source');
        }
      }
    }
    return value;
  }
}
