// Generated from app/gateway/openapi.yaml. DO NOT EDIT.

class AdActionResp {
  final bool ok;
  AdActionResp({required this.ok});
  factory AdActionResp.fromJson(Map<String, dynamic> m) =>
      AdActionResp(ok: m['ok'] ?? false);
  Map<String, dynamic> toJson() => {'ok': ok};
}

class AdAssetContentResp {
  final String mimeType;
  final String contentBase64;
  AdAssetContentResp({required this.mimeType, required this.contentBase64});
  factory AdAssetContentResp.fromJson(Map<String, dynamic> m) =>
      AdAssetContentResp(
        mimeType: m['mimeType']?.toString() ?? "",
        contentBase64: m['contentBase64']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'mimeType': mimeType,
    'contentBase64': contentBase64,
  };
}

class AdAssetResp {
  final Object assetId;
  final String kind;
  final String sha256;
  final String mimeType;
  final num size;
  AdAssetResp({
    required this.assetId,
    required this.kind,
    required this.sha256,
    required this.mimeType,
    required this.size,
  });
  factory AdAssetResp.fromJson(Map<String, dynamic> m) => AdAssetResp(
    assetId: m['assetId'] ?? 0,
    kind: m['kind']?.toString() ?? "",
    sha256: m['sha256']?.toString() ?? "",
    mimeType: m['mimeType']?.toString() ?? "",
    size: m['size'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'assetId': assetId,
    'kind': kind,
    'sha256': sha256,
    'mimeType': mimeType,
    'size': size,
  };
}

class AdContentItem {
  final String title;
  final String body;
  final String cta;
  final String landingUrl;
  final String landingDomain;
  final List<AdMediaItem> media;
  final String market;
  final String language;
  final String industry;
  final String advertiserName;
  final num revision;
  AdContentItem({
    required this.title,
    required this.body,
    required this.cta,
    required this.landingUrl,
    required this.landingDomain,
    required this.media,
    required this.market,
    required this.language,
    required this.industry,
    required this.advertiserName,
    required this.revision,
  });
  factory AdContentItem.fromJson(Map<String, dynamic> m) => AdContentItem(
    title: m['title']?.toString() ?? "",
    body: m['body']?.toString() ?? "",
    cta: m['cta']?.toString() ?? "",
    landingUrl: m['landingUrl']?.toString() ?? "",
    landingDomain: m['landingDomain']?.toString() ?? "",
    media: ((m['media'] ?? []) as List)
        .map((i) => AdMediaItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList(),
    market: m['market']?.toString() ?? "",
    language: m['language']?.toString() ?? "",
    industry: m['industry']?.toString() ?? "",
    advertiserName: m['advertiserName']?.toString() ?? "",
    revision: m['revision'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'cta': cta,
    'landingUrl': landingUrl,
    'landingDomain': landingDomain,
    'media': media.map((i) => i.toJson()).toList(),
    'market': market,
    'language': language,
    'industry': industry,
    'advertiserName': advertiserName,
    'revision': revision,
  };
}

class AdItem {
  final Object adId;
  final num revision;
  final num approvedRevision;
  final String reviewStatus;
  final String servingStatus;
  final List<String> policyCodes;
  final AdContentItem latest;
  final AdContentItem? approved;
  final num startMs;
  final num endMs;
  final bool eligible;
  final num updatedAtMs;
  final String pauseReason;
  AdItem({
    required this.adId,
    required this.revision,
    required this.approvedRevision,
    required this.reviewStatus,
    required this.servingStatus,
    required this.policyCodes,
    required this.latest,
    required this.approved,
    required this.startMs,
    required this.endMs,
    required this.eligible,
    required this.updatedAtMs,
    required this.pauseReason,
  });
  factory AdItem.fromJson(Map<String, dynamic> m) => AdItem(
    adId: m['adId'] ?? 0,
    revision: m['revision'] ?? 0,
    approvedRevision: m['approvedRevision'] ?? 0,
    reviewStatus: m['reviewStatus']?.toString() ?? "",
    servingStatus: m['servingStatus']?.toString() ?? "",
    policyCodes: List<String>.from(m['policyCodes'] as List? ?? const []),
    latest: AdContentItem.fromJson(
      Map<String, dynamic>.from(m['latest'] as Map? ?? const {}),
    ),
    approved: m['approved'] == null
        ? null
        : AdContentItem.fromJson(
            Map<String, dynamic>.from(m['approved'] as Map? ?? const {}),
          ),
    startMs: m['startMs'] ?? 0,
    endMs: m['endMs'] ?? 0,
    eligible: m['eligible'] ?? false,
    updatedAtMs: m['updatedAtMs'] ?? 0,
    pauseReason: m['pauseReason']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'adId': adId,
    'revision': revision,
    'approvedRevision': approvedRevision,
    'reviewStatus': reviewStatus,
    'servingStatus': servingStatus,
    'policyCodes': policyCodes,
    'latest': latest.toJson(),
    'approved': approved?.toJson(),
    'startMs': startMs,
    'endMs': endMs,
    'eligible': eligible,
    'updatedAtMs': updatedAtMs,
    'pauseReason': pauseReason,
  };
}

class AdMediaItem {
  final Object mediaId;
  final String sha256;
  final String publicUrl;
  AdMediaItem({
    required this.mediaId,
    required this.sha256,
    required this.publicUrl,
  });
  factory AdMediaItem.fromJson(Map<String, dynamic> m) => AdMediaItem(
    mediaId: m['mediaId'] ?? 0,
    sha256: m['sha256']?.toString() ?? "",
    publicUrl: m['publicUrl']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'mediaId': mediaId,
    'sha256': sha256,
    'publicUrl': publicUrl,
  };
}

class AdPolicyCodeItem {
  final String code;
  final String title;
  final String category;
  AdPolicyCodeItem({
    required this.code,
    required this.title,
    required this.category,
  });
  factory AdPolicyCodeItem.fromJson(Map<String, dynamic> m) => AdPolicyCodeItem(
    code: m['code']?.toString() ?? "",
    title: m['title']?.toString() ?? "",
    category: m['category']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'code': code,
    'title': title,
    'category': category,
  };
}

class AdQualificationItem {
  final Object qualificationId;
  final String market;
  final String industry;
  final Object documentAssetId;
  final num validUntilMs;
  final String status;
  final num submittedRevision;
  AdQualificationItem({
    required this.qualificationId,
    required this.market,
    required this.industry,
    required this.documentAssetId,
    required this.validUntilMs,
    required this.status,
    required this.submittedRevision,
  });
  factory AdQualificationItem.fromJson(Map<String, dynamic> m) =>
      AdQualificationItem(
        qualificationId: m['qualificationId'] ?? 0,
        market: m['market']?.toString() ?? "",
        industry: m['industry']?.toString() ?? "",
        documentAssetId: m['documentAssetId'] ?? 0,
        validUntilMs: m['validUntilMs'] ?? 0,
        status: m['status']?.toString() ?? "",
        submittedRevision: m['submittedRevision'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'qualificationId': qualificationId,
    'market': market,
    'industry': industry,
    'documentAssetId': documentAssetId,
    'validUntilMs': validUntilMs,
    'status': status,
    'submittedRevision': submittedRevision,
  };
}

class AdResp {
  final AdItem ad;
  AdResp({required this.ad});
  factory AdResp.fromJson(Map<String, dynamic> m) => AdResp(
    ad: AdItem.fromJson(Map<String, dynamic>.from(m['ad'] as Map? ?? const {})),
  );
  Map<String, dynamic> toJson() => {'ad': ad.toJson()};
}

class AddAssistantMemoryReq {
  final String target;
  final String content;
  final String requestId;
  AddAssistantMemoryReq({
    required this.target,
    required this.content,
    required this.requestId,
  });
  factory AddAssistantMemoryReq.fromJson(Map<String, dynamic> m) =>
      AddAssistantMemoryReq(
        target: m['target']?.toString() ?? "",
        content: m['content']?.toString() ?? "",
        requestId: m['requestId']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'target': target,
    'content': content,
    'requestId': requestId,
  };
}

class AddAssistantMemoryResp {
  final AssistantMemoryEntry entry;
  final Object changeId;
  AddAssistantMemoryResp({required this.entry, required this.changeId});
  factory AddAssistantMemoryResp.fromJson(Map<String, dynamic> m) =>
      AddAssistantMemoryResp(
        entry: AssistantMemoryEntry.fromJson(
          Map<String, dynamic>.from(m['entry'] as Map? ?? const {}),
        ),
        changeId: m['changeId'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'entry': entry.toJson(),
    'changeId': changeId,
  };
}

class AddQualificationReq {
  final String market;
  final String industry;
  final Object documentAssetId;
  final num validUntilMs;
  final num expectedRevision;
  final String idempotencyKey;
  AddQualificationReq({
    required this.market,
    required this.industry,
    required this.documentAssetId,
    required this.validUntilMs,
    required this.expectedRevision,
    required this.idempotencyKey,
  });
  factory AddQualificationReq.fromJson(Map<String, dynamic> m) =>
      AddQualificationReq(
        market: m['market']?.toString() ?? "",
        industry: m['industry']?.toString() ?? "",
        documentAssetId: m['documentAssetId'] ?? 0,
        validUntilMs: m['validUntilMs'] ?? 0,
        expectedRevision: m['expectedRevision'] ?? 0,
        idempotencyKey: m['idempotencyKey']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'market': market,
    'industry': industry,
    'documentAssetId': documentAssetId,
    'validUntilMs': validUntilMs,
    'expectedRevision': expectedRevision,
    'idempotencyKey': idempotencyKey,
  };
}

class AdvertiserItem {
  final Object advertiserId;
  final String name;
  final List<String> markets;
  final num revision;
  final num approvedRevision;
  final String reviewStatus;
  final List<String> policyCodes;
  final List<AdQualificationItem> qualifications;
  final num updatedAtMs;
  AdvertiserItem({
    required this.advertiserId,
    required this.name,
    required this.markets,
    required this.revision,
    required this.approvedRevision,
    required this.reviewStatus,
    required this.policyCodes,
    required this.qualifications,
    required this.updatedAtMs,
  });
  factory AdvertiserItem.fromJson(Map<String, dynamic> m) => AdvertiserItem(
    advertiserId: m['advertiserId'] ?? 0,
    name: m['name']?.toString() ?? "",
    markets: List<String>.from(m['markets'] as List? ?? const []),
    revision: m['revision'] ?? 0,
    approvedRevision: m['approvedRevision'] ?? 0,
    reviewStatus: m['reviewStatus']?.toString() ?? "",
    policyCodes: List<String>.from(m['policyCodes'] as List? ?? const []),
    qualifications: ((m['qualifications'] ?? []) as List)
        .map(
          (i) =>
              AdQualificationItem.fromJson(Map<String, dynamic>.from(i as Map)),
        )
        .toList(),
    updatedAtMs: m['updatedAtMs'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'advertiserId': advertiserId,
    'name': name,
    'markets': markets,
    'revision': revision,
    'approvedRevision': approvedRevision,
    'reviewStatus': reviewStatus,
    'policyCodes': policyCodes,
    'qualifications': qualifications.map((i) => i.toJson()).toList(),
    'updatedAtMs': updatedAtMs,
  };
}

class AdvertiserResp {
  final bool found;
  final AdvertiserItem? advertiser;
  AdvertiserResp({required this.found, required this.advertiser});
  factory AdvertiserResp.fromJson(Map<String, dynamic> m) => AdvertiserResp(
    found: m['found'] ?? false,
    advertiser: m['advertiser'] == null
        ? null
        : AdvertiserItem.fromJson(
            Map<String, dynamic>.from(m['advertiser'] as Map? ?? const {}),
          ),
  );
  Map<String, dynamic> toJson() => {
    'found': found,
    'advertiser': advertiser?.toJson(),
  };
}

class AnswerAssistantQuestionsReq {
  final Object id;
  final String questionRequestId;
  final String requestId;
  final List<AssistantQuestionAnswer> answers;
  AnswerAssistantQuestionsReq({
    required this.id,
    required this.questionRequestId,
    required this.requestId,
    required this.answers,
  });
  factory AnswerAssistantQuestionsReq.fromJson(Map<String, dynamic> m) =>
      AnswerAssistantQuestionsReq(
        id: m['id'] ?? 0,
        questionRequestId: m['questionRequestId']?.toString() ?? "",
        requestId: m['requestId']?.toString() ?? "",
        answers: ((m['answers'] ?? []) as List)
            .map(
              (i) => AssistantQuestionAnswer.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'questionRequestId': questionRequestId,
    'requestId': requestId,
    'answers': answers.map((i) => i.toJson()).toList(),
  };
}

class AnswerAssistantQuestionsResp {
  final AssistantQuestionRequest questionRequest;
  AnswerAssistantQuestionsResp({required this.questionRequest});
  factory AnswerAssistantQuestionsResp.fromJson(Map<String, dynamic> m) =>
      AnswerAssistantQuestionsResp(
        questionRequest: AssistantQuestionRequest.fromJson(
          Map<String, dynamic>.from(m['questionRequest'] as Map? ?? const {}),
        ),
      );
  Map<String, dynamic> toJson() => {
    'questionRequest': questionRequest.toJson(),
  };
}

class ApplyAdvertiserReq {
  final String name;
  final List<String> markets;
  final num expectedRevision;
  final String idempotencyKey;
  ApplyAdvertiserReq({
    required this.name,
    required this.markets,
    required this.expectedRevision,
    required this.idempotencyKey,
  });
  factory ApplyAdvertiserReq.fromJson(Map<String, dynamic> m) =>
      ApplyAdvertiserReq(
        name: m['name']?.toString() ?? "",
        markets: List<String>.from(m['markets'] as List? ?? const []),
        expectedRevision: m['expectedRevision'] ?? 0,
        idempotencyKey: m['idempotencyKey']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'name': name,
    'markets': markets,
    'expectedRevision': expectedRevision,
    'idempotencyKey': idempotencyKey,
  };
}

class AssistantAnswerBlock {
  final String id;
  final String kind;
  final String text;
  final List<AssistantAnswerCitation> citations;
  AssistantAnswerBlock({
    required this.id,
    required this.kind,
    required this.text,
    required this.citations,
  });
  factory AssistantAnswerBlock.fromJson(Map<String, dynamic> m) =>
      AssistantAnswerBlock(
        id: m['id']?.toString() ?? "",
        kind: m['kind']?.toString() ?? "",
        text: m['text']?.toString() ?? "",
        citations: ((m['citations'] ?? []) as List)
            .map(
              (i) => AssistantAnswerCitation.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'text': text,
    'citations': citations.map((i) => i.toJson()).toList(),
  };
}

class AssistantAnswerCitation {
  final String handle;
  final List<String> evidenceIds;
  AssistantAnswerCitation({required this.handle, required this.evidenceIds});
  factory AssistantAnswerCitation.fromJson(Map<String, dynamic> m) =>
      AssistantAnswerCitation(
        handle: m['handle']?.toString() ?? "",
        evidenceIds: List<String>.from(m['evidenceIds'] as List? ?? const []),
      );
  Map<String, dynamic> toJson() => {
    'handle': handle,
    'evidenceIds': evidenceIds,
  };
}

class AssistantAnswerPresentation {
  final num version;
  final Object messageId;
  final Object runId;
  final List<AssistantAnswerBlock> blocks;
  final List<AssistantResearchSource> sources;
  AssistantAnswerPresentation({
    required this.version,
    required this.messageId,
    required this.runId,
    required this.blocks,
    required this.sources,
  });
  factory AssistantAnswerPresentation.fromJson(Map<String, dynamic> m) =>
      AssistantAnswerPresentation(
        version: m['version'] ?? 0,
        messageId: m['messageId'] ?? 0,
        runId: m['runId'] ?? 0,
        blocks: ((m['blocks'] ?? []) as List)
            .map(
              (i) => AssistantAnswerBlock.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
        sources: ((m['sources'] ?? []) as List)
            .map(
              (i) => AssistantResearchSource.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'version': version,
    'messageId': messageId,
    'runId': runId,
    'blocks': blocks.map((i) => i.toJson()).toList(),
    'sources': sources.map((i) => i.toJson()).toList(),
  };
}

class AssistantAttachment {
  final Object mediaId;
  final String url;
  AssistantAttachment({required this.mediaId, required this.url});
  factory AssistantAttachment.fromJson(Map<String, dynamic> m) =>
      AssistantAttachment(
        mediaId: m['mediaId'] ?? 0,
        url: m['url']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {'mediaId': mediaId, 'url': url};
}

class AssistantEvidence {
  final String id;
  final String handle;
  final String kind;
  final String text;
  final String commentId;
  final num retrievedAtMs;
  AssistantEvidence({
    required this.id,
    required this.handle,
    required this.kind,
    required this.text,
    required this.commentId,
    required this.retrievedAtMs,
  });
  factory AssistantEvidence.fromJson(Map<String, dynamic> m) =>
      AssistantEvidence(
        id: m['id']?.toString() ?? "",
        handle: m['handle']?.toString() ?? "",
        kind: m['kind']?.toString() ?? "",
        text: m['text']?.toString() ?? "",
        commentId: m['commentId']?.toString() ?? "",
        retrievedAtMs: m['retrievedAtMs'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'handle': handle,
    'kind': kind,
    'text': text,
    'commentId': commentId,
    'retrievedAtMs': retrievedAtMs,
  };
}

class AssistantMemoryCapacity {
  final String target;
  final num used;
  final num limit;
  AssistantMemoryCapacity({
    required this.target,
    required this.used,
    required this.limit,
  });
  factory AssistantMemoryCapacity.fromJson(Map<String, dynamic> m) =>
      AssistantMemoryCapacity(
        target: m['target']?.toString() ?? "",
        used: m['used'] ?? 0,
        limit: m['limit'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'target': target,
    'used': used,
    'limit': limit,
  };
}

class AssistantMemoryEntry {
  final Object id;
  final String target;
  final String content;
  final num version;
  final num createdAtMs;
  final num updatedAtMs;
  AssistantMemoryEntry({
    required this.id,
    required this.target,
    required this.content,
    required this.version,
    required this.createdAtMs,
    required this.updatedAtMs,
  });
  factory AssistantMemoryEntry.fromJson(Map<String, dynamic> m) =>
      AssistantMemoryEntry(
        id: m['id'] ?? 0,
        target: m['target']?.toString() ?? "",
        content: m['content']?.toString() ?? "",
        version: m['version'] ?? 0,
        createdAtMs: m['createdAtMs'] ?? 0,
        updatedAtMs: m['updatedAtMs'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'target': target,
    'content': content,
    'version': version,
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
  };
}

class AssistantMemoryOp {
  final String op;
  final Object id;
  final String target;
  final String content;
  final num version;
  AssistantMemoryOp({
    required this.op,
    required this.id,
    required this.target,
    required this.content,
    required this.version,
  });
  factory AssistantMemoryOp.fromJson(Map<String, dynamic> m) =>
      AssistantMemoryOp(
        op: m['op']?.toString() ?? "",
        id: m['id'] ?? 0,
        target: m['target']?.toString() ?? "",
        content: m['content']?.toString() ?? "",
        version: m['version'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'op': op,
    'id': id,
    'target': target,
    'content': content,
    'version': version,
  };
}

class AssistantMessage {
  final Object id;
  final Object sessionId;
  final Object runId;
  final String role;
  final String kind;
  final String content;
  final bool unread;
  final num createdAtMs;
  final Object changeId;
  final AssistantQuestionRequest? questionRequest;
  final AssistantAnswerPresentation? answerPresentation;
  AssistantMessage({
    required this.id,
    required this.sessionId,
    required this.runId,
    required this.role,
    required this.kind,
    required this.content,
    required this.unread,
    required this.createdAtMs,
    required this.changeId,
    required this.questionRequest,
    required this.answerPresentation,
  });
  factory AssistantMessage.fromJson(Map<String, dynamic> m) => AssistantMessage(
    id: m['id'] ?? 0,
    sessionId: m['sessionId'] ?? 0,
    runId: m['runId'] ?? 0,
    role: m['role']?.toString() ?? "",
    kind: m['kind']?.toString() ?? "",
    content: m['content']?.toString() ?? "",
    unread: m['unread'] ?? false,
    createdAtMs: m['createdAtMs'] ?? 0,
    changeId: m['changeId'] ?? 0,
    questionRequest: m['questionRequest'] == null
        ? null
        : AssistantQuestionRequest.fromJson(
            Map<String, dynamic>.from(m['questionRequest'] as Map? ?? const {}),
          ),
    answerPresentation: m['answerPresentation'] == null
        ? null
        : AssistantAnswerPresentation.fromJson(
            Map<String, dynamic>.from(
              m['answerPresentation'] as Map? ?? const {},
            ),
          ),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'runId': runId,
    'role': role,
    'kind': kind,
    'content': content,
    'unread': unread,
    'createdAtMs': createdAtMs,
    'changeId': changeId,
    'questionRequest': questionRequest?.toJson(),
    'answerPresentation': answerPresentation?.toJson(),
  };
}

class AssistantQuestion {
  final String id;
  final String text;
  final String selection;
  final List<AssistantQuestionOption> options;
  AssistantQuestion({
    required this.id,
    required this.text,
    required this.selection,
    required this.options,
  });
  factory AssistantQuestion.fromJson(Map<String, dynamic> m) =>
      AssistantQuestion(
        id: m['id']?.toString() ?? "",
        text: m['text']?.toString() ?? "",
        selection: m['selection']?.toString() ?? "",
        options: ((m['options'] ?? []) as List)
            .map(
              (i) => AssistantQuestionOption.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'selection': selection,
    'options': options.map((i) => i.toJson()).toList(),
  };
}

class AssistantQuestionAnswer {
  final String questionId;
  final List<String> selectedOptionIds;
  final String text;
  final String disposition;
  AssistantQuestionAnswer({
    required this.questionId,
    required this.selectedOptionIds,
    required this.text,
    required this.disposition,
  });
  factory AssistantQuestionAnswer.fromJson(Map<String, dynamic> m) =>
      AssistantQuestionAnswer(
        questionId: m['questionId']?.toString() ?? "",
        selectedOptionIds: List<String>.from(
          m['selectedOptionIds'] as List? ?? const [],
        ),
        text: m['text']?.toString() ?? "",
        disposition: m['disposition']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'selectedOptionIds': selectedOptionIds,
    'text': text,
    'disposition': disposition,
  };
}

class AssistantQuestionContext {
  final Object runId;
  final String questionRequestId;
  final List<AssistantQuestionAnswer> answers;
  AssistantQuestionContext({
    required this.runId,
    required this.questionRequestId,
    required this.answers,
  });
  factory AssistantQuestionContext.fromJson(Map<String, dynamic> m) =>
      AssistantQuestionContext(
        runId: m['runId'] ?? 0,
        questionRequestId: m['questionRequestId']?.toString() ?? "",
        answers: ((m['answers'] ?? []) as List)
            .map(
              (i) => AssistantQuestionAnswer.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'runId': runId,
    'questionRequestId': questionRequestId,
    'answers': answers.map((i) => i.toJson()).toList(),
  };
}

class AssistantQuestionOption {
  final String id;
  final String label;
  AssistantQuestionOption({required this.id, required this.label});
  factory AssistantQuestionOption.fromJson(Map<String, dynamic> m) =>
      AssistantQuestionOption(
        id: m['id']?.toString() ?? "",
        label: m['label']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {'id': id, 'label': label};
}

class AssistantQuestionRequest {
  final String id;
  final Object runId;
  final String callId;
  final Object messageId;
  final String status;
  final List<AssistantQuestion> questions;
  final List<AssistantQuestionAnswer> answers;
  final num deadlineMs;
  final num createdAtMs;
  AssistantQuestionRequest({
    required this.id,
    required this.runId,
    required this.callId,
    required this.messageId,
    required this.status,
    required this.questions,
    required this.answers,
    required this.deadlineMs,
    required this.createdAtMs,
  });
  factory AssistantQuestionRequest.fromJson(Map<String, dynamic> m) =>
      AssistantQuestionRequest(
        id: m['id']?.toString() ?? "",
        runId: m['runId'] ?? 0,
        callId: m['callId']?.toString() ?? "",
        messageId: m['messageId'] ?? 0,
        status: m['status']?.toString() ?? "",
        questions: ((m['questions'] ?? []) as List)
            .map(
              (i) => AssistantQuestion.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
        answers: ((m['answers'] ?? []) as List)
            .map(
              (i) => AssistantQuestionAnswer.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
        deadlineMs: m['deadlineMs'] ?? 0,
        createdAtMs: m['createdAtMs'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'runId': runId,
    'callId': callId,
    'messageId': messageId,
    'status': status,
    'questions': questions.map((i) => i.toJson()).toList(),
    'answers': answers.map((i) => i.toJson()).toList(),
    'deadlineMs': deadlineMs,
    'createdAtMs': createdAtMs,
  };
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
  factory AssistantRecommendFeedbackReq.fromJson(Map<String, dynamic> m) =>
      AssistantRecommendFeedbackReq(
        requestId: m['requestId']?.toString() ?? "",
        postId: m['postId'] ?? 0,
        reason: m['reason']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'postId': postId,
    'reason': reason,
  };
}

class AssistantRecommendFeedbackResp {
  AssistantRecommendFeedbackResp();
  factory AssistantRecommendFeedbackResp.fromJson(Map<String, dynamic> m) =>
      AssistantRecommendFeedbackResp();
  Map<String, dynamic> toJson() => {};
}

class AssistantResearchSource {
  final String handle;
  final String kind;
  final String authorityId;
  final String title;
  final num revision;
  final String url;
  final String thumbnailUrl;
  final String author;
  final num publishedAtMs;
  final bool available;
  final String unavailableReason;
  final List<AssistantEvidence> excerpts;
  AssistantResearchSource({
    required this.handle,
    required this.kind,
    required this.authorityId,
    required this.title,
    required this.revision,
    required this.url,
    required this.thumbnailUrl,
    required this.author,
    required this.publishedAtMs,
    required this.available,
    required this.unavailableReason,
    required this.excerpts,
  });
  factory AssistantResearchSource.fromJson(Map<String, dynamic> m) =>
      AssistantResearchSource(
        handle: m['handle']?.toString() ?? "",
        kind: m['kind']?.toString() ?? "",
        authorityId: m['authorityId']?.toString() ?? "",
        title: m['title']?.toString() ?? "",
        revision: m['revision'] ?? 0,
        url: m['url']?.toString() ?? "",
        thumbnailUrl: m['thumbnailUrl']?.toString() ?? "",
        author: m['author']?.toString() ?? "",
        publishedAtMs: m['publishedAtMs'] ?? 0,
        available: m['available'] ?? false,
        unavailableReason: m['unavailableReason']?.toString() ?? "",
        excerpts: ((m['excerpts'] ?? []) as List)
            .map(
              (i) => AssistantEvidence.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'handle': handle,
    'kind': kind,
    'authorityId': authorityId,
    'title': title,
    'revision': revision,
    'url': url,
    'thumbnailUrl': thumbnailUrl,
    'author': author,
    'publishedAtMs': publishedAtMs,
    'available': available,
    'unavailableReason': unavailableReason,
    'excerpts': excerpts.map((i) => i.toJson()).toList(),
  };
}

class AssistantRunEvent {
  final Object runId;
  final num seq;
  final String type;
  final String text;
  final bool degraded;
  final String errorCode;
  final Object sessionId;
  final AssistantToolCallInfo? toolCall;
  final AssistantSourceCard? sourceCard;
  final Object changeId;
  final String streamId;
  final AssistantQuestionRequest? questionRequest;
  final AssistantAnswerPresentation? answerPresentation;
  AssistantRunEvent({
    required this.runId,
    required this.seq,
    required this.type,
    required this.text,
    required this.degraded,
    required this.errorCode,
    required this.sessionId,
    required this.toolCall,
    required this.sourceCard,
    required this.changeId,
    required this.streamId,
    required this.questionRequest,
    required this.answerPresentation,
  });
  factory AssistantRunEvent.fromJson(Map<String, dynamic> m) =>
      AssistantRunEvent(
        runId: m['runId'] ?? 0,
        seq: m['seq'] ?? 0,
        type: m['type']?.toString() ?? "",
        text: m['text']?.toString() ?? "",
        degraded: m['degraded'] ?? false,
        errorCode: m['errorCode']?.toString() ?? "",
        sessionId: m['sessionId'] ?? 0,
        toolCall: m['toolCall'] == null
            ? null
            : AssistantToolCallInfo.fromJson(
                Map<String, dynamic>.from(m['toolCall'] as Map? ?? const {}),
              ),
        sourceCard: m['sourceCard'] == null
            ? null
            : AssistantSourceCard.fromJson(
                Map<String, dynamic>.from(m['sourceCard'] as Map? ?? const {}),
              ),
        changeId: m['changeId'] ?? 0,
        streamId: m['streamId']?.toString() ?? "",
        questionRequest: m['questionRequest'] == null
            ? null
            : AssistantQuestionRequest.fromJson(
                Map<String, dynamic>.from(
                  m['questionRequest'] as Map? ?? const {},
                ),
              ),
        answerPresentation: m['answerPresentation'] == null
            ? null
            : AssistantAnswerPresentation.fromJson(
                Map<String, dynamic>.from(
                  m['answerPresentation'] as Map? ?? const {},
                ),
              ),
      );
  Map<String, dynamic> toJson() => {
    'runId': runId,
    'seq': seq,
    'type': type,
    'text': text,
    'degraded': degraded,
    'errorCode': errorCode,
    'sessionId': sessionId,
    'toolCall': toolCall?.toJson(),
    'sourceCard': sourceCard?.toJson(),
    'changeId': changeId,
    'streamId': streamId,
    'questionRequest': questionRequest?.toJson(),
    'answerPresentation': answerPresentation?.toJson(),
  };
}

class AssistantRunEventsReq {
  final Object id;
  final num afterSeq;
  AssistantRunEventsReq({required this.id, required this.afterSeq});
  factory AssistantRunEventsReq.fromJson(Map<String, dynamic> m) =>
      AssistantRunEventsReq(id: m['id'] ?? 0, afterSeq: m['afterSeq'] ?? 0);
  Map<String, dynamic> toJson() => {'id': id, 'afterSeq': afterSeq};
}

class AssistantSourceCard {
  final String handle;
  final String kind;
  final String authorityId;
  final String title;
  final num revision;
  final String payloadJson;
  AssistantSourceCard({
    required this.handle,
    required this.kind,
    required this.authorityId,
    required this.title,
    required this.revision,
    required this.payloadJson,
  });
  factory AssistantSourceCard.fromJson(Map<String, dynamic> m) =>
      AssistantSourceCard(
        handle: m['handle']?.toString() ?? "",
        kind: m['kind']?.toString() ?? "",
        authorityId: m['authorityId']?.toString() ?? "",
        title: m['title']?.toString() ?? "",
        revision: m['revision'] ?? 0,
        payloadJson: m['payloadJson']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'handle': handle,
    'kind': kind,
    'authorityId': authorityId,
    'title': title,
    'revision': revision,
    'payloadJson': payloadJson,
  };
}

class AssistantThread {
  final Object sessionId;
  final num unreadCount;
  final Object lastMessageId;
  final String lastMessagePreview;
  final num lastMessageAtMs;
  final Object activeRunId;
  final String activeRunStatus;
  final String activeRunPhase;
  final AssistantQuestionRequest? questionRequest;
  AssistantThread({
    required this.sessionId,
    required this.unreadCount,
    required this.lastMessageId,
    required this.lastMessagePreview,
    required this.lastMessageAtMs,
    required this.activeRunId,
    required this.activeRunStatus,
    required this.activeRunPhase,
    required this.questionRequest,
  });
  factory AssistantThread.fromJson(Map<String, dynamic> m) => AssistantThread(
    sessionId: m['sessionId'] ?? 0,
    unreadCount: m['unreadCount'] ?? 0,
    lastMessageId: m['lastMessageId'] ?? 0,
    lastMessagePreview: m['lastMessagePreview']?.toString() ?? "",
    lastMessageAtMs: m['lastMessageAtMs'] ?? 0,
    activeRunId: m['activeRunId'] ?? 0,
    activeRunStatus: m['activeRunStatus']?.toString() ?? "",
    activeRunPhase: m['activeRunPhase']?.toString() ?? "",
    questionRequest: m['questionRequest'] == null
        ? null
        : AssistantQuestionRequest.fromJson(
            Map<String, dynamic>.from(m['questionRequest'] as Map? ?? const {}),
          ),
  );
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'unreadCount': unreadCount,
    'lastMessageId': lastMessageId,
    'lastMessagePreview': lastMessagePreview,
    'lastMessageAtMs': lastMessageAtMs,
    'activeRunId': activeRunId,
    'activeRunStatus': activeRunStatus,
    'activeRunPhase': activeRunPhase,
    'questionRequest': questionRequest?.toJson(),
  };
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
  factory AssistantToolCallInfo.fromJson(Map<String, dynamic> m) =>
      AssistantToolCallInfo(
        callId: m['callId']?.toString() ?? "",
        tool: m['tool']?.toString() ?? "",
        summary: m['summary']?.toString() ?? "",
        payloadJson: m['payloadJson']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'callId': callId,
    'tool': tool,
    'summary': summary,
    'payloadJson': payloadJson,
  };
}

class AssistantWatchTask {
  final Object id;
  final String conditionType;
  final String targetType;
  final Object targetId;
  final String targetText;
  final bool enabled;
  final num version;
  final num createdAt;
  AssistantWatchTask({
    required this.id,
    required this.conditionType,
    required this.targetType,
    required this.targetId,
    required this.targetText,
    required this.enabled,
    required this.version,
    required this.createdAt,
  });
  factory AssistantWatchTask.fromJson(Map<String, dynamic> m) =>
      AssistantWatchTask(
        id: m['id'] ?? 0,
        conditionType: m['conditionType']?.toString() ?? "",
        targetType: m['targetType']?.toString() ?? "",
        targetId: m['targetId'] ?? 0,
        targetText: m['targetText']?.toString() ?? "",
        enabled: m['enabled'] ?? false,
        version: m['version'] ?? 0,
        createdAt: m['createdAt'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'conditionType': conditionType,
    'targetType': targetType,
    'targetId': targetId,
    'targetText': targetText,
    'enabled': enabled,
    'version': version,
    'createdAt': createdAt,
  };
}

class BatchAssistantMemoryReq {
  final String requestId;
  final List<AssistantMemoryOp> ops;
  BatchAssistantMemoryReq({required this.requestId, required this.ops});
  factory BatchAssistantMemoryReq.fromJson(Map<String, dynamic> m) =>
      BatchAssistantMemoryReq(
        requestId: m['requestId']?.toString() ?? "",
        ops: ((m['ops'] ?? []) as List)
            .map(
              (i) => AssistantMemoryOp.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'ops': ops.map((i) => i.toJson()).toList(),
  };
}

class BatchAssistantMemoryResp {
  final List<AssistantMemoryEntry> entries;
  final List<Object> changeIds;
  BatchAssistantMemoryResp({required this.entries, required this.changeIds});
  factory BatchAssistantMemoryResp.fromJson(Map<String, dynamic> m) =>
      BatchAssistantMemoryResp(
        entries: ((m['entries'] ?? []) as List)
            .map(
              (i) => AssistantMemoryEntry.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
        changeIds: List<Object>.from(m['changeIds'] as List? ?? const []),
      );
  Map<String, dynamic> toJson() => {
    'entries': entries.map((i) => i.toJson()).toList(),
    'changeIds': changeIds,
  };
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
  factory BehaviorEvent.fromJson(Map<String, dynamic> m) => BehaviorEvent(
    clientEventId: m['clientEventId']?.toString() ?? "",
    occurredAt: m['occurredAt'] ?? 0,
    action: m['action']?.toString() ?? "",
    targetId: m['targetId'] ?? 0,
    targetType: m['targetType']?.toString() ?? "",
    scene: m['scene']?.toString() ?? "",
    requestId: m['requestId']?.toString() ?? "",
    position: m['position'] == null
        ? null
        : (m['position'] is num)
        ? (m['position'] as num).toInt()
        : 0,
    durationMs: m['durationMs'] == null
        ? null
        : (m['durationMs'] is num)
        ? (m['durationMs'] as num).toInt()
        : 0,
    recallSource: m['recallSource']?.toString() ?? "",
    modelVersion: m['modelVersion']?.toString() ?? "",
    experimentId: m['experimentId']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
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
  factory BehaviorEventResult.fromJson(Map<String, dynamic> m) =>
      BehaviorEventResult(
        clientEventId: m['clientEventId']?.toString() ?? "",
        eventId: m['eventId'] ?? 0,
        accepted: m['accepted'] ?? false,
        code: m['code'] ?? 0,
        reason: m['reason']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'clientEventId': clientEventId,
    'eventId': eventId,
    'accepted': accepted,
    'code': code,
    'reason': reason,
  };
}

class CancelAssistantRunReq {
  final Object id;
  CancelAssistantRunReq({required this.id});
  factory CancelAssistantRunReq.fromJson(Map<String, dynamic> m) =>
      CancelAssistantRunReq(id: m['id'] ?? 0);
  Map<String, dynamic> toJson() => {'id': id};
}

class CancelAssistantRunResp {
  CancelAssistantRunResp();
  factory CancelAssistantRunResp.fromJson(Map<String, dynamic> m) =>
      CancelAssistantRunResp();
  Map<String, dynamic> toJson() => {};
}

class ClaimReviewTaskReq {
  final String purpose;
  ClaimReviewTaskReq({required this.purpose});
  factory ClaimReviewTaskReq.fromJson(Map<String, dynamic> m) =>
      ClaimReviewTaskReq(purpose: m['purpose']?.toString() ?? "");
  Map<String, dynamic> toJson() => {'purpose': purpose};
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
  final num replyCount;
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
  factory CommentItem.fromJson(Map<String, dynamic> m) => CommentItem(
    id: m['id'] ?? 0,
    userId: m['userId'] ?? 0,
    userName: m['userName']?.toString() ?? "",
    userAvatar: m['userAvatar']?.toString() ?? "",
    parentId: m['parentId'] ?? 0,
    replyUserId: m['replyUserId'] ?? 0,
    content: m['content']?.toString() ?? "",
    likeCount: m['likeCount'] ?? 0,
    createdAt: m['createdAt'] ?? 0,
    replyCount: m['replyCount'] ?? 0,
    replies: ((m['replies'] ?? []) as List)
        .map((i) => CommentItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
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
    'replies': replies.map((i) => i.toJson()).toList(),
  };
}

class ConfirmAssistantRunReq {
  final Object id;
  final String callId;
  final bool approved;
  ConfirmAssistantRunReq({
    required this.id,
    required this.callId,
    required this.approved,
  });
  factory ConfirmAssistantRunReq.fromJson(Map<String, dynamic> m) =>
      ConfirmAssistantRunReq(
        id: m['id'] ?? 0,
        callId: m['callId']?.toString() ?? "",
        approved: m['approved'] ?? false,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'callId': callId,
    'approved': approved,
  };
}

class ConfirmAssistantRunResp {
  ConfirmAssistantRunResp();
  factory ConfirmAssistantRunResp.fromJson(Map<String, dynamic> m) =>
      ConfirmAssistantRunResp();
  Map<String, dynamic> toJson() => {};
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
  factory ConversationItem.fromJson(Map<String, dynamic> m) => ConversationItem(
    id: m['id'] ?? 0,
    targetUserId: m['targetUserId'] ?? 0,
    targetUserName: m['targetUserName']?.toString() ?? "",
    targetUserAvatar: m['targetUserAvatar']?.toString() ?? "",
    lastMessage: m['lastMessage']?.toString() ?? "",
    lastMessageTime: m['lastMessageTime'] ?? 0,
    unreadCount: m['unreadCount'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'targetUserId': targetUserId,
    'targetUserName': targetUserName,
    'targetUserAvatar': targetUserAvatar,
    'lastMessage': lastMessage,
    'lastMessageTime': lastMessageTime,
    'unreadCount': unreadCount,
  };
}

class CreateAdReq {
  final String title;
  final String body;
  final String cta;
  final String landingUrl;
  final List<Object> mediaIds;
  final String market;
  final String industry;
  final num startMs;
  final num endMs;
  final String idempotencyKey;
  CreateAdReq({
    required this.title,
    required this.body,
    required this.cta,
    required this.landingUrl,
    required this.mediaIds,
    required this.market,
    required this.industry,
    required this.startMs,
    required this.endMs,
    required this.idempotencyKey,
  });
  factory CreateAdReq.fromJson(Map<String, dynamic> m) => CreateAdReq(
    title: m['title']?.toString() ?? "",
    body: m['body']?.toString() ?? "",
    cta: m['cta']?.toString() ?? "",
    landingUrl: m['landingUrl']?.toString() ?? "",
    mediaIds: List<Object>.from(m['mediaIds'] as List? ?? const []),
    market: m['market']?.toString() ?? "",
    industry: m['industry']?.toString() ?? "",
    startMs: m['startMs'] ?? 0,
    endMs: m['endMs'] ?? 0,
    idempotencyKey: m['idempotencyKey']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'cta': cta,
    'landingUrl': landingUrl,
    'mediaIds': mediaIds,
    'market': market,
    'industry': industry,
    'startMs': startMs,
    'endMs': endMs,
    'idempotencyKey': idempotencyKey,
  };
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
  factory CreateAssistantWatchReq.fromJson(Map<String, dynamic> m) =>
      CreateAssistantWatchReq(
        conditionType: m['conditionType']?.toString() ?? "",
        targetType: m['targetType']?.toString() ?? "",
        targetId: m['targetId'] ?? 0,
        targetText: m['targetText']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'conditionType': conditionType,
    'targetType': targetType,
    'targetId': targetId,
    'targetText': targetText,
  };
}

class CreateAssistantWatchResp {
  final AssistantWatchTask task;
  CreateAssistantWatchResp({required this.task});
  factory CreateAssistantWatchResp.fromJson(Map<String, dynamic> m) =>
      CreateAssistantWatchResp(
        task: AssistantWatchTask.fromJson(
          Map<String, dynamic>.from(m['task'] as Map? ?? const {}),
        ),
      );
  Map<String, dynamic> toJson() => {'task': task.toJson()};
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
  factory CreateCommentReq.fromJson(Map<String, dynamic> m) => CreateCommentReq(
    postId: m['postId'] ?? 0,
    parentId: m['parentId'] ?? 0,
    replyUserId: m['replyUserId'] ?? 0,
    content: m['content']?.toString() ?? "",
    idempotencyKey: m['idempotencyKey']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'postId': postId,
    'parentId': parentId,
    'replyUserId': replyUserId,
    'content': content,
    'idempotencyKey': idempotencyKey,
  };
}

class CreateCommentResp {
  final Object commentId;
  CreateCommentResp({required this.commentId});
  factory CreateCommentResp.fromJson(Map<String, dynamic> m) =>
      CreateCommentResp(commentId: m['commentId'] ?? 0);
  Map<String, dynamic> toJson() => {'commentId': commentId};
}

class CreatePostReq {
  final String title;
  final String content;
  final List<String> images;
  final List<String> tags;
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
  factory CreatePostReq.fromJson(Map<String, dynamic> m) => CreatePostReq(
    title: m['title']?.toString() ?? "",
    content: m['content']?.toString() ?? "",
    images: List<String>.from(m['images'] as List? ?? const []),
    tags: List<String>.from(m['tags'] as List? ?? const []),
    status: m['status'] ?? 0,
    idempotencyKey: m['idempotencyKey']?.toString() ?? "",
    mediaIds: List<Object>.from(m['mediaIds'] as List? ?? const []),
  );
  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'images': images,
    'tags': tags,
    'status': status,
    'idempotencyKey': idempotencyKey,
    'mediaIds': mediaIds,
  };
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
  factory CreatePostResp.fromJson(Map<String, dynamic> m) => CreatePostResp(
    postId: m['postId'] ?? 0,
    status: m['status'] ?? 0,
    revision: m['revision'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'postId': postId,
    'status': status,
    'revision': revision,
  };
}

class DeleteAssistantHistoryResp {
  DeleteAssistantHistoryResp();
  factory DeleteAssistantHistoryResp.fromJson(Map<String, dynamic> m) =>
      DeleteAssistantHistoryResp();
  Map<String, dynamic> toJson() => {};
}

class DeleteAssistantWatchReq {
  final Object id;
  final num expectedVersion;
  DeleteAssistantWatchReq({required this.id, required this.expectedVersion});
  factory DeleteAssistantWatchReq.fromJson(Map<String, dynamic> m) =>
      DeleteAssistantWatchReq(
        id: m['id'] ?? 0,
        expectedVersion: m['expectedVersion'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'expectedVersion': expectedVersion,
  };
}

class DeleteAssistantWatchResp {
  DeleteAssistantWatchResp();
  factory DeleteAssistantWatchResp.fromJson(Map<String, dynamic> m) =>
      DeleteAssistantWatchResp();
  Map<String, dynamic> toJson() => {};
}

class DeleteCommentReq {
  final Object commentId;
  DeleteCommentReq({required this.commentId});
  factory DeleteCommentReq.fromJson(Map<String, dynamic> m) =>
      DeleteCommentReq(commentId: m['commentId'] ?? 0);
  Map<String, dynamic> toJson() => {'commentId': commentId};
}

class DeleteCommentResp {
  DeleteCommentResp();
  factory DeleteCommentResp.fromJson(Map<String, dynamic> m) =>
      DeleteCommentResp();
  Map<String, dynamic> toJson() => {};
}

class DeletePostResp {
  DeletePostResp();
  factory DeletePostResp.fromJson(Map<String, dynamic> m) => DeletePostResp();
  Map<String, dynamic> toJson() => {};
}

class DeletePostV2Req {
  final Object postId;
  final num expectedRevision;
  DeletePostV2Req({required this.postId, required this.expectedRevision});
  factory DeletePostV2Req.fromJson(Map<String, dynamic> m) => DeletePostV2Req(
    postId: m['postId'] ?? 0,
    expectedRevision: m['expectedRevision'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'postId': postId,
    'expectedRevision': expectedRevision,
  };
}

class FavoriteReq {
  final Object postId;
  FavoriteReq({required this.postId});
  factory FavoriteReq.fromJson(Map<String, dynamic> m) =>
      FavoriteReq(postId: m['postId'] ?? 0);
  Map<String, dynamic> toJson() => {'postId': postId};
}

class FavoriteResp {
  FavoriteResp();
  factory FavoriteResp.fromJson(Map<String, dynamic> m) => FavoriteResp();
  Map<String, dynamic> toJson() => {};
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
  factory FeedItem.fromJson(Map<String, dynamic> m) => FeedItem(
    postId: m['postId'] ?? 0,
    authorId: m['authorId'] ?? 0,
    authorName: m['authorName']?.toString() ?? "",
    authorAvatar: m['authorAvatar']?.toString() ?? "",
    createdAt: m['createdAt'] ?? 0,
    feedType: m['feedType'] ?? 0,
    title: m['title']?.toString() ?? "",
    content: m['content']?.toString() ?? "",
    images: List<String>.from(m['images'] as List? ?? const []),
    tags: List<String>.from(m['tags'] as List? ?? const []),
    viewCount: m['viewCount'] ?? 0,
    likeCount: m['likeCount'] ?? 0,
    commentCount: m['commentCount'] ?? 0,
    favoriteCount: m['favoriteCount'] ?? 0,
    isLiked: m['isLiked'] ?? false,
  );
  Map<String, dynamic> toJson() => {
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

class FollowReq {
  final Object targetUserId;
  FollowReq({required this.targetUserId});
  factory FollowReq.fromJson(Map<String, dynamic> m) =>
      FollowReq(targetUserId: m['targetUserId'] ?? 0);
  Map<String, dynamic> toJson() => {'targetUserId': targetUserId};
}

class FollowResp {
  FollowResp();
  factory FollowResp.fromJson(Map<String, dynamic> m) => FollowResp();
  Map<String, dynamic> toJson() => {};
}

class GetAdAssetReq {
  final Object assetId;
  GetAdAssetReq({required this.assetId});
  factory GetAdAssetReq.fromJson(Map<String, dynamic> m) =>
      GetAdAssetReq(assetId: m['assetId'] ?? 0);
  Map<String, dynamic> toJson() => {'assetId': assetId};
}

class GetAdReq {
  final Object adId;
  GetAdReq({required this.adId});
  factory GetAdReq.fromJson(Map<String, dynamic> m) =>
      GetAdReq(adId: m['adId'] ?? 0);
  Map<String, dynamic> toJson() => {'adId': adId};
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
  factory GetAgentConsentResp.fromJson(Map<String, dynamic> m) =>
      GetAgentConsentResp(
        granted: m['granted'] ?? false,
        grantedAt: m['grantedAt'] ?? 0,
        revokedAt: m['revokedAt'] ?? 0,
        consentVersion: m['consentVersion'] ?? 0,
        currentVersion: m['currentVersion'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'granted': granted,
    'grantedAt': grantedAt,
    'revokedAt': revokedAt,
    'consentVersion': consentVersion,
    'currentVersion': currentVersion,
  };
}

class GetAssistantThreadResp {
  final AssistantThread thread;
  GetAssistantThreadResp({required this.thread});
  factory GetAssistantThreadResp.fromJson(Map<String, dynamic> m) =>
      GetAssistantThreadResp(
        thread: AssistantThread.fromJson(
          Map<String, dynamic>.from(m['thread'] as Map? ?? const {}),
        ),
      );
  Map<String, dynamic> toJson() => {'thread': thread.toJson()};
}

class GetCommentListReq {
  final Object postId;
  final num page;
  final num pageSize;
  final num sortBy;
  GetCommentListReq({
    required this.postId,
    required this.page,
    required this.pageSize,
    required this.sortBy,
  });
  factory GetCommentListReq.fromJson(Map<String, dynamic> m) =>
      GetCommentListReq(
        postId: m['postId'] ?? 0,
        page: m['page'] ?? 0,
        pageSize: m['pageSize'] ?? 0,
        sortBy: m['sortBy'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'postId': postId,
    'page': page,
    'pageSize': pageSize,
    'sortBy': sortBy,
  };
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
  factory GetCommentListResp.fromJson(Map<String, dynamic> m) =>
      GetCommentListResp(
        list: ((m['list'] ?? []) as List)
            .map(
              (i) => CommentItem.fromJson(Map<String, dynamic>.from(i as Map)),
            )
            .toList(),
        total: m['total'] ?? 0,
        page: m['page'] ?? 0,
        pageSize: m['pageSize'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'list': list.map((i) => i.toJson()).toList(),
    'total': total,
    'page': page,
    'pageSize': pageSize,
  };
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
  factory GetCommentRepliesReq.fromJson(Map<String, dynamic> m) =>
      GetCommentRepliesReq(
        commentId: m['commentId'] ?? 0,
        page: m['page'] ?? 0,
        pageSize: m['pageSize'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'commentId': commentId,
    'page': page,
    'pageSize': pageSize,
  };
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
  factory GetCommentRepliesResp.fromJson(Map<String, dynamic> m) =>
      GetCommentRepliesResp(
        list: ((m['list'] ?? []) as List)
            .map(
              (i) => CommentItem.fromJson(Map<String, dynamic>.from(i as Map)),
            )
            .toList(),
        total: m['total'] ?? 0,
        page: m['page'] ?? 0,
        pageSize: m['pageSize'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'list': list.map((i) => i.toJson()).toList(),
    'total': total,
    'page': page,
    'pageSize': pageSize,
  };
}

class GetConversationsReq {
  final num page;
  final num pageSize;
  GetConversationsReq({required this.page, required this.pageSize});
  factory GetConversationsReq.fromJson(Map<String, dynamic> m) =>
      GetConversationsReq(page: m['page'] ?? 0, pageSize: m['pageSize'] ?? 0);
  Map<String, dynamic> toJson() => {'page': page, 'pageSize': pageSize};
}

class GetConversationsResp {
  final List<ConversationItem> conversations;
  final num total;
  GetConversationsResp({required this.conversations, required this.total});
  factory GetConversationsResp.fromJson(Map<String, dynamic> m) =>
      GetConversationsResp(
        conversations: ((m['conversations'] ?? []) as List)
            .map(
              (i) => ConversationItem.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
        total: m['total'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'conversations': conversations.map((i) => i.toJson()).toList(),
    'total': total,
  };
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
  factory GetFollowFeedReq.fromJson(Map<String, dynamic> m) => GetFollowFeedReq(
    cursorCreatedAt: m['cursorCreatedAt'] ?? 0,
    cursorPostId: m['cursorPostId'] ?? 0,
    pageSize: m['pageSize'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'cursorCreatedAt': cursorCreatedAt,
    'cursorPostId': cursorPostId,
    'pageSize': pageSize,
  };
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
  factory GetFollowFeedResp.fromJson(Map<String, dynamic> m) =>
      GetFollowFeedResp(
        items: ((m['items'] ?? []) as List)
            .map((i) => FeedItem.fromJson(Map<String, dynamic>.from(i as Map)))
            .toList(),
        hasMore: m['hasMore'] ?? false,
        nextCursorCreatedAt: m['nextCursorCreatedAt'] ?? 0,
        nextCursorPostId: m['nextCursorPostId'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
    'hasMore': hasMore,
    'nextCursorCreatedAt': nextCursorCreatedAt,
    'nextCursorPostId': nextCursorPostId,
  };
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
  factory GetMessagesReq.fromJson(Map<String, dynamic> m) => GetMessagesReq(
    conversationId: m['id'] ?? 0,
    lastId: m['lastId'] ?? 0,
    pageSize: m['pageSize'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'id': conversationId,
    'lastId': lastId,
    'pageSize': pageSize,
  };
}

class GetMessagesResp {
  final List<MessageItem> messages;
  final bool hasMore;
  GetMessagesResp({required this.messages, required this.hasMore});
  factory GetMessagesResp.fromJson(Map<String, dynamic> m) => GetMessagesResp(
    messages: ((m['messages'] ?? []) as List)
        .map((i) => MessageItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList(),
    hasMore: m['hasMore'] ?? false,
  );
  Map<String, dynamic> toJson() => {
    'messages': messages.map((i) => i.toJson()).toList(),
    'hasMore': hasMore,
  };
}

class GetMyAdvertiserReq {
  GetMyAdvertiserReq();
  factory GetMyAdvertiserReq.fromJson(Map<String, dynamic> m) =>
      GetMyAdvertiserReq();
  Map<String, dynamic> toJson() => {};
}

class GetPersonalizationPreferenceResp {
  final bool enabled;
  final num optedOutAt;
  GetPersonalizationPreferenceResp({
    required this.enabled,
    required this.optedOutAt,
  });
  factory GetPersonalizationPreferenceResp.fromJson(Map<String, dynamic> m) =>
      GetPersonalizationPreferenceResp(
        enabled: m['enabled'] ?? false,
        optedOutAt: m['optedOutAt'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'optedOutAt': optedOutAt,
  };
}

class GetPostListReq {
  final num pageSize;
  final num sortBy;
  final String cursor;
  GetPostListReq({
    required this.pageSize,
    required this.sortBy,
    required this.cursor,
  });
  factory GetPostListReq.fromJson(Map<String, dynamic> m) => GetPostListReq(
    pageSize: m['pageSize'] ?? 0,
    sortBy: m['sortBy'] ?? 0,
    cursor: m['cursor']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'pageSize': pageSize,
    'sortBy': sortBy,
    'cursor': cursor,
  };
}

class GetPostListResp {
  final List<PostItem> list;
  final String nextCursor;
  GetPostListResp({required this.list, required this.nextCursor});
  factory GetPostListResp.fromJson(Map<String, dynamic> m) => GetPostListResp(
    list: ((m['list'] ?? []) as List)
        .map((i) => PostItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList(),
    nextCursor: m['nextCursor']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'list': list.map((i) => i.toJson()).toList(),
    'nextCursor': nextCursor,
  };
}

class GetPostReq {
  final Object postId;
  GetPostReq({required this.postId});
  factory GetPostReq.fromJson(Map<String, dynamic> m) =>
      GetPostReq(postId: m['postId'] ?? 0);
  Map<String, dynamic> toJson() => {'postId': postId};
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
  final List<Object> mediaIds;
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
    required this.mediaIds,
  });
  factory GetPostResp.fromJson(Map<String, dynamic> m) => GetPostResp(
    id: m['id'] ?? 0,
    authorId: m['authorId'] ?? 0,
    authorName: m['authorName']?.toString() ?? "",
    authorAvatar: m['authorAvatar']?.toString() ?? "",
    title: m['title']?.toString() ?? "",
    content: m['content']?.toString() ?? "",
    images: List<String>.from(m['images'] as List? ?? const []),
    tags: List<String>.from(m['tags'] as List? ?? const []),
    status: m['status'] ?? 0,
    viewCount: m['viewCount'] ?? 0,
    likeCount: m['likeCount'] ?? 0,
    commentCount: m['commentCount'] ?? 0,
    favoriteCount: m['favoriteCount'] ?? 0,
    isLiked: m['isLiked'] ?? false,
    isFavorited: m['isFavorited'] ?? false,
    revision: m['revision'] ?? 0,
    createdAt: m['createdAt'] ?? 0,
    mediaIds: List<Object>.from(m['mediaIds'] as List? ?? const []),
  );
  Map<String, dynamic> toJson() => {
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
    'mediaIds': mediaIds,
  };
}

class GetRecommendFeedReq {
  final String anonymousId;
  final String scene;
  final String requestId;
  final String sessionId;
  final String cursor;
  final num pageSize;
  final String experimentId;
  final num adSlots;
  final String market;
  GetRecommendFeedReq({
    required this.anonymousId,
    required this.scene,
    required this.requestId,
    required this.sessionId,
    required this.cursor,
    required this.pageSize,
    required this.experimentId,
    required this.adSlots,
    required this.market,
  });
  factory GetRecommendFeedReq.fromJson(Map<String, dynamic> m) =>
      GetRecommendFeedReq(
        anonymousId: m['anonymousId']?.toString() ?? "",
        scene: m['scene']?.toString() ?? "",
        requestId: m['requestId']?.toString() ?? "",
        sessionId: m['sessionId']?.toString() ?? "",
        cursor: m['cursor']?.toString() ?? "",
        pageSize: m['pageSize'] ?? 0,
        experimentId: m['experimentId']?.toString() ?? "",
        adSlots: m['adSlots'] ?? 0,
        market: m['market']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'anonymousId': anonymousId,
    'scene': scene,
    'requestId': requestId,
    'sessionId': sessionId,
    'cursor': cursor,
    'pageSize': pageSize,
    'experimentId': experimentId,
    'adSlots': adSlots,
    'market': market,
  };
}

class GetRecommendFeedResp {
  final List<RecommendFeedItem> items;
  final String nextCursor;
  final bool hasMore;
  final String requestId;
  final List<SponsoredSlotItem>? sponsored;
  GetRecommendFeedResp({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.requestId,
    this.sponsored,
  });
  factory GetRecommendFeedResp.fromJson(Map<String, dynamic> m) =>
      GetRecommendFeedResp(
        items: ((m['items'] ?? []) as List)
            .map(
              (i) => RecommendFeedItem.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
        nextCursor: m['nextCursor']?.toString() ?? "",
        hasMore: m['hasMore'] ?? false,
        requestId: m['requestId']?.toString() ?? "",
        sponsored: m['sponsored'] == null
            ? null
            : ((m['sponsored'] ?? []) as List)
                  .map(
                    (i) => SponsoredSlotItem.fromJson(
                      Map<String, dynamic>.from(i as Map),
                    ),
                  )
                  .toList(),
      );
  Map<String, dynamic> toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
    'nextCursor': nextCursor,
    'hasMore': hasMore,
    'requestId': requestId,
    if (sponsored != null)
      'sponsored': sponsored?.map((i) => i.toJson()).toList(),
  };
}

class GetReviewEvidenceMediaReq {
  final Object taskId;
  final Object mediaId;
  GetReviewEvidenceMediaReq({required this.taskId, required this.mediaId});
  factory GetReviewEvidenceMediaReq.fromJson(Map<String, dynamic> m) =>
      GetReviewEvidenceMediaReq(
        taskId: m['taskId'] ?? 0,
        mediaId: m['mediaId'] ?? 0,
      );
  Map<String, dynamic> toJson() => {'taskId': taskId, 'mediaId': mediaId};
}

class GetReviewQueueReq {
  GetReviewQueueReq();
  factory GetReviewQueueReq.fromJson(Map<String, dynamic> m) =>
      GetReviewQueueReq();
  Map<String, dynamic> toJson() => {};
}

class GetReviewTaskReq {
  final Object taskId;
  GetReviewTaskReq({required this.taskId});
  factory GetReviewTaskReq.fromJson(Map<String, dynamic> m) =>
      GetReviewTaskReq(taskId: m['taskId'] ?? 0);
  Map<String, dynamic> toJson() => {'taskId': taskId};
}

class GetReviewerProfileReq {
  GetReviewerProfileReq();
  factory GetReviewerProfileReq.fromJson(Map<String, dynamic> m) =>
      GetReviewerProfileReq();
  Map<String, dynamic> toJson() => {};
}

class GetUnreadSummaryResp {
  final num messageUnread;
  final num notificationUnread;
  GetUnreadSummaryResp({
    required this.messageUnread,
    required this.notificationUnread,
  });
  factory GetUnreadSummaryResp.fromJson(Map<String, dynamic> m) =>
      GetUnreadSummaryResp(
        messageUnread: m['messageUnread'] ?? 0,
        notificationUnread: m['notificationUnread'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'messageUnread': messageUnread,
    'notificationUnread': notificationUnread,
  };
}

class GetUserFavoritesReq {
  final Object userId;
  final num page;
  final num pageSize;
  final String cursor;
  GetUserFavoritesReq({
    required this.userId,
    required this.page,
    required this.pageSize,
    required this.cursor,
  });
  factory GetUserFavoritesReq.fromJson(Map<String, dynamic> m) =>
      GetUserFavoritesReq(
        userId: m['userId'] ?? 0,
        page: m['page'] ?? 0,
        pageSize: m['pageSize'] ?? 0,
        cursor: m['cursor']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'page': page,
    'pageSize': pageSize,
    'cursor': cursor,
  };
}

class GetUserPostsReq {
  final Object userId;
  final num pageSize;
  final num sortBy;
  final String cursor;
  GetUserPostsReq({
    required this.userId,
    required this.pageSize,
    required this.sortBy,
    required this.cursor,
  });
  factory GetUserPostsReq.fromJson(Map<String, dynamic> m) => GetUserPostsReq(
    userId: m['userId'] ?? 0,
    pageSize: m['pageSize'] ?? 0,
    sortBy: m['sortBy'] ?? 0,
    cursor: m['cursor']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'pageSize': pageSize,
    'sortBy': sortBy,
    'cursor': cursor,
  };
}

class GetUserReq {
  final Object userId;
  GetUserReq({required this.userId});
  factory GetUserReq.fromJson(Map<String, dynamic> m) =>
      GetUserReq(userId: m['userId'] ?? 0);
  Map<String, dynamic> toJson() => {'userId': userId};
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
  final bool isFollowing;
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
    required this.isFollowing,
  });
  factory GetUserResp.fromJson(Map<String, dynamic> m) => GetUserResp(
    id: m['id'] ?? 0,
    username: m['username']?.toString() ?? "",
    nickname: m['nickname']?.toString() ?? "",
    avatarUrl: m['avatarUrl']?.toString() ?? "",
    bio: m['bio']?.toString() ?? "",
    level: m['level'] ?? 0,
    followerCount: m['followerCount'] ?? 0,
    followingCount: m['followingCount'] ?? 0,
    postCount: m['postCount'] ?? 0,
    favoritesVisible: m['favoritesVisible'] ?? false,
    isFollowing: m['isFollowing'] ?? false,
  );
  Map<String, dynamic> toJson() => {
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
    'isFollowing': isFollowing,
  };
}

class HealthReadyResp {
  final String status;
  final Map<String, String> dependencies;
  HealthReadyResp({required this.status, required this.dependencies});
  factory HealthReadyResp.fromJson(Map<String, dynamic> m) => HealthReadyResp(
    status: m['status']?.toString() ?? "",
    dependencies: Map<String, String>.from(
      m['dependencies'] as Map? ?? const {},
    ),
  );
  Map<String, dynamic> toJson() => {
    'status': status,
    'dependencies': dependencies,
  };
}

class HealthReq {
  HealthReq();
  factory HealthReq.fromJson(Map<String, dynamic> m) => HealthReq();
  Map<String, dynamic> toJson() => {};
}

class HealthResp {
  final String status;
  HealthResp({required this.status});
  factory HealthResp.fromJson(Map<String, dynamic> m) =>
      HealthResp(status: m['status']?.toString() ?? "");
  Map<String, dynamic> toJson() => {'status': status};
}

class HideAdReq {
  final Object adId;
  final String sessionId;
  HideAdReq({required this.adId, required this.sessionId});
  factory HideAdReq.fromJson(Map<String, dynamic> m) => HideAdReq(
    adId: m['adId'] ?? 0,
    sessionId: m['sessionId']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {'adId': adId, 'sessionId': sessionId};
}

class LikeReq {
  final Object targetId;
  final num targetType;
  LikeReq({required this.targetId, required this.targetType});
  factory LikeReq.fromJson(Map<String, dynamic> m) =>
      LikeReq(targetId: m['targetId'] ?? 0, targetType: m['targetType'] ?? 0);
  Map<String, dynamic> toJson() => {
    'targetId': targetId,
    'targetType': targetType,
  };
}

class LikeResp {
  LikeResp();
  factory LikeResp.fromJson(Map<String, dynamic> m) => LikeResp();
  Map<String, dynamic> toJson() => {};
}

class ListAdPoliciesReq {
  ListAdPoliciesReq();
  factory ListAdPoliciesReq.fromJson(Map<String, dynamic> m) =>
      ListAdPoliciesReq();
  Map<String, dynamic> toJson() => {};
}

class ListAdPoliciesResp {
  final String policyVersion;
  final List<AdPolicyCodeItem> codes;
  final List<String> markets;
  final List<String> industries;
  final bool demo;
  ListAdPoliciesResp({
    required this.policyVersion,
    required this.codes,
    required this.markets,
    required this.industries,
    required this.demo,
  });
  factory ListAdPoliciesResp.fromJson(Map<String, dynamic> m) =>
      ListAdPoliciesResp(
        policyVersion: m['policyVersion']?.toString() ?? "",
        codes: ((m['codes'] ?? []) as List)
            .map(
              (i) => AdPolicyCodeItem.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
        markets: List<String>.from(m['markets'] as List? ?? const []),
        industries: List<String>.from(m['industries'] as List? ?? const []),
        demo: m['demo'] ?? false,
      );
  Map<String, dynamic> toJson() => {
    'policyVersion': policyVersion,
    'codes': codes.map((i) => i.toJson()).toList(),
    'markets': markets,
    'industries': industries,
    'demo': demo,
  };
}

class ListAdsReq {
  final String cursor;
  final num pageSize;
  ListAdsReq({required this.cursor, required this.pageSize});
  factory ListAdsReq.fromJson(Map<String, dynamic> m) => ListAdsReq(
    cursor: m['cursor']?.toString() ?? "",
    pageSize: m['pageSize'] ?? 0,
  );
  Map<String, dynamic> toJson() => {'cursor': cursor, 'pageSize': pageSize};
}

class ListAdsResp {
  final List<AdItem> ads;
  final String nextCursor;
  final bool hasMore;
  ListAdsResp({
    required this.ads,
    required this.nextCursor,
    required this.hasMore,
  });
  factory ListAdsResp.fromJson(Map<String, dynamic> m) => ListAdsResp(
    ads: ((m['ads'] ?? []) as List)
        .map((i) => AdItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList(),
    nextCursor: m['nextCursor']?.toString() ?? "",
    hasMore: m['hasMore'] ?? false,
  );
  Map<String, dynamic> toJson() => {
    'ads': ads.map((i) => i.toJson()).toList(),
    'nextCursor': nextCursor,
    'hasMore': hasMore,
  };
}

class ListAssistantMemoryReq {
  final String target;
  ListAssistantMemoryReq({required this.target});
  factory ListAssistantMemoryReq.fromJson(Map<String, dynamic> m) =>
      ListAssistantMemoryReq(target: m['target']?.toString() ?? "");
  Map<String, dynamic> toJson() => {'target': target};
}

class ListAssistantMemoryResp {
  final List<AssistantMemoryEntry> items;
  final List<AssistantMemoryCapacity> capacities;
  ListAssistantMemoryResp({required this.items, required this.capacities});
  factory ListAssistantMemoryResp.fromJson(Map<String, dynamic> m) =>
      ListAssistantMemoryResp(
        items: ((m['items'] ?? []) as List)
            .map(
              (i) => AssistantMemoryEntry.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
        capacities: ((m['capacities'] ?? []) as List)
            .map(
              (i) => AssistantMemoryCapacity.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
    'capacities': capacities.map((i) => i.toJson()).toList(),
  };
}

class ListAssistantMessagesReq {
  final Object sessionId;
  final Object afterId;
  final Object beforeId;
  final num limit;
  ListAssistantMessagesReq({
    required this.sessionId,
    required this.afterId,
    required this.beforeId,
    required this.limit,
  });
  factory ListAssistantMessagesReq.fromJson(Map<String, dynamic> m) =>
      ListAssistantMessagesReq(
        sessionId: m['sessionId'] ?? 0,
        afterId: m['afterId'] ?? 0,
        beforeId: m['beforeId'] ?? 0,
        limit: m['limit'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'afterId': afterId,
    'beforeId': beforeId,
    'limit': limit,
  };
}

class ListAssistantMessagesResp {
  final List<AssistantMessage> messages;
  final bool hasMore;
  final Object nextBeforeId;
  ListAssistantMessagesResp({
    required this.messages,
    required this.hasMore,
    required this.nextBeforeId,
  });
  factory ListAssistantMessagesResp.fromJson(Map<String, dynamic> m) =>
      ListAssistantMessagesResp(
        messages: ((m['messages'] ?? []) as List)
            .map(
              (i) => AssistantMessage.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
        hasMore: m['hasMore'] ?? false,
        nextBeforeId: m['nextBeforeId'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'messages': messages.map((i) => i.toJson()).toList(),
    'hasMore': hasMore,
    'nextBeforeId': nextBeforeId,
  };
}

class ListAssistantWatchReq {
  ListAssistantWatchReq();
  factory ListAssistantWatchReq.fromJson(Map<String, dynamic> m) =>
      ListAssistantWatchReq();
  Map<String, dynamic> toJson() => {};
}

class ListAssistantWatchResp {
  final List<AssistantWatchTask> tasks;
  ListAssistantWatchResp({required this.tasks});
  factory ListAssistantWatchResp.fromJson(Map<String, dynamic> m) =>
      ListAssistantWatchResp(
        tasks: ((m['tasks'] ?? []) as List)
            .map(
              (i) => AssistantWatchTask.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'tasks': tasks.map((i) => i.toJson()).toList(),
  };
}

class ListReviewSeedsReq {
  final String status;
  final num limit;
  ListReviewSeedsReq({required this.status, required this.limit});
  factory ListReviewSeedsReq.fromJson(Map<String, dynamic> m) =>
      ListReviewSeedsReq(
        status: m['status']?.toString() ?? "",
        limit: m['limit'] ?? 0,
      );
  Map<String, dynamic> toJson() => {'status': status, 'limit': limit};
}

class ListReviewSeedsResp {
  final List<ReviewSeedItem> seeds;
  ListReviewSeedsResp({required this.seeds});
  factory ListReviewSeedsResp.fromJson(Map<String, dynamic> m) =>
      ListReviewSeedsResp(
        seeds: ((m['seeds'] ?? []) as List)
            .map(
              (i) =>
                  ReviewSeedItem.fromJson(Map<String, dynamic>.from(i as Map)),
            )
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'seeds': seeds.map((i) => i.toJson()).toList(),
  };
}

class LoginReq {
  final String username;
  final String password;
  final String phone;
  final String verifyCode;
  final num loginType;
  LoginReq({
    required this.username,
    required this.password,
    required this.phone,
    required this.verifyCode,
    required this.loginType,
  });
  factory LoginReq.fromJson(Map<String, dynamic> m) => LoginReq(
    username: m['username']?.toString() ?? "",
    password: m['password']?.toString() ?? "",
    phone: m['phone']?.toString() ?? "",
    verifyCode: m['verifyCode']?.toString() ?? "",
    loginType: m['loginType'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'phone': phone,
    'verifyCode': verifyCode,
    'loginType': loginType,
  };
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
  factory LoginResp.fromJson(Map<String, dynamic> m) => LoginResp(
    userId: m['userId'] ?? 0,
    token: m['token']?.toString() ?? "",
    refreshToken: m['refreshToken']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'token': token,
    'refreshToken': refreshToken,
  };
}

class MarkAssistantThreadReadResp {
  final num unreadCount;
  MarkAssistantThreadReadResp({required this.unreadCount});
  factory MarkAssistantThreadReadResp.fromJson(Map<String, dynamic> m) =>
      MarkAssistantThreadReadResp(unreadCount: m['unreadCount'] ?? 0);
  Map<String, dynamic> toJson() => {'unreadCount': unreadCount};
}

class MarkConversationReadReq {
  final Object conversationId;
  MarkConversationReadReq({required this.conversationId});
  factory MarkConversationReadReq.fromJson(Map<String, dynamic> m) =>
      MarkConversationReadReq(conversationId: m['id'] ?? 0);
  Map<String, dynamic> toJson() => {'id': conversationId};
}

class MarkConversationReadResp {
  MarkConversationReadResp();
  factory MarkConversationReadResp.fromJson(Map<String, dynamic> m) =>
      MarkConversationReadResp();
  Map<String, dynamic> toJson() => {};
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
  final Object mediaId;
  MessageItem({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.msgType,
    required this.status,
    required this.createdAt,
    required this.mediaId,
  });
  factory MessageItem.fromJson(Map<String, dynamic> m) => MessageItem(
    id: m['id'] ?? 0,
    conversationId: m['conversationId'] ?? 0,
    senderId: m['senderId'] ?? 0,
    receiverId: m['receiverId'] ?? 0,
    content: m['content']?.toString() ?? "",
    msgType: m['msgType'] ?? 0,
    status: m['status'] ?? 0,
    createdAt: m['createdAt'] ?? 0,
    mediaId: m['mediaId'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'receiverId': receiverId,
    'content': content,
    'msgType': msgType,
    'status': status,
    'createdAt': createdAt,
    'mediaId': mediaId,
  };
}

class PostAssistantMessageReq {
  final String message;
  final String requestId;
  final List<AssistantAttachment> attachments;
  final Object contextPostId;
  final num clientProtocolVersion;
  final AssistantQuestionContext? questionContext;
  PostAssistantMessageReq({
    required this.message,
    required this.requestId,
    required this.attachments,
    required this.contextPostId,
    required this.clientProtocolVersion,
    required this.questionContext,
  });
  factory PostAssistantMessageReq.fromJson(
    Map<String, dynamic> m,
  ) => PostAssistantMessageReq(
    message: m['message']?.toString() ?? "",
    requestId: m['requestId']?.toString() ?? "",
    attachments: ((m['attachments'] ?? []) as List)
        .map(
          (i) =>
              AssistantAttachment.fromJson(Map<String, dynamic>.from(i as Map)),
        )
        .toList(),
    contextPostId: m['contextPostId'] ?? 0,
    clientProtocolVersion: m['clientProtocolVersion'] ?? 0,
    questionContext: m['questionContext'] == null
        ? null
        : AssistantQuestionContext.fromJson(
            Map<String, dynamic>.from(m['questionContext'] as Map? ?? const {}),
          ),
  );
  Map<String, dynamic> toJson() => {
    'message': message,
    'requestId': requestId,
    'attachments': attachments.map((i) => i.toJson()).toList(),
    'contextPostId': contextPostId,
    'clientProtocolVersion': clientProtocolVersion,
    'questionContext': questionContext?.toJson(),
  };
}

class PostAssistantMessageResp {
  final Object messageId;
  final Object sessionId;
  final Object runId;
  final String disposition;
  PostAssistantMessageResp({
    required this.messageId,
    required this.sessionId,
    required this.runId,
    required this.disposition,
  });
  factory PostAssistantMessageResp.fromJson(Map<String, dynamic> m) =>
      PostAssistantMessageResp(
        messageId: m['messageId'] ?? 0,
        sessionId: m['sessionId'] ?? 0,
        runId: m['runId'] ?? 0,
        disposition: m['disposition']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'sessionId': sessionId,
    'runId': runId,
    'disposition': disposition,
  };
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
  final List<Object> mediaIds;
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
    this.mediaIds = const [],
  });
  factory PostItem.fromJson(Map<String, dynamic> m) => PostItem(
    id: m['id'] ?? 0,
    authorId: m['authorId'] ?? 0,
    authorName: m['authorName']?.toString() ?? "",
    authorAvatar: m['authorAvatar']?.toString() ?? "",
    title: m['title']?.toString() ?? "",
    content: m['content']?.toString() ?? "",
    images: List<String>.from(m['images'] as List? ?? const []),
    tags: List<String>.from(m['tags'] as List? ?? const []),
    status: m['status'] ?? 0,
    viewCount: m['viewCount'] ?? 0,
    likeCount: m['likeCount'] ?? 0,
    commentCount: m['commentCount'] ?? 0,
    favoriteCount: m['favoriteCount'] ?? 0,
    isLiked: m['isLiked'] ?? false,
    isFavorited: m['isFavorited'] ?? false,
    revision: m['revision'] ?? 0,
    createdAt: m['createdAt'] ?? 0,
    mediaIds: List<Object>.from(m['mediaIds'] as List? ?? const []),
  );
  Map<String, dynamic> toJson() => {
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
    'mediaIds': mediaIds,
  };
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
  factory RecommendFeedItem.fromJson(Map<String, dynamic> m) =>
      RecommendFeedItem(
        postId: m['postId'] ?? 0,
        authorId: m['authorId'] ?? 0,
        authorName: m['authorName']?.toString() ?? "",
        authorAvatar: m['authorAvatar']?.toString() ?? "",
        createdAt: m['createdAt'] ?? 0,
        feedType: m['feedType'] ?? 0,
        title: m['title']?.toString() ?? "",
        content: m['content']?.toString() ?? "",
        images: List<String>.from(m['images'] as List? ?? const []),
        tags: List<String>.from(m['tags'] as List? ?? const []),
        viewCount: m['viewCount'] ?? 0,
        likeCount: m['likeCount'] ?? 0,
        commentCount: m['commentCount'] ?? 0,
        favoriteCount: m['favoriteCount'] ?? 0,
        isLiked: m['isLiked'] ?? false,
        score: m['score'] ?? 0,
        reason: m['reason']?.toString() ?? "",
        recallSource: m['recallSource']?.toString() ?? "",
        modelVersion: m['modelVersion']?.toString() ?? "",
        experimentId: m['experimentId']?.toString() ?? "",
        position: m['position'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
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

class RecordBehaviorEventsReq {
  final String anonymousId;
  final String sessionId;
  final List<BehaviorEvent> events;
  RecordBehaviorEventsReq({
    required this.anonymousId,
    required this.sessionId,
    required this.events,
  });
  factory RecordBehaviorEventsReq.fromJson(Map<String, dynamic> m) =>
      RecordBehaviorEventsReq(
        anonymousId: m['anonymousId']?.toString() ?? "",
        sessionId: m['sessionId']?.toString() ?? "",
        events: ((m['events'] ?? []) as List)
            .map(
              (i) =>
                  BehaviorEvent.fromJson(Map<String, dynamic>.from(i as Map)),
            )
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'anonymousId': anonymousId,
    'sessionId': sessionId,
    'events': events.map((i) => i.toJson()).toList(),
  };
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
  factory RecordBehaviorEventsResp.fromJson(Map<String, dynamic> m) =>
      RecordBehaviorEventsResp(
        results: ((m['results'] ?? []) as List)
            .map(
              (i) => BehaviorEventResult.fromJson(
                Map<String, dynamic>.from(i as Map),
              ),
            )
            .toList(),
        acceptedCount: m['acceptedCount'] ?? 0,
        rejectedCount: m['rejectedCount'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'results': results.map((i) => i.toJson()).toList(),
    'acceptedCount': acceptedCount,
    'rejectedCount': rejectedCount,
  };
}

class RefreshTokenReq {
  final String refreshToken;
  RefreshTokenReq({required this.refreshToken});
  factory RefreshTokenReq.fromJson(Map<String, dynamic> m) =>
      RefreshTokenReq(refreshToken: m['refreshToken']?.toString() ?? "");
  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};
}

class RefreshTokenResp {
  final String token;
  final String refreshToken;
  RefreshTokenResp({required this.token, required this.refreshToken});
  factory RefreshTokenResp.fromJson(Map<String, dynamic> m) => RefreshTokenResp(
    token: m['token']?.toString() ?? "",
    refreshToken: m['refreshToken']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'token': token,
    'refreshToken': refreshToken,
  };
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
  factory RegisterReq.fromJson(Map<String, dynamic> m) => RegisterReq(
    username: m['username']?.toString() ?? "",
    password: m['password']?.toString() ?? "",
    phone: m['phone']?.toString() ?? "",
    verifyCode: m['verifyCode']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'phone': phone,
    'verifyCode': verifyCode,
  };
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
  factory RegisterResp.fromJson(Map<String, dynamic> m) => RegisterResp(
    userId: m['userId'] ?? 0,
    token: m['token']?.toString() ?? "",
    refreshToken: m['refreshToken']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'token': token,
    'refreshToken': refreshToken,
  };
}

class RemoveAssistantMemoryReq {
  final Object id;
  final num version;
  final String requestId;
  RemoveAssistantMemoryReq({
    required this.id,
    required this.version,
    required this.requestId,
  });
  factory RemoveAssistantMemoryReq.fromJson(Map<String, dynamic> m) =>
      RemoveAssistantMemoryReq(
        id: m['id'] ?? 0,
        version: m['version'] ?? 0,
        requestId: m['requestId']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'requestId': requestId,
  };
}

class RemoveAssistantMemoryResp {
  final Object changeId;
  RemoveAssistantMemoryResp({required this.changeId});
  factory RemoveAssistantMemoryResp.fromJson(Map<String, dynamic> m) =>
      RemoveAssistantMemoryResp(changeId: m['changeId'] ?? 0);
  Map<String, dynamic> toJson() => {'changeId': changeId};
}

class ReplaceAssistantMemoryReq {
  final Object id;
  final String content;
  final num version;
  final String requestId;
  ReplaceAssistantMemoryReq({
    required this.id,
    required this.content,
    required this.version,
    required this.requestId,
  });
  factory ReplaceAssistantMemoryReq.fromJson(Map<String, dynamic> m) =>
      ReplaceAssistantMemoryReq(
        id: m['id'] ?? 0,
        content: m['content']?.toString() ?? "",
        version: m['version'] ?? 0,
        requestId: m['requestId']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'version': version,
    'requestId': requestId,
  };
}

class ReplaceAssistantMemoryResp {
  final AssistantMemoryEntry entry;
  final Object changeId;
  ReplaceAssistantMemoryResp({required this.entry, required this.changeId});
  factory ReplaceAssistantMemoryResp.fromJson(Map<String, dynamic> m) =>
      ReplaceAssistantMemoryResp(
        entry: AssistantMemoryEntry.fromJson(
          Map<String, dynamic>.from(m['entry'] as Map? ?? const {}),
        ),
        changeId: m['changeId'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'entry': entry.toJson(),
    'changeId': changeId,
  };
}

class ReviewActionResp {
  final bool ok;
  ReviewActionResp({required this.ok});
  factory ReviewActionResp.fromJson(Map<String, dynamic> m) =>
      ReviewActionResp(ok: m['ok'] ?? false);
  Map<String, dynamic> toJson() => {'ok': ok};
}

class ReviewDecisionItem {
  final Object decisionId;
  final String verdict;
  final List<String> policyCodes;
  final String policyVersion;
  final String source;
  final num decidedAtMs;
  ReviewDecisionItem({
    required this.decisionId,
    required this.verdict,
    required this.policyCodes,
    required this.policyVersion,
    required this.source,
    required this.decidedAtMs,
  });
  factory ReviewDecisionItem.fromJson(Map<String, dynamic> m) =>
      ReviewDecisionItem(
        decisionId: m['decisionId'] ?? 0,
        verdict: m['verdict']?.toString() ?? "",
        policyCodes: List<String>.from(m['policyCodes'] as List? ?? const []),
        policyVersion: m['policyVersion']?.toString() ?? "",
        source: m['source']?.toString() ?? "",
        decidedAtMs: m['decidedAtMs'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'decisionId': decisionId,
    'verdict': verdict,
    'policyCodes': policyCodes,
    'policyVersion': policyVersion,
    'source': source,
    'decidedAtMs': decidedAtMs,
  };
}

class ReviewDecisionResp {
  final Object decisionId;
  final String verdict;
  final List<String> policyCodes;
  final String policyVersion;
  ReviewDecisionResp({
    required this.decisionId,
    required this.verdict,
    required this.policyCodes,
    required this.policyVersion,
  });
  factory ReviewDecisionResp.fromJson(Map<String, dynamic> m) =>
      ReviewDecisionResp(
        decisionId: m['decisionId'] ?? 0,
        verdict: m['verdict']?.toString() ?? "",
        policyCodes: List<String>.from(m['policyCodes'] as List? ?? const []),
        policyVersion: m['policyVersion']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'decisionId': decisionId,
    'verdict': verdict,
    'policyCodes': policyCodes,
    'policyVersion': policyVersion,
  };
}

class ReviewLeaseReq {
  final Object taskId;
  final num leaseGeneration;
  ReviewLeaseReq({required this.taskId, required this.leaseGeneration});
  factory ReviewLeaseReq.fromJson(Map<String, dynamic> m) => ReviewLeaseReq(
    taskId: m['taskId'] ?? 0,
    leaseGeneration: m['leaseGeneration'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'leaseGeneration': leaseGeneration,
  };
}

class ReviewQueueBucket {
  final String purpose;
  final num pending;
  final num oldestAgeMs;
  ReviewQueueBucket({
    required this.purpose,
    required this.pending,
    required this.oldestAgeMs,
  });
  factory ReviewQueueBucket.fromJson(Map<String, dynamic> m) =>
      ReviewQueueBucket(
        purpose: m['purpose']?.toString() ?? "",
        pending: m['pending'] ?? 0,
        oldestAgeMs: m['oldestAgeMs'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'purpose': purpose,
    'pending': pending,
    'oldestAgeMs': oldestAgeMs,
  };
}

class ReviewQueueResp {
  final List<ReviewQueueBucket> buckets;
  final String policyVersion;
  ReviewQueueResp({required this.buckets, required this.policyVersion});
  factory ReviewQueueResp.fromJson(Map<String, dynamic> m) => ReviewQueueResp(
    buckets: ((m['buckets'] ?? []) as List)
        .map(
          (i) =>
              ReviewQueueBucket.fromJson(Map<String, dynamic>.from(i as Map)),
        )
        .toList(),
    policyVersion: m['policyVersion']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'buckets': buckets.map((i) => i.toJson()).toList(),
    'policyVersion': policyVersion,
  };
}

class ReviewSeedActionReq {
  final Object seedId;
  ReviewSeedActionReq({required this.seedId});
  factory ReviewSeedActionReq.fromJson(Map<String, dynamic> m) =>
      ReviewSeedActionReq(seedId: m['seedId'] ?? 0);
  Map<String, dynamic> toJson() => {'seedId': seedId};
}

class ReviewSeedItem {
  final Object seedId;
  final String issueCode;
  final String market;
  final String language;
  final String text;
  final String status;
  final Object nominatedBy;
  final Object confirmedBy;
  final Object sourceTaskId;
  final num updatedAtMs;
  ReviewSeedItem({
    required this.seedId,
    required this.issueCode,
    required this.market,
    required this.language,
    required this.text,
    required this.status,
    required this.nominatedBy,
    required this.confirmedBy,
    required this.sourceTaskId,
    required this.updatedAtMs,
  });
  factory ReviewSeedItem.fromJson(Map<String, dynamic> m) => ReviewSeedItem(
    seedId: m['seedId'] ?? 0,
    issueCode: m['issueCode']?.toString() ?? "",
    market: m['market']?.toString() ?? "",
    language: m['language']?.toString() ?? "",
    text: m['text']?.toString() ?? "",
    status: m['status']?.toString() ?? "",
    nominatedBy: m['nominatedBy'] ?? 0,
    confirmedBy: m['confirmedBy'] ?? 0,
    sourceTaskId: m['sourceTaskId'] ?? 0,
    updatedAtMs: m['updatedAtMs'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'seedId': seedId,
    'issueCode': issueCode,
    'market': market,
    'language': language,
    'text': text,
    'status': status,
    'nominatedBy': nominatedBy,
    'confirmedBy': confirmedBy,
    'sourceTaskId': sourceTaskId,
    'updatedAtMs': updatedAtMs,
  };
}

class ReviewSeedResp {
  final ReviewSeedItem seed;
  ReviewSeedResp({required this.seed});
  factory ReviewSeedResp.fromJson(Map<String, dynamic> m) => ReviewSeedResp(
    seed: ReviewSeedItem.fromJson(
      Map<String, dynamic>.from(m['seed'] as Map? ?? const {}),
    ),
  );
  Map<String, dynamic> toJson() => {'seed': seed.toJson()};
}

class ReviewStageItem {
  final String stage;
  final String componentVersion;
  final bool shadow;
  final String outcome;
  final String reason;
  final String outputJson;
  final num latencyMs;
  ReviewStageItem({
    required this.stage,
    required this.componentVersion,
    required this.shadow,
    required this.outcome,
    required this.reason,
    required this.outputJson,
    required this.latencyMs,
  });
  factory ReviewStageItem.fromJson(Map<String, dynamic> m) => ReviewStageItem(
    stage: m['stage']?.toString() ?? "",
    componentVersion: m['componentVersion']?.toString() ?? "",
    shadow: m['shadow'] ?? false,
    outcome: m['outcome']?.toString() ?? "",
    reason: m['reason']?.toString() ?? "",
    outputJson: m['outputJson']?.toString() ?? "",
    latencyMs: m['latencyMs'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'stage': stage,
    'componentVersion': componentVersion,
    'shadow': shadow,
    'outcome': outcome,
    'reason': reason,
    'outputJson': outputJson,
    'latencyMs': latencyMs,
  };
}

class ReviewTaskItem {
  final Object taskId;
  final String bizType;
  final Object objectId;
  final num objectRevision;
  final String purpose;
  final String status;
  final String market;
  final String language;
  final String industry;
  final num priority;
  final num deadlineMs;
  final num leaseGeneration;
  final num leaseUntilMs;
  final String snapshotJson;
  final List<ReviewStageItem> stages;
  final ReviewDecisionItem? originalDecision;
  final ReviewDecisionItem? decision;
  final num submittedAtMs;
  final String escalationReason;
  final String policyVersion;
  final num attempts;
  ReviewTaskItem({
    required this.taskId,
    required this.bizType,
    required this.objectId,
    required this.objectRevision,
    required this.purpose,
    required this.status,
    required this.market,
    required this.language,
    required this.industry,
    required this.priority,
    required this.deadlineMs,
    required this.leaseGeneration,
    required this.leaseUntilMs,
    required this.snapshotJson,
    required this.stages,
    required this.originalDecision,
    required this.decision,
    required this.submittedAtMs,
    required this.escalationReason,
    required this.policyVersion,
    required this.attempts,
  });
  factory ReviewTaskItem.fromJson(Map<String, dynamic> m) => ReviewTaskItem(
    taskId: m['taskId'] ?? 0,
    bizType: m['bizType']?.toString() ?? "",
    objectId: m['objectId'] ?? 0,
    objectRevision: m['objectRevision'] ?? 0,
    purpose: m['purpose']?.toString() ?? "",
    status: m['status']?.toString() ?? "",
    market: m['market']?.toString() ?? "",
    language: m['language']?.toString() ?? "",
    industry: m['industry']?.toString() ?? "",
    priority: m['priority'] ?? 0,
    deadlineMs: m['deadlineMs'] ?? 0,
    leaseGeneration: m['leaseGeneration'] ?? 0,
    leaseUntilMs: m['leaseUntilMs'] ?? 0,
    snapshotJson: m['snapshotJson']?.toString() ?? "",
    stages: ((m['stages'] ?? []) as List)
        .map(
          (i) => ReviewStageItem.fromJson(Map<String, dynamic>.from(i as Map)),
        )
        .toList(),
    originalDecision: m['originalDecision'] == null
        ? null
        : ReviewDecisionItem.fromJson(
            Map<String, dynamic>.from(
              m['originalDecision'] as Map? ?? const {},
            ),
          ),
    decision: m['decision'] == null
        ? null
        : ReviewDecisionItem.fromJson(
            Map<String, dynamic>.from(m['decision'] as Map? ?? const {}),
          ),
    submittedAtMs: m['submittedAtMs'] ?? 0,
    escalationReason: m['escalationReason']?.toString() ?? "",
    policyVersion: m['policyVersion']?.toString() ?? "",
    attempts: m['attempts'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'bizType': bizType,
    'objectId': objectId,
    'objectRevision': objectRevision,
    'purpose': purpose,
    'status': status,
    'market': market,
    'language': language,
    'industry': industry,
    'priority': priority,
    'deadlineMs': deadlineMs,
    'leaseGeneration': leaseGeneration,
    'leaseUntilMs': leaseUntilMs,
    'snapshotJson': snapshotJson,
    'stages': stages.map((i) => i.toJson()).toList(),
    'originalDecision': originalDecision?.toJson(),
    'decision': decision?.toJson(),
    'submittedAtMs': submittedAtMs,
    'escalationReason': escalationReason,
    'policyVersion': policyVersion,
    'attempts': attempts,
  };
}

class ReviewTaskResp {
  final bool found;
  final ReviewTaskItem? task;
  ReviewTaskResp({required this.found, required this.task});
  factory ReviewTaskResp.fromJson(Map<String, dynamic> m) => ReviewTaskResp(
    found: m['found'] ?? false,
    task: m['task'] == null
        ? null
        : ReviewTaskItem.fromJson(
            Map<String, dynamic>.from(m['task'] as Map? ?? const {}),
          ),
  );
  Map<String, dynamic> toJson() => {'found': found, 'task': task?.toJson()};
}

class ReviewerProfileResp {
  final bool active;
  final List<String> roles;
  final List<String> markets;
  final List<String> languages;
  ReviewerProfileResp({
    required this.active,
    required this.roles,
    required this.markets,
    required this.languages,
  });
  factory ReviewerProfileResp.fromJson(Map<String, dynamic> m) =>
      ReviewerProfileResp(
        active: m['active'] ?? false,
        roles: List<String>.from(m['roles'] as List? ?? const []),
        markets: List<String>.from(m['markets'] as List? ?? const []),
        languages: List<String>.from(m['languages'] as List? ?? const []),
      );
  Map<String, dynamic> toJson() => {
    'active': active,
    'roles': roles,
    'markets': markets,
    'languages': languages,
  };
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
  factory SearchPostItem.fromJson(Map<String, dynamic> m) => SearchPostItem(
    id: m['id'] ?? 0,
    title: m['title']?.toString() ?? "",
    contentHighlight: m['contentHighlight']?.toString() ?? "",
    authorId: m['authorId'] ?? 0,
    authorName: m['authorName']?.toString() ?? "",
    authorAvatar: m['authorAvatar']?.toString() ?? "",
    likeCount: m['likeCount'] ?? 0,
    commentCount: m['commentCount'] ?? 0,
    createdAt: m['createdAt'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
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

class SearchReq {
  final String keyword;
  final num page;
  final num pageSize;
  SearchReq({
    required this.keyword,
    required this.page,
    required this.pageSize,
  });
  factory SearchReq.fromJson(Map<String, dynamic> m) => SearchReq(
    keyword: m['keyword']?.toString() ?? "",
    page: m['page'] ?? 0,
    pageSize: m['pageSize'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'keyword': keyword,
    'page': page,
    'pageSize': pageSize,
  };
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
  factory SearchResp.fromJson(Map<String, dynamic> m) => SearchResp(
    posts: ((m['posts'] ?? []) as List)
        .map(
          (i) => SearchPostItem.fromJson(Map<String, dynamic>.from(i as Map)),
        )
        .toList(),
    users: ((m['users'] ?? []) as List)
        .map(
          (i) => SearchUserItem.fromJson(Map<String, dynamic>.from(i as Map)),
        )
        .toList(),
    tags: ((m['tags'] ?? []) as List)
        .map((i) => SearchTagItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList(),
    degraded: m['degraded'] ?? false,
    unavailableTypes: List<String>.from(
      m['unavailableTypes'] as List? ?? const [],
    ),
  );
  Map<String, dynamic> toJson() => {
    'posts': posts.map((i) => i.toJson()).toList(),
    'users': users.map((i) => i.toJson()).toList(),
    'tags': tags.map((i) => i.toJson()).toList(),
    'degraded': degraded,
    'unavailableTypes': unavailableTypes,
  };
}

class SearchTagItem {
  final String name;
  final num postCount;
  SearchTagItem({required this.name, required this.postCount});
  factory SearchTagItem.fromJson(Map<String, dynamic> m) => SearchTagItem(
    name: m['name']?.toString() ?? "",
    postCount: m['postCount'] ?? 0,
  );
  Map<String, dynamic> toJson() => {'name': name, 'postCount': postCount};
}

class SearchTagsReq {
  final String keyword;
  final num limit;
  SearchTagsReq({required this.keyword, required this.limit});
  factory SearchTagsReq.fromJson(Map<String, dynamic> m) => SearchTagsReq(
    keyword: m['keyword']?.toString() ?? "",
    limit: m['limit'] ?? 0,
  );
  Map<String, dynamic> toJson() => {'keyword': keyword, 'limit': limit};
}

class SearchTagsResp {
  final List<SearchTagItem> tags;
  SearchTagsResp({required this.tags});
  factory SearchTagsResp.fromJson(Map<String, dynamic> m) => SearchTagsResp(
    tags: ((m['tags'] ?? []) as List)
        .map((i) => SearchTagItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'tags': tags.map((i) => i.toJson()).toList(),
  };
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
  factory SearchUserItem.fromJson(Map<String, dynamic> m) => SearchUserItem(
    id: m['id'] ?? 0,
    username: m['username']?.toString() ?? "",
    nickname: m['nickname']?.toString() ?? "",
    avatarUrl: m['avatarUrl']?.toString() ?? "",
    bio: m['bio']?.toString() ?? "",
    followerCount: m['followerCount'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nickname': nickname,
    'avatarUrl': avatarUrl,
    'bio': bio,
    'followerCount': followerCount,
  };
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
  factory SearchUsersReq.fromJson(Map<String, dynamic> m) => SearchUsersReq(
    keyword: m['keyword']?.toString() ?? "",
    page: m['page'] ?? 0,
    pageSize: m['pageSize'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'keyword': keyword,
    'page': page,
    'pageSize': pageSize,
  };
}

class SearchUsersResp {
  final List<SearchUserItem> users;
  final num total;
  SearchUsersResp({required this.users, required this.total});
  factory SearchUsersResp.fromJson(Map<String, dynamic> m) => SearchUsersResp(
    users: ((m['users'] ?? []) as List)
        .map(
          (i) => SearchUserItem.fromJson(Map<String, dynamic>.from(i as Map)),
        )
        .toList(),
    total: m['total'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'users': users.map((i) => i.toJson()).toList(),
    'total': total,
  };
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
  factory SendMessageReq.fromJson(Map<String, dynamic> m) => SendMessageReq(
    receiverId: m['receiverId'] ?? 0,
    content: m['content']?.toString() ?? "",
    msgType: m['msgType'] ?? 0,
    idempotencyKey: m['idempotencyKey']?.toString() ?? "",
    mediaId: m['mediaId'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'receiverId': receiverId,
    'content': content,
    'msgType': msgType,
    'idempotencyKey': idempotencyKey,
    'mediaId': mediaId,
  };
}

class SendMessageResp {
  final Object messageId;
  SendMessageResp({required this.messageId});
  factory SendMessageResp.fromJson(Map<String, dynamic> m) =>
      SendMessageResp(messageId: m['messageId'] ?? 0);
  Map<String, dynamic> toJson() => {'messageId': messageId};
}

class SendVerifyCodeReq {
  final String phone;
  final num type;
  SendVerifyCodeReq({required this.phone, required this.type});
  factory SendVerifyCodeReq.fromJson(Map<String, dynamic> m) =>
      SendVerifyCodeReq(
        phone: m['phone']?.toString() ?? "",
        type: m['type'] ?? 0,
      );
  Map<String, dynamic> toJson() => {'phone': phone, 'type': type};
}

class SendVerifyCodeResp {
  SendVerifyCodeResp();
  factory SendVerifyCodeResp.fromJson(Map<String, dynamic> m) =>
      SendVerifyCodeResp();
  Map<String, dynamic> toJson() => {};
}

class SetAgentConsentReq {
  final bool granted;
  SetAgentConsentReq({required this.granted});
  factory SetAgentConsentReq.fromJson(Map<String, dynamic> m) =>
      SetAgentConsentReq(granted: m['granted'] ?? false);
  Map<String, dynamic> toJson() => {'granted': granted};
}

class SetAgentConsentResp {
  SetAgentConsentResp();
  factory SetAgentConsentResp.fromJson(Map<String, dynamic> m) =>
      SetAgentConsentResp();
  Map<String, dynamic> toJson() => {};
}

class SetPersonalizationPreferenceReq {
  final bool enabled;
  SetPersonalizationPreferenceReq({required this.enabled});
  factory SetPersonalizationPreferenceReq.fromJson(Map<String, dynamic> m) =>
      SetPersonalizationPreferenceReq(enabled: m['enabled'] ?? false);
  Map<String, dynamic> toJson() => {'enabled': enabled};
}

class SetPersonalizationPreferenceResp {
  SetPersonalizationPreferenceResp();
  factory SetPersonalizationPreferenceResp.fromJson(Map<String, dynamic> m) =>
      SetPersonalizationPreferenceResp();
  Map<String, dynamic> toJson() => {};
}

class SponsoredAdItem {
  final Object adId;
  final num revision;
  final String advertiserName;
  final String title;
  final String body;
  final String cta;
  final String landingUrl;
  final String landingDomain;
  final List<String> images;
  final String disclosure;
  final SponsoredWhyItem why;
  SponsoredAdItem({
    required this.adId,
    required this.revision,
    required this.advertiserName,
    required this.title,
    required this.body,
    required this.cta,
    required this.landingUrl,
    required this.landingDomain,
    required this.images,
    required this.disclosure,
    required this.why,
  });
  factory SponsoredAdItem.fromJson(Map<String, dynamic> m) => SponsoredAdItem(
    adId: m['adId'] ?? 0,
    revision: m['revision'] ?? 0,
    advertiserName: m['advertiserName']?.toString() ?? "",
    title: m['title']?.toString() ?? "",
    body: m['body']?.toString() ?? "",
    cta: m['cta']?.toString() ?? "",
    landingUrl: m['landingUrl']?.toString() ?? "",
    landingDomain: m['landingDomain']?.toString() ?? "",
    images: List<String>.from(m['images'] as List? ?? const []),
    disclosure: m['disclosure']?.toString() ?? "",
    why: SponsoredWhyItem.fromJson(
      Map<String, dynamic>.from(m['why'] as Map? ?? const {}),
    ),
  );
  Map<String, dynamic> toJson() => {
    'adId': adId,
    'revision': revision,
    'advertiserName': advertiserName,
    'title': title,
    'body': body,
    'cta': cta,
    'landingUrl': landingUrl,
    'landingDomain': landingDomain,
    'images': images,
    'disclosure': disclosure,
    'why': why.toJson(),
  };
}

class SponsoredSlotItem {
  final String slotId;
  final num afterPosition;
  final SponsoredAdItem ad;
  SponsoredSlotItem({
    required this.slotId,
    required this.afterPosition,
    required this.ad,
  });
  factory SponsoredSlotItem.fromJson(Map<String, dynamic> m) =>
      SponsoredSlotItem(
        slotId: m['slotId']?.toString() ?? "",
        afterPosition: m['afterPosition'] ?? 0,
        ad: SponsoredAdItem.fromJson(
          Map<String, dynamic>.from(m['ad'] as Map? ?? const {}),
        ),
      );
  Map<String, dynamic> toJson() => {
    'slotId': slotId,
    'afterPosition': afterPosition,
    'ad': ad.toJson(),
  };
}

class SponsoredWhyItem {
  final String market;
  final String scene;
  final bool personalized;
  SponsoredWhyItem({
    required this.market,
    required this.scene,
    required this.personalized,
  });
  factory SponsoredWhyItem.fromJson(Map<String, dynamic> m) => SponsoredWhyItem(
    market: m['market']?.toString() ?? "",
    scene: m['scene']?.toString() ?? "",
    personalized: m['personalized'] ?? false,
  );
  Map<String, dynamic> toJson() => {
    'market': market,
    'scene': scene,
    'personalized': personalized,
  };
}

class SubmitReviewDecisionReq {
  final Object taskId;
  final num leaseGeneration;
  final String verdict;
  final List<String> policyCodes;
  final String note;
  final bool nominateSeed;
  final String idempotencyKey;
  SubmitReviewDecisionReq({
    required this.taskId,
    required this.leaseGeneration,
    required this.verdict,
    required this.policyCodes,
    required this.note,
    required this.nominateSeed,
    required this.idempotencyKey,
  });
  factory SubmitReviewDecisionReq.fromJson(Map<String, dynamic> m) =>
      SubmitReviewDecisionReq(
        taskId: m['taskId'] ?? 0,
        leaseGeneration: m['leaseGeneration'] ?? 0,
        verdict: m['verdict']?.toString() ?? "",
        policyCodes: List<String>.from(m['policyCodes'] as List? ?? const []),
        note: m['note']?.toString() ?? "",
        nominateSeed: m['nominateSeed'] ?? false,
        idempotencyKey: m['idempotencyKey']?.toString() ?? "",
      );
  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'leaseGeneration': leaseGeneration,
    'verdict': verdict,
    'policyCodes': policyCodes,
    'note': note,
    'nominateSeed': nominateSeed,
    'idempotencyKey': idempotencyKey,
  };
}

class UndoAssistantMemoryChangeReq {
  final Object id;
  UndoAssistantMemoryChangeReq({required this.id});
  factory UndoAssistantMemoryChangeReq.fromJson(Map<String, dynamic> m) =>
      UndoAssistantMemoryChangeReq(id: m['id'] ?? 0);
  Map<String, dynamic> toJson() => {'id': id};
}

class UndoAssistantMemoryChangeResp {
  final AssistantMemoryEntry entry;
  UndoAssistantMemoryChangeResp({required this.entry});
  factory UndoAssistantMemoryChangeResp.fromJson(Map<String, dynamic> m) =>
      UndoAssistantMemoryChangeResp(
        entry: AssistantMemoryEntry.fromJson(
          Map<String, dynamic>.from(m['entry'] as Map? ?? const {}),
        ),
      );
  Map<String, dynamic> toJson() => {'entry': entry.toJson()};
}

class UnfavoriteReq {
  final Object postId;
  UnfavoriteReq({required this.postId});
  factory UnfavoriteReq.fromJson(Map<String, dynamic> m) =>
      UnfavoriteReq(postId: m['postId'] ?? 0);
  Map<String, dynamic> toJson() => {'postId': postId};
}

class UnfavoriteResp {
  UnfavoriteResp();
  factory UnfavoriteResp.fromJson(Map<String, dynamic> m) => UnfavoriteResp();
  Map<String, dynamic> toJson() => {};
}

class UnfollowReq {
  final Object targetUserId;
  UnfollowReq({required this.targetUserId});
  factory UnfollowReq.fromJson(Map<String, dynamic> m) =>
      UnfollowReq(targetUserId: m['targetUserId'] ?? 0);
  Map<String, dynamic> toJson() => {'targetUserId': targetUserId};
}

class UnfollowResp {
  UnfollowResp();
  factory UnfollowResp.fromJson(Map<String, dynamic> m) => UnfollowResp();
  Map<String, dynamic> toJson() => {};
}

class UnlikeReq {
  final Object targetId;
  final num targetType;
  UnlikeReq({required this.targetId, required this.targetType});
  factory UnlikeReq.fromJson(Map<String, dynamic> m) =>
      UnlikeReq(targetId: m['targetId'] ?? 0, targetType: m['targetType'] ?? 0);
  Map<String, dynamic> toJson() => {
    'targetId': targetId,
    'targetType': targetType,
  };
}

class UnlikeResp {
  UnlikeResp();
  factory UnlikeResp.fromJson(Map<String, dynamic> m) => UnlikeResp();
  Map<String, dynamic> toJson() => {};
}

class UpdateAdReq {
  final Object adId;
  final num expectedRevision;
  final String title;
  final String body;
  final String cta;
  final String landingUrl;
  final List<Object> mediaIds;
  final String market;
  final String industry;
  final num startMs;
  final num endMs;
  final String idempotencyKey;
  UpdateAdReq({
    required this.adId,
    required this.expectedRevision,
    required this.title,
    required this.body,
    required this.cta,
    required this.landingUrl,
    required this.mediaIds,
    required this.market,
    required this.industry,
    required this.startMs,
    required this.endMs,
    required this.idempotencyKey,
  });
  factory UpdateAdReq.fromJson(Map<String, dynamic> m) => UpdateAdReq(
    adId: m['adId'] ?? 0,
    expectedRevision: m['expectedRevision'] ?? 0,
    title: m['title']?.toString() ?? "",
    body: m['body']?.toString() ?? "",
    cta: m['cta']?.toString() ?? "",
    landingUrl: m['landingUrl']?.toString() ?? "",
    mediaIds: List<Object>.from(m['mediaIds'] as List? ?? const []),
    market: m['market']?.toString() ?? "",
    industry: m['industry']?.toString() ?? "",
    startMs: m['startMs'] ?? 0,
    endMs: m['endMs'] ?? 0,
    idempotencyKey: m['idempotencyKey']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'adId': adId,
    'expectedRevision': expectedRevision,
    'title': title,
    'body': body,
    'cta': cta,
    'landingUrl': landingUrl,
    'mediaIds': mediaIds,
    'market': market,
    'industry': industry,
    'startMs': startMs,
    'endMs': endMs,
    'idempotencyKey': idempotencyKey,
  };
}

class UpdateAssistantWatchReq {
  final Object id;
  final bool enabled;
  final num expectedVersion;
  UpdateAssistantWatchReq({
    required this.id,
    required this.enabled,
    required this.expectedVersion,
  });
  factory UpdateAssistantWatchReq.fromJson(Map<String, dynamic> m) =>
      UpdateAssistantWatchReq(
        id: m['id'] ?? 0,
        enabled: m['enabled'] ?? false,
        expectedVersion: m['expectedVersion'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'expectedVersion': expectedVersion,
  };
}

class UpdateAssistantWatchResp {
  final AssistantWatchTask task;
  UpdateAssistantWatchResp({required this.task});
  factory UpdateAssistantWatchResp.fromJson(Map<String, dynamic> m) =>
      UpdateAssistantWatchResp(
        task: AssistantWatchTask.fromJson(
          Map<String, dynamic>.from(m['task'] as Map? ?? const {}),
        ),
      );
  Map<String, dynamic> toJson() => {'task': task.toJson()};
}

class UpdatePostResp {
  final num status;
  final num revision;
  UpdatePostResp({required this.status, required this.revision});
  factory UpdatePostResp.fromJson(Map<String, dynamic> m) =>
      UpdatePostResp(status: m['status'] ?? 0, revision: m['revision'] ?? 0);
  Map<String, dynamic> toJson() => {'status': status, 'revision': revision};
}

class UpdatePostV2Req {
  final Object postId;
  final String title;
  final String content;
  final List<String>? images;
  final List<String> tags;
  final int? status;
  final num expectedRevision;
  final List<Object>? mediaIds;
  UpdatePostV2Req({
    required this.postId,
    required this.title,
    required this.content,
    this.images,
    required this.tags,
    required this.status,
    required this.expectedRevision,
    this.mediaIds,
  });
  factory UpdatePostV2Req.fromJson(Map<String, dynamic> m) => UpdatePostV2Req(
    postId: m['postId'] ?? 0,
    title: m['title']?.toString() ?? "",
    content: m['content']?.toString() ?? "",
    images: m['images'] == null
        ? null
        : List<String>.from(m['images'] as List? ?? const []),
    tags: List<String>.from(m['tags'] as List? ?? const []),
    status: m['status'] == null
        ? null
        : (m['status'] is num)
        ? (m['status'] as num).toInt()
        : 0,
    expectedRevision: m['expectedRevision'] ?? 0,
    mediaIds: m['mediaIds'] == null
        ? null
        : List<Object>.from(m['mediaIds'] as List? ?? const []),
  );
  Map<String, dynamic> toJson() => {
    'postId': postId,
    'title': title,
    'content': content,
    if (images != null) 'images': images,
    'tags': tags,
    'status': status,
    'expectedRevision': expectedRevision,
    if (mediaIds != null) 'mediaIds': mediaIds,
  };
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
  factory UpdateProfileReq.fromJson(Map<String, dynamic> m) => UpdateProfileReq(
    nickname: m['nickname']?.toString() ?? "",
    avatarUrl: m['avatarUrl']?.toString() ?? "",
    bio: m['bio']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'nickname': nickname,
    'avatarUrl': avatarUrl,
    'bio': bio,
  };
}

class UpdateProfileResp {
  UpdateProfileResp();
  factory UpdateProfileResp.fromJson(Map<String, dynamic> m) =>
      UpdateProfileResp();
  Map<String, dynamic> toJson() => {};
}

class UploadAdAssetReq {
  final String kind;
  UploadAdAssetReq({required this.kind});
  factory UploadAdAssetReq.fromJson(Map<String, dynamic> m) =>
      UploadAdAssetReq(kind: m['kind']?.toString() ?? "");
  Map<String, dynamic> toJson() => {'kind': kind};
}

class UploadImageReq {
  UploadImageReq();
  factory UploadImageReq.fromJson(Map<String, dynamic> m) => UploadImageReq();
  Map<String, dynamic> toJson() => {};
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
  factory UploadImageResp.fromJson(Map<String, dynamic> m) => UploadImageResp(
    mediaId: m['mediaId'] ?? 0,
    url: m['url']?.toString() ?? "",
    thumbnailUrl: m['thumbnailUrl']?.toString() ?? "",
  );
  Map<String, dynamic> toJson() => {
    'mediaId': mediaId,
    'url': url,
    'thumbnailUrl': thumbnailUrl,
  };
}

class UploadMediaReq {
  UploadMediaReq();
  factory UploadMediaReq.fromJson(Map<String, dynamic> m) => UploadMediaReq();
  Map<String, dynamic> toJson() => {};
}

class UploadMediaResp {
  final Object mediaId;
  final String url;
  final String fileType;
  final String mimeType;
  final num fileSize;
  UploadMediaResp({
    required this.mediaId,
    required this.url,
    required this.fileType,
    required this.mimeType,
    required this.fileSize,
  });
  factory UploadMediaResp.fromJson(Map<String, dynamic> m) => UploadMediaResp(
    mediaId: m['mediaId'] ?? 0,
    url: m['url']?.toString() ?? "",
    fileType: m['fileType']?.toString() ?? "",
    mimeType: m['mimeType']?.toString() ?? "",
    fileSize: m['fileSize'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'mediaId': mediaId,
    'url': url,
    'fileType': fileType,
    'mimeType': mimeType,
    'fileSize': fileSize,
  };
}
