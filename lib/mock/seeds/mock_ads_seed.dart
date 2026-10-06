part of '../mock_router.dart';

// 付费广告与审核 Mock 的种子数据：推荐流演示广告、每次重置时恢复的广告主/广告/审核任务、
// 政策标题表与素材占位图。处理请求的路由逻辑在 `mock_ads.dart`。

/// 推荐流广告槽位使用的两条演示广告，按槽位顺序取用。
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

/// 重置广告 Mock 状态：清空隐藏、举报、幂等与素材记录，并恢复预置的广告主、广告与审核任务。
///
/// 预置广告覆盖待审（7001）、被拒可申诉（7003）与举报下线可申诉（7004）；审核队列覆盖首次
/// 审核、质检、提交时「任务作废」「持有失效」、举报、复扫与申诉等用途。
void _resetMockAds() {
  final now = DateTime.now().millisecondsSinceEpoch;
  _nextAdId = 7100;
  _nextAdAssetId = 8100;
  _nextDecisionId = 9500;
  mockSponsoredMalformed = false;
  _hiddenAds = {};
  _adReports = {};
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
      'appealedRevision': 0,
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
      'appealedRevision': 0,
    },
    // 举报成立后下线的广告：被下线的过审版本可申诉一次（ADS-014）。
    7004: {
      'owner': 1,
      'adId': 7004,
      'revision': 1,
      'approvedRevision': 1,
      'reviewStatus': 'rejected',
      'servingStatus': 'offline',
      'policyCodes': ['CONTENT.DECEPTIVE'],
      'latest': _mockAdContent(
        title: '限时返现活动',
        body: '下单即返现。',
        cta: '立即参与',
        landingUrl: 'https://cashback.example.com/promo',
        market: 'US',
        revision: 1,
      ),
      'approved': _mockAdContent(
        title: '限时返现活动',
        body: '下单即返现。',
        cta: '立即参与',
        landingUrl: 'https://cashback.example.com/promo',
        market: 'US',
        revision: 1,
      ),
      'startMs': 0,
      'endMs': 0,
      'eligible': false,
      'updatedAtMs': now,
      'pauseReason': 'report',
      'appealedRevision': 0,
    },
  };
  Map<String, dynamic> task(
    int id, {
    required String purpose,
    required String title,
    String failure = '',
    Map<String, dynamic>? originalDecision,
    String escalationReason = 'gray-zone',
    int priority = 0,
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
    'priority': priority,
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
    'escalationReason': escalationReason,
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
    9005: task(
      9005,
      purpose: 'report',
      title: 'Reported cashback',
      escalationReason: 'report',
      priority: 60,
    ),
    9006: task(
      9006,
      purpose: 'rescan',
      title: 'Paused by rescan',
      escalationReason: 'rescan-violation',
      priority: 90,
    ),
    9007: task(
      9007,
      purpose: 'appeal',
      title: 'Appealed claim',
      escalationReason: 'appeal',
      originalDecision: {
        'decisionId': 9401,
        'verdict': 'reject',
        'policyCodes': ['MISLEADING.CLAIM'],
        'policyVersion': 'ads-2026-10-01',
        'source': 'human',
        'decidedAtMs': now - const Duration(hours: 2).inMilliseconds,
      },
    ),
  };
}

/// `policies` 接口返回的政策代码与中文标题。
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
