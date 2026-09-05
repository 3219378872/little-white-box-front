part of 'assistant_models.dart';

T? _researchObject<T>(Object? value, T Function(Map<String, dynamic>) decode) {
  if (value == null) return null;
  if (value is! Map) throw const FormatException('invalid research object');
  return decode(Map<String, dynamic>.from(value));
}

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
  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'selectedOptionIds': [...selectedOptionIds]..sort(),
    'text': text,
    'disposition': disposition,
  };
}

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
  bool get isPending => status == 'pending';
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
