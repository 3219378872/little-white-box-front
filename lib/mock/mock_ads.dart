part of 'mock_router.dart';

/// 付费广告与审核的 Mock（FX-105、FX-070）。
///
/// 用户 1 是已过审广告主，并拥有 reviewer/qa 角色；推荐流在 `adSlots=1` 时每页返回两个
/// 确定性的广告槽位。审核队列预置首次审核、质检，以及提交时返回「持有失效」「任务作废」的任务。

const _mockReviewLease = Duration(minutes: 10);
const _mockReviewerId = 1;

/// 打开后第二个广告槽位缺少广告标识，用于覆盖逐槽丢弃的失败分支（FX-103）。
bool mockSponsoredMalformed = false;

int _nextAdId = 7100;
int _nextAdAssetId = 8100;
int _nextDecisionId = 9500;
late Map<int, Map<String, dynamic>> _advertisers;
late Map<int, Map<String, dynamic>> _ads;
late Map<int, Map<String, dynamic>> _adAssets;
late Set<String> _hiddenAds;
late Map<int, Map<String, dynamic>> _reviewTasks;
late Map<String, Map<String, dynamic>> _adIdempotency;

const _mockSponsoredAds = [
  {
    'adId': 7001,
    'revision': 1,
    'advertiserName': '小白盒周边店',
    'title': '社区限定桌搭套装上新',
    'body': '机械键盘、屏幕挂灯与桌垫组合，演示广告不涉及真实商品。',
    'cta': '去看看',
    'landingUrl': 'https://shop.example.com/desk?utm=xbh',
    'landingDomain': 'shop.example.com',
  },
  {
    'adId': 7002,
    'revision': 2,
    'advertiserName': 'Cloud IDE Demo',
    'title': '在浏览器里写代码',
    'body': '开箱即用的在线开发环境，演示广告。',
    'cta': '免费试用',
    'landingUrl': 'https://ide.example.org/start',
    'landingDomain': 'ide.example.org',
  },
];

