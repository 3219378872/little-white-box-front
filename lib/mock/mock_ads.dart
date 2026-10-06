part of 'mock_router.dart';

/// 付费广告与审核的 Mock（FX-105、FX-070）。
///
/// 用户 1 是已过审广告主，并拥有 reviewer/qa 角色；推荐流在 `adSlots=1` 时每页返回两个
/// 确定性的广告槽位。审核队列预置首次审核、质检，以及提交时返回「持有失效」「任务作废」的任务。
/// 种子数据与重置逻辑在 `seeds/mock_ads_seed.dart`，本文件只保留运行时状态与请求处理。

const _mockReviewLease = Duration(minutes: 10);
const _mockReviewerId = 1;

/// 打开后第二个广告槽位缺少广告标识，用于覆盖逐槽丢弃的失败分支（FX-103）。
bool mockSponsoredMalformed = false;

// 运行时状态：ID 计数器与内存表，由 `_resetMockAds` 在每次重置时恢复为种子值。
int _nextAdId = 7100;
int _nextAdAssetId = 8100;
int _nextDecisionId = 9500;
late Map<int, Map<String, dynamic>> _advertisers;
late Map<int, Map<String, dynamic>> _ads;
late Map<int, Map<String, dynamic>> _adAssets;
late Set<String> _hiddenAds;
late Set<String> _adReports;
late Map<int, Map<String, dynamic>> _reviewTasks;
late Map<String, Map<String, dynamic>> _adIdempotency;

// 构造一份广告版本内容；种子与创建/编辑广告共用，保证字段形状一致。
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

// `/api/v2/ads/**` 路由，非广告路径返回 null 交回上层继续匹配。
// 举报与隐藏允许匿名（以 sessionId 识别观看者），其余接口要求登录。
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
  // 举报：同时对该观看者隐藏广告；counted 表示是否为首次计数的举报。
  if (rest.length == 2 && rest[1] == 'report') {
    _requireMethod(method, 'POST');
    final sessionId = body?['sessionId']?.toString().trim() ?? '';
    final reason = body?['reason']?.toString().trim() ?? '';
    if ((!auth.isAuthenticated && sessionId.isEmpty) ||
        !_mockReportReasons.contains(reason)) {
      throw const _MockBiz(400, 2, '参数错误');
    }
    final viewer = auth.isAuthenticated ? 'u:${auth.userId}' : 's:$sessionId';
    final adId = _pathId(rest[0]);
    _hiddenAds.add('$viewer:$adId');
    return _jsonResponse({'counted': _adReports.add('$viewer:$adId')});
  }
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
  // 广告控制台：列表与创建。
  if (rest.isEmpty) {
    if (method == 'GET') return _jsonResponse(_listMockAds(auth.userId));
    _requireMethod(method, 'POST');
    return _jsonResponse({'ad': _writeMockAd(auth.userId, null, body ?? {})});
  }
  // 广告主资料、资质与投放政策（政策表为演示数据）。
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
  // 素材上传与读取：上传只登记归属与类型，读取总是返回占位 PNG。
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
  if (rest.length == 2 && rest[1] == 'appeal') {
    _requireMethod(method, 'POST');
    return _jsonResponse({'ad': _appealMockAd(auth.userId, _pathId(rest[0]))});
  }
  // 单个广告的读取与编辑，仅限广告所有者。
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

// 当前用户的全部广告，一次返回不分页。
Map<String, dynamic> _listMockAds(int userId) => {
  'ads': [
    for (final ad in _ads.values)
      if (ad['owner'] == userId) _publicAd(ad),
  ],
  'nextCursor': '',
  'hasMore': false,
};

// 举报原因白名单。
const _mockReportReasons = {
  'misleading',
  'scam',
  'offensive',
  'inappropriate',
  'irrelevant',
  'other',
};

