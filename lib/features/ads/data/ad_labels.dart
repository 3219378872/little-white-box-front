/// 广告与审核界面的本地化文案，集中维护在此（DES-sponsored-ads-client「广告主控制台」）。
///
/// 政策码与后端 `pkg/adpolicy` 的演示配置一致；未知代码原样显示而不报错。
const adPolicyLabels = <String, String>{
  'INDUSTRY.ADULT': '成人内容与服务',
  'INDUSTRY.ALCOHOL': '酒精',
  'INDUSTRY.GAMBLING': '博彩与游戏',
  'INDUSTRY.FINANCIAL': '金融服务',
  'INDUSTRY.HEALTHCARE': '医疗与药品',
  'INDUSTRY.WEIGHT': '体重管理与身体形象',
  'INDUSTRY.DANGEROUS': '危险商品或服务',
  'INDUSTRY.POLITICAL': '政治、政府与选举',
  'INDUSTRY.RESTRICTED_OTHER': '其他受限商品与服务',
  'INDUSTRY.QUALIFICATION': '缺少目标市场要求的行业资质',
  'MISLEADING.CLAIM': '承诺或夸大效果',
  'MISLEADING.ABSOLUTE': '涉及时间、地域或品牌的绝对化用语',
  'MISLEADING.INCONSISTENT': '广告与落地页的产品、价格或优惠不一致，或缺少必要说明与条款',
  'MISLEADING.CLICKBAIT': '虚假交互元素或诱导点击',
  'MISLEADING.COMPARISON': '前后对比、恶意比较或主观贬低',
  'MISLEADING.AIGC': '未标注的显著 AI 生成或编辑内容',
  'MISLEADING.IDENTITY': '未经许可使用他人形象或虚假背书',
  'CONTENT.DECEPTIVE': '欺诈或欺骗性做法',
  'CONTENT.MISINFORMATION': '虚假信息',
  'CONTENT.DISCRIMINATION': '歧视、骚扰与霸凌',
  'CONTENT.VIOLENCE': '暴力与危险活动',
  'CONTENT.SELF_HARM': '自杀与自残',
  'CONTENT.TEEN_SAFETY': '危害青少年安全与福祉',
  'CONTENT.IP': '知识产权侵权',
  'FORMAT.FUNCTIONALITY': '广告格式或功能不符合要求',
  'LANDING.URL': '落地页地址不合规',
  'LANDING.DOMAIN': '落地页域名被禁止',
  'LANDING.MISMATCH': '落地页与广告内容、语言或目标市场不一致',
  'LANDING.PRIVACY': '落地页收集个人信息但缺少隐私政策',
  'ACCOUNT.RISK': '广告主反复违规或规避审核',
};

/// 政策码的中文说明；未知代码返回原始代码。
String adPolicyLabel(String code) => adPolicyLabels[code] ?? code;

const adMarketLabels = <String, String>{
  'US': '美国（英语）',
  'DE': '德国（德语）',
  'ID': '印度尼西亚（印尼语）',
};

String adMarketLabel(String market) => adMarketLabels[market] ?? market;

const adIndustryLabels = <String, String>{
  'GENERAL': '一般商品与服务',
  'FINANCIAL': '金融服务',
  'HEALTHCARE': '医疗与药品',
  'WEIGHT': '体重管理',
  'ALCOHOL': '酒精',
  'GAMBLING': '博彩',
  'ADULT': '成人',
  'DANGEROUS': '危险商品',
  'POLITICAL': '政治',
};

String adIndustryLabel(String industry) =>
    adIndustryLabels[industry] ?? industry;

/// 需要提交目标市场资质的行业（演示矩阵）；酒精、博彩等禁投行业不提供资质入口。
const qualificationIndustries = ['FINANCIAL', 'HEALTHCARE', 'WEIGHT'];