void _resetMockAds() {
  final now = DateTime.now().millisecondsSinceEpoch;
  _nextAdId = 7100;
  _nextAdAssetId = 8100;
  _nextDecisionId = 9500;
  mockSponsoredMalformed = false;
  _hiddenAds = {};
  _adIdempotency = {};
  _adAssets = {};
  _advertisers = {
    1: {
      'advertiserId': 501,
      'name': '小白盒周边店',
      'markets': ['US', 'DE'],
      'revision': 1,
      'approvedRevision': 1,
      'reviewStatus': 'approved',
      'policyCodes': <String>[],
      'qualifications': <Map<String, dynamic>>[],
      'updatedAtMs': now,
    },
  };
  final approved = _mockAdContent(
    title: '社区限定桌搭套装上新',
    body: '机械键盘、屏幕挂灯与桌垫组合。',
    cta: '去看看',
    landingUrl: 'https://shop.example.com/desk',
    market: 'US',
    revision: 1,
  );
  _ads = {
    7001: {
      'owner': 1,
      'adId': 7001,
      'revision': 2,
      'approvedRevision': 1,
      'reviewStatus': 'pending_review',
      'servingStatus': 'serving',
      'policyCodes': <String>[],
      'latest': {...approved, 'title': '社区限定桌搭套装第二波', 'revision': 2},
      'approved': approved,
      'startMs': 0,
      'endMs': 0,
      'eligible': true,
      'updatedAtMs': now,
      'pauseReason': '',
    },
    7003: {
      'owner': 1,
      'adId': 7003,
      'revision': 1,
      'approvedRevision': 0,
      'reviewStatus': 'rejected',
      'servingStatus': 'none',
      'policyCodes': ['MISLEADING.ABSOLUTE', 'LANDING.MISMATCH'],
      'latest': _mockAdContent(
        title: '全网最低价，只此一天',
        body: '史上最强优惠。',
        cta: '立即抢购',
        landingUrl: 'https://deal.example.net/now',
        market: 'DE',
        revision: 1,
      ),
      'approved': null,
      'startMs': 0,
      'endMs': 0,
      'eligible': false,
      'updatedAtMs': now,
      'pauseReason': '',
    },
  };
  Map<String, dynamic> task(
    int id, {
    required String purpose,
    required String title,
    String failure = '',
    Map<String, dynamic>? originalDecision,
  }) => {
    'taskId': id,
    'bizType': 'ad_creative',
    'objectId': 7001,
    'objectRevision': 2,
    'purpose': purpose,
    'status': 'human_pending',
    'market': 'US',
    'language': 'en',
    'industry': 'GENERAL',
    'priority': 0,
    'deadlineMs': now + const Duration(hours: 24).inMilliseconds,
    'leaseGeneration': 0,
    'leaseUntilMs': 0,
    'snapshotJson': jsonEncode({
      'bizType': 'ad_creative',
      'snapshot': {
        'texts': {
          'advertiser': '小白盒周边店',
          'title': title,
          'body': 'Best desk setup for the community.',
          'cta': 'Shop now',
        },
        'landingUrl': 'https://shop.example.com/desk?utm=xbh',
        'market': 'US',
        'language': 'en',
        'industry': 'GENERAL',
        'submitterId': 1,
      },
    }),
    'stages': [
      {
        'stage': 'rules',
        'componentVersion': 'rules-ads-2026-10-01',
        'shadow': false,
        'outcome': 'pass',
        'reason': '',
        'outputJson': '{"hits":[]}',
        'latencyMs': 2,
      },
      {
        'stage': 'ranker',
        'componentVersion': 'stub-v0',
        'shadow': false,
        'outcome': 'uncertain',
        'reason': 'below auto-pass threshold',
        'outputJson': '{"scores":{"MISLEADING.CLAIM":0.5}}',
        'latencyMs': 14,
      },
    ],
    'originalDecision': originalDecision,
    'decision': null,
    'submittedAtMs': now - const Duration(minutes: 30).inMilliseconds,
    'escalationReason': 'ranker_uncertain',
    'policyVersion': 'ads-2026-10-01',
    'attempts': 0,
    'claimer': 0,
    'failure': failure,
  };
  _reviewTasks = {
    9001: task(9001, purpose: 'initial', title: 'Desk setup bundle'),
    9002: task(
      9002,
      purpose: 'qa',
      title: 'Lowest price ever',
      originalDecision: {
        'decisionId': 9400,
        'verdict': 'approve',
        'policyCodes': <String>[],
        'policyVersion': 'ads-2026-10-01',
        'source': 'machine',
        'decidedAtMs': now - const Duration(hours: 1).inMilliseconds,
      },
    ),
    9003: task(
      9003,
      purpose: 'initial',
      title: 'Edited after submit',
      failure: 'superseded',
    ),
    9004: task(
      9004,
      purpose: 'initial',
      title: 'Slow decision',
      failure: 'lease_lost',
    ),
  };
}

Map<String, dynamic> _mockAdContent({
  required String title,
  required String body,
  required String cta,
  required String landingUrl,
  required String market,
  required int revision,
  String industry = 'GENERAL',
  List<Object> media = const [],
}) => {
  'title': title,
  'body': body,
  'cta': cta,
  'landingUrl': landingUrl,
  'landingDomain': Uri.parse(landingUrl).host,
  'media': [
    for (final id in media) {'mediaId': id, 'sha256': '', 'publicUrl': ''},
  ],
  'market': market,
  'language': switch (market) {
    'DE' => 'de',
    'ID' => 'id',
    _ => 'en',
  },
  'industry': industry,
  'advertiserName': '小白盒周边店',
  'revision': revision,
};