// 对外的广告对象：去掉内部归属字段，补上是否可申诉。
Map<String, dynamic> _publicAd(Map<String, dynamic> ad) =>
    Map<String, dynamic>.from(ad)
      ..remove('owner')
      ..['appealable'] = _mockAppealTarget(ad) > 0;

/// 与后端一致：最新版本被拒时申诉它；被下线且没有更新编辑时申诉过审版本；每个版本一次。
int _mockAppealTarget(Map<String, dynamic> ad) {
  final revision = ad['revision'] as int;
  final approved = ad['approvedRevision'] as int;
  final appealed = (ad['appealedRevision'] as int?) ?? 0;
  var target = 0;
  if (ad['reviewStatus'] == 'rejected') {
    target = revision;
  } else if (ad['servingStatus'] == 'offline' &&
      approved > 0 &&
      revision == approved &&
      ad['reviewStatus'] == 'approved') {
    target = approved;
  }
  return target > appealed ? target : 0;
}

// 提交申诉：无可申诉版本时返回 409/7106，成功后进入 appealing 并记下已申诉版本。
Map<String, dynamic> _appealMockAd(int userId, int adId) {
  final ad = _ads[adId];
  if (ad == null || ad['owner'] != userId) {
    throw const _MockBiz(404, 2001, '内容不存在');
  }
  final target = _mockAppealTarget(ad);
  if (target == 0) throw const _MockBiz(409, 7106, '当前版本不可申诉');
  ad
    ..['reviewStatus'] = 'appealing'
    ..['appealedRevision'] = target
    ..['updatedAtMs'] = DateTime.now().millisecondsSinceEpoch;
  return _publicAd(ad);
}

// 读取自己的广告，他人或不存在的广告一律按不存在处理。
Map<String, dynamic> _ownedAd(int userId, int adId) {
  final ad = _ads[adId];
  if (ad == null || ad['owner'] != userId) {
    throw const _MockBiz(404, 2001, '内容不存在');
  }
  return _publicAd(ad);
}

// 申请或更新广告主资料：expectedRevision 乐观并发，提交后重新进入待审。
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

// 追加行业资质：需要已是广告主且版本匹配，资质文件必须是本人上传的素材。
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

// 创建（[adId] 为 null）或编辑广告：幂等键重放返回首次结果；要求广告主已过审、
// 落地页为 https、行业不在受限列表；编辑需版本匹配，保存后版本加一并重新待审。
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
    'appealedRevision': current?['appealedRevision'] ?? 0,
  };
  _ads[id] = ad;
  if (key.isNotEmpty) _adIdempotency['$userId:$key'] = ad;
  return _publicAd(ad);
}

// `/api/v2/review/**` 路由，非审核路径返回 null。只有固定的审核员（用户 1）具备角色，
// 其他登录用户只能访问 `me`；续租、释放与提交结论要求持有有效租约。
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
  // 队列概览：按用途统计待审数量与最久等待时长。
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
  // 领取任务：取第一个匹配用途的待审任务并加租约。
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
    // 续租、释放与提交结论。
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

// 领取任务：租约代数加一，旧代数的后续操作会被判为持有失效。
void _leaseMockTask(Map<String, dynamic> task, int userId) {
  task['status'] = 'claimed';
  task['claimer'] = userId;
  task['leaseGeneration'] = (task['leaseGeneration'] as int) + 1;
  task['leaseUntilMs'] = DateTime.now()
      .add(_mockReviewLease)
      .millisecondsSinceEpoch;
}

// 校验任务操作的前提：已决任务 409/7004，预置作废任务 410/7002，
// 非本人持有、租约代数不符或预置持有失效时 409/7001。
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

// 提交审核结论：拒绝必须附政策代码；质检任务的结论来源记为 qa。
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

// 对外的任务对象：去掉持有人与预置失败标记等内部字段。
Map<String, dynamic> _publicTask(Map<String, dynamic> task) =>
    Map<String, dynamic>.from(task)
      ..remove('claimer')
      ..remove('failure');