String adReviewStatusLabel(String status) => switch (status) {
  'draft' => '草稿',
  'pending_review' => '审核中',
  'approved' => '已通过',
  'rejected' => '未通过',
  'appealing' => '申诉中',
  'expired' => '已过期',
  'pending' => '审核中',
  _ => status.isEmpty ? '未知' : status,
};

String adServingStatusLabel(String status) => switch (status) {
  'none' => '未投放',
  'serving' => '投放中',
  'paused' => '已暂停',
  'offline' => '已下线',
  _ => status.isEmpty ? '未知' : status,
};

/// 暂停与下线原因：回扫、质检与举报写任务目的，资质失效写政策码。
String adPauseReasonLabel(String reason) => switch (reason) {
  '' => '',
  'rescan' => '政策回扫判定疑似违规',
  'qa' => '质检复审判定违规',
  'report' => '用户举报经复审成立',
  _ => adPolicyLabel(reason),
};

/// 举报原因（与后端 `ReportReasons` 一致），按展示顺序排列（FX-101）。
const adReportReasons = <(String, String)>[
  ('misleading', '虚假或误导'),
  ('scam', '诈骗或欺诈'),
  ('offensive', '冒犯或令人不适'),
  ('inappropriate', '不适宜的内容'),
  ('irrelevant', '与我无关或重复出现'),
  ('other', '其他'),
];

/// 转人审原因的中文说明；未知原因原样显示。
String reviewEscalationLabel(String reason) => switch (reason) {
  'rescan-violation' => '政策回扫判定疑似违规，广告已暂停投放',
  'report' => '用户举报',
  'appeal' => '广告主申诉',
  'qa' => '自动通过抽样质检',
  'gray-zone' => '机审分数处于灰区',
  'first-submission-protection' => '广告主前 3 次送审保护期',
  'industry-no-auto-pass' => '行业不允许自动通过',
  'image-unconfirmed' => '图片未经人工确认',
  'forced-human-rule' => '命中强制人审规则',
  'qualification-review' => '资质对象需资质审核员审核',
  'router-unavailable' || 'router-no-coverage' => '召回不可用，已全部精排',
  'ranker-timeout' || 'ranker-unavailable' || 'ranker-invalid' => '精排不可用',
  _ => reason,
};

/// 不同任务目的下结论的业务效果，提示审核员（FX-113）。
String? reviewPurposeHint(String purpose) => switch (purpose) {
  'rescan' => '广告已暂停投放：拒绝即确认违规并下线，通过则恢复投放。',
  'report' => '拒绝表示举报成立，广告将下线；通过表示举报不成立。',
  'appeal' => '申诉复审结论为最终结论，原决策人不能处理本任务。',
  'qa' => '质检判定违规时广告立即下线。',
  _ => null,
};

String reviewTaskStatusLabel(String status) => switch (status) {
  'machine_pending' || 'machine_running' => '机审中',
  'human_pending' => '待人审',
  'claimed' => '处理中',
  'decided' => '已结案',
  'superseded' => '已作废',
  _ => status,
};

String reviewPurposeLabel(String purpose) => switch (purpose) {
  'initial' => '首次审核',
  'qa' => '质检',
  'appeal' => '申诉',
  'report' => '举报',
  'rescan' => '回扫',
  _ => purpose,
};

String reviewBizTypeLabel(String bizType) => switch (bizType) {
  'ad_creative' => '广告创意',
  'advertiser_qualification' => '广告主与资质',
  _ => bizType,
};

String reviewVerdictLabel(String verdict) => switch (verdict) {
  'approve' => '通过',
  'reject' => '拒绝',
  _ => verdict,
};

String reviewSourceLabel(String source) => switch (source) {
  'machine' => '机审',
  'human' => '人审',
  'qa' => '质检',
  _ => source,
};

/// 审核快照文案字段名。
String reviewSnapshotTextLabel(String key) => switch (key) {
  'advertiser' => '广告主',
  'name' => '主体名称',
  'markets' => '投放市场',
  'title' => '标题',
  'body' => '正文',
  'cta' => '行动按钮',
  _ => key,
};