/// 推荐流广告槽位：本页第 3、7 个自然条目之后各一个（种子帖子只有 8 篇；FX-105）。
List<Map<String, dynamic>> _mockSponsoredSlots(
  List<Map<String, dynamic>> items,
  Map<String, String> query,
  _Auth auth,
) {
  if (query['adSlots'] != '1') return const [];
  final viewer = auth.isAuthenticated
      ? 'u:${auth.userId}'
      : 's:${query['sessionId'] ?? ''}';
  final slots = <Map<String, dynamic>>[];
  for (final (index, after) in const [3, 7].indexed) {
    if (items.length < after || index >= _mockSponsoredAds.length) continue;
    final ad = _mockSponsoredAds[index];
    if (_hiddenAds.contains('$viewer:${ad['adId']}')) continue;
    final malformed = mockSponsoredMalformed && index == 1;
    slots.add({
      // Matches the backend: slot ids restart at s1 on every page.
      'slotId': 's${index + 1}',
      'afterPosition': items[after - 1]['position'],
      'ad': {
        ...ad,
        'images': const <String>[],
        if (!malformed) 'disclosure': 'sponsored',
        'why': {'market': 'US', 'scene': 'home', 'personalized': false},
      },
    });
  }
  return slots;
}

MockRouterResponse? _routeAds(
  String method,
  List<String> segments,
  Map<String, String> query,
  Map<String, dynamic>? body,
  _Auth auth,
  Map<String, String> headers,
) {
  if (segments.length < 3 || segments[2] != 'ads') return null;
  final rest = segments.sublist(3);
  if (rest.length == 2 && rest[1] == 'hide') {
    _requireMethod(method, 'POST');
    final sessionId = body?['sessionId']?.toString().trim() ?? '';
    if (!auth.isAuthenticated && sessionId.isEmpty) {
      throw const _MockBiz(400, 2, '参数错误');
    }
    final viewer = auth.isAuthenticated ? 'u:${auth.userId}' : 's:$sessionId';
    _hiddenAds.add('$viewer:${_pathId(rest[0])}');
    return _jsonResponse({'ok': true});
  }
  _requireAuth(auth);
  if (rest.isEmpty) {
    if (method == 'GET') return _jsonResponse(_listMockAds(auth.userId));
    _requireMethod(method, 'POST');
    return _jsonResponse({'ad': _writeMockAd(auth.userId, null, body ?? {})});
  }
  switch (rest.join('/')) {
    case 'advertiser':
      if (method == 'GET') {
        final advertiser = _advertisers[auth.userId];
        return _jsonResponse({
          'found': advertiser != null,
          'advertiser': advertiser,
        });
      }
      _requireMethod(method, 'PUT');
      return _jsonResponse({
        'found': true,
        'advertiser': _applyMockAdvertiser(auth.userId, body ?? {}),
      });
    case 'advertiser/qualifications':
      _requireMethod(method, 'POST');
      return _jsonResponse({
        'found': true,
        'advertiser': _addMockQualification(auth.userId, body ?? {}),
      });
    case 'policies':
      _requireMethod(method, 'GET');
      return _jsonResponse({
        'policyVersion': 'ads-2026-10-01',
        'codes': [
          for (final entry in _mockPolicyTitles.entries)
            {'code': entry.key, 'title': entry.value, 'category': ''},
        ],
        'markets': ['US', 'DE', 'ID'],
        'industries': [
          'GENERAL',
          'FINANCIAL',
          'HEALTHCARE',
          'WEIGHT',
          'ALCOHOL',
          'GAMBLING',
          'ADULT',
          'DANGEROUS',
          'POLITICAL',
        ],
        'demo': true,
      });
  }
  if (rest.length == 2 && rest[0] == 'assets') {
    if (method == 'POST') {
      if (rest[1] != 'creative' && rest[1] != 'document') {
        throw const _MockBiz(400, 2, '参数错误');
      }
      final id = _nextAdAssetId++;
      _adAssets[id] = {'owner': auth.userId, 'kind': rest[1]};
      return _jsonResponse({
        'assetId': id,
        'kind': rest[1],
        'sha256': 'mock$id',
        'mimeType': 'image/png',
        'size': _mockPng.length,
      });
    }
    _requireMethod(method, 'GET');
    final asset = _adAssets[_pathId(rest[1])];
    if (asset == null || asset['owner'] != auth.userId) {
      throw const _MockBiz(404, 2001, '内容不存在');
    }
    return _jsonResponse({
      'mimeType': 'image/png',
      'contentBase64': base64Encode(_mockPng),
    });
  }
  if (rest.length == 1) {
    final adId = _pathId(rest[0]);
    if (method == 'GET') {
      return _jsonResponse({'ad': _ownedAd(auth.userId, adId)});
    }
    _requireMethod(method, 'PUT');
    return _jsonResponse({'ad': _writeMockAd(auth.userId, adId, body ?? {})});
  }
  throw const _MockBiz(404, 4, '资源不存在');
}

Map<String, dynamic> _listMockAds(int userId) => {
  'ads': [
    for (final ad in _ads.values)
      if (ad['owner'] == userId) _publicAd(ad),
  ],
  'nextCursor': '',
  'hasMore': false,
};

Map<String, dynamic> _publicAd(Map<String, dynamic> ad) =>
    Map<String, dynamic>.from(ad)..remove('owner');

Map<String, dynamic> _ownedAd(int userId, int adId) {
  final ad = _ads[adId];
  if (ad == null || ad['owner'] != userId) {
    throw const _MockBiz(404, 2001, '内容不存在');
  }
  return _publicAd(ad);
}

Map<String, dynamic> _applyMockAdvertiser(
  int userId,
  Map<String, dynamic> body,
) {
  final name = body['name']?.toString().trim() ?? '';
  final markets = _stringList(body['markets']);
  if (name.runes.length < 2 || markets.isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final current = _advertisers[userId];
  final expected = (body['expectedRevision'] as num?)?.toInt() ?? 0;
  if ((current?['revision'] ?? 0) != expected) {
    throw const _MockBiz(409, 2007, '内容版本冲突');
  }
  final next = {
    ...?current,
    'advertiserId': current?['advertiserId'] ?? 500 + userId,
    'name': name,
    'markets': markets,
    'revision': expected + 1,
    'approvedRevision': current?['approvedRevision'] ?? 0,
    'reviewStatus': 'pending_review',
    'policyCodes': <String>[],
    'qualifications': current?['qualifications'] ?? <Map<String, dynamic>>[],
    'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
  };
  _advertisers[userId] = next;
  return next;
}

Map<String, dynamic> _addMockQualification(
  int userId,
  Map<String, dynamic> body,
) {
  final current = _advertisers[userId];
  if (current == null) throw const _MockBiz(403, 7101, '请先申请成为广告主');
  if (current['revision'] != (body['expectedRevision'] as num?)?.toInt()) {
    throw const _MockBiz(409, 2007, '内容版本冲突');
  }
  final assetId = _isPositiveId(body['documentAssetId'])
      ? jsonInt64Id(body['documentAssetId'])
      : '';
  final asset = _adAssets[int.tryParse(assetId) ?? 0];
  if (asset == null || asset['owner'] != userId) {
    throw const _MockBiz(400, 7107, '素材无效');
  }
  final revision = (current['revision'] as int) + 1;
  final next = {
    ...current,
    'revision': revision,
    'reviewStatus': 'pending_review',
    'qualifications': [
      ...(current['qualifications'] as List),
      {
        'qualificationId': 600 + revision,
        'market': body['market'],
        'industry': body['industry'],
        'documentAssetId': body['documentAssetId'],
        'validUntilMs': body['validUntilMs'],
        'status': 'pending',
        'submittedRevision': revision,
      },
    ],
  };
  _advertisers[userId] = next;
  return next;
}

Map<String, dynamic> _writeMockAd(
  int userId,
  int? adId,
  Map<String, dynamic> body,
) {
  final key = body['idempotencyKey']?.toString() ?? '';
  final replay = _adIdempotency['$userId:$key'];
  if (key.isNotEmpty && replay != null) return _publicAd(replay);
  final advertiser = _advertisers[userId];
  if (advertiser == null || advertiser['approvedRevision'] == 0) {
    throw const _MockBiz(403, 7101, '广告主未通过审核');
  }
  final landing = Uri.tryParse(body['landingUrl']?.toString() ?? '');
  if (landing == null || landing.scheme != 'https' || landing.host.isEmpty) {
    throw const _MockBiz(400, 7104, '落地页地址不合规');
  }
  final industry = body['industry']?.toString() ?? '';
  if (const {
    'ALCOHOL',
    'GAMBLING',
    'ADULT',
    'DANGEROUS',
    'POLITICAL',
  }.contains(industry)) {
    throw const _MockBiz(400, 7105, '该市场不支持此行业');
  }
  final current = adId == null ? null : _ads[adId];
  if (adId != null && (current == null || current['owner'] != userId)) {
    throw const _MockBiz(404, 2001, '内容不存在');
  }
  final expected = (body['expectedRevision'] as num?)?.toInt() ?? 0;
  if (current != null && current['revision'] != expected) {
    throw const _MockBiz(409, 2007, '内容版本冲突');
  }
  final id = adId ?? _nextAdId++;
  final revision = ((current?['revision'] as int?) ?? 0) + 1;
  final ad = {
    'owner': userId,
    'adId': id,
    'revision': revision,
    'approvedRevision': current?['approvedRevision'] ?? 0,
    'reviewStatus': 'pending_review',
    'servingStatus': current?['servingStatus'] ?? 'none',
    'policyCodes': <String>[],
    'latest': _mockAdContent(
      title: body['title']?.toString() ?? '',
      body: body['body']?.toString() ?? '',
      cta: body['cta']?.toString() ?? '',
      landingUrl: landing.toString(),
      market: body['market']?.toString() ?? 'US',
      industry: industry,
      revision: revision,
      media: [...?(body['mediaIds'] as List?)?.whereType<Object>()],
    ),
    'approved': current?['approved'],
    'startMs': body['startMs'] ?? 0,
    'endMs': body['endMs'] ?? 0,
    'eligible': current?['eligible'] ?? false,
    'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    'pauseReason': '',
  };
  _ads[id] = ad;
  if (key.isNotEmpty) _adIdempotency['$userId:$key'] = ad;
  return _publicAd(ad);
}

MockRouterResponse? _routeReview(
  String method,
  List<String> segments,
  Map<String, dynamic>? body,
  _Auth auth,
) {
  if (segments.length < 3 || segments[2] != 'review') return null;
  _requireAuth(auth);
  final reviewer = auth.userId == _mockReviewerId;
  final rest = segments.sublist(3).join('/');
  if (rest == 'me') {
    _requireMethod(method, 'GET');
    return _jsonResponse({
      'active': reviewer,
      'roles': reviewer ? ['reviewer', 'qa'] : <String>[],
      'markets': reviewer ? ['US', 'DE', 'ID'] : <String>[],
      'languages': reviewer ? ['en', 'de', 'id'] : <String>[],
    });
  }
  if (!reviewer) throw const _MockBiz(403, 7003, '需要审核角色');
  if (rest == 'queue') {
    _requireMethod(method, 'GET');
    final now = DateTime.now().millisecondsSinceEpoch;
    final buckets = <String, Map<String, dynamic>>{};
    for (final task in _reviewTasks.values) {
      if (task['status'] != 'human_pending') continue;
      final bucket = buckets.putIfAbsent(
        task['purpose'] as String,
        () => {'purpose': task['purpose'], 'pending': 0, 'oldestAgeMs': 0},
      );
      bucket['pending'] = (bucket['pending'] as int) + 1;
      final age = now - (task['submittedAtMs'] as int);
      if (age > (bucket['oldestAgeMs'] as int)) bucket['oldestAgeMs'] = age;
    }
    return _jsonResponse({
      'buckets': buckets.values.toList(),
      'policyVersion': 'ads-2026-10-01',
    });
  }
  if (rest == 'tasks/claim') {
    _requireMethod(method, 'POST');
    final purpose = body?['purpose']?.toString() ?? '';
    for (final task in _reviewTasks.values) {
      if (task['status'] != 'human_pending') continue;
      if (purpose.isNotEmpty && task['purpose'] != purpose) continue;
      _leaseMockTask(task, auth.userId);
      return _jsonResponse({'found': true, 'task': _publicTask(task)});
    }
    return _jsonResponse({'found': false, 'task': null});
  }
  final parts = segments.sublist(3);
  if (parts.length >= 2 && parts[0] == 'tasks') {
    final task = _reviewTasks[_pathId(parts[1])];
    if (task == null) throw const _MockBiz(404, 2001, '内容不存在');
    if (parts.length == 2) {
      _requireMethod(method, 'GET');
      return _jsonResponse({'found': true, 'task': _publicTask(task)});
    }
    if (parts.length == 4 && parts[2] == 'media') {
      _requireMethod(method, 'GET');
      return _jsonResponse({
        'mimeType': 'image/png',
        'contentBase64': base64Encode(_mockPng),
      });
    }
    if (parts.length == 3) {
      _requireMethod(method, 'POST');
      _requireMockLease(task, auth.userId, body);
      switch (parts[2]) {
        case 'renew':
          task['leaseUntilMs'] = DateTime.now()
              .add(_mockReviewLease)
              .millisecondsSinceEpoch;
          return _jsonResponse({'found': true, 'task': _publicTask(task)});
        case 'release':
          task['status'] = 'human_pending';
          task['claimer'] = 0;
          return _jsonResponse({'ok': true});
        case 'decision':
          return _jsonResponse(_decideMockTask(task, body ?? {}));
      }
    }
  }
  throw const _MockBiz(404, 4, '资源不存在');
}

void _leaseMockTask(Map<String, dynamic> task, int userId) {
  task['status'] = 'claimed';
  task['claimer'] = userId;
  task['leaseGeneration'] = (task['leaseGeneration'] as int) + 1;
  task['leaseUntilMs'] = DateTime.now()
      .add(_mockReviewLease)
      .millisecondsSinceEpoch;
}

void _requireMockLease(
  Map<String, dynamic> task,
  int userId,
  Map<String, dynamic>? body,
) {
  if (task['status'] == 'decided') {
    throw const _MockBiz(409, 7004, '任务已有结论');
  }
  if (task['failure'] == 'superseded') {
    task['status'] = 'superseded';
    throw const _MockBiz(410, 7002, '任务已作废');
  }
  final generation = (body?['leaseGeneration'] as num?)?.toInt();
  if (task['failure'] == 'lease_lost' ||
      task['claimer'] != userId ||
      task['status'] != 'claimed' ||
      task['leaseGeneration'] != generation) {
    throw const _MockBiz(409, 7001, '持有已失效');
  }
}

Map<String, dynamic> _decideMockTask(
  Map<String, dynamic> task,
  Map<String, dynamic> body,
) {
  final verdict = body['verdict']?.toString() ?? '';
  final codes = _stringList(body['policyCodes']);
  if (verdict != 'approve' && verdict != 'reject' ||
      verdict == 'reject' && codes.isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final decision = {
    'decisionId': _nextDecisionId++,
    'verdict': verdict,
    'policyCodes': verdict == 'reject' ? codes : <String>[],
    'policyVersion': task['policyVersion'],
    'source': task['purpose'] == 'qa' ? 'qa' : 'human',
    'decidedAtMs': DateTime.now().millisecondsSinceEpoch,
  };
  task['status'] = 'decided';
  task['decision'] = decision;
  return {
    'decisionId': decision['decisionId'],
    'verdict': verdict,
    'policyCodes': decision['policyCodes'],
    'policyVersion': task['policyVersion'],
  };
}

Map<String, dynamic> _publicTask(Map<String, dynamic> task) =>
    Map<String, dynamic>.from(task)
      ..remove('claimer')
      ..remove('failure');

const _mockPolicyTitles = {
  'MISLEADING.CLAIM': '承诺或夸大效果',
  'MISLEADING.ABSOLUTE': '涉及时间、地域或品牌的绝对化用语',
  'MISLEADING.CLICKBAIT': '虚假交互元素或诱导点击',
  'CONTENT.DECEPTIVE': '欺诈或欺骗性做法',
  'LANDING.MISMATCH': '落地页与广告内容、语言或目标市场不一致',
  'INDUSTRY.QUALIFICATION': '缺少目标市场要求的行业资质',
};

/// 1×1 透明 PNG，作为 Mock 素材内容。
final _mockPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);
