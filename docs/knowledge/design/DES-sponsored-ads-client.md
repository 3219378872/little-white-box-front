---
id: DES-sponsored-ads-client
layer: design
title: 付费广告与审核客户端设计
status: active
owner: agent
external_upstream:
- little-white-box-content-community@e3a390a51cc8434b4353d013e74141b0165c27f8:SPEC-sponsored-ads
- little-white-box-content-community@e3a390a51cc8434b4353d013e74141b0165c27f8:SPEC-review-platform
tracks:
- FX-100
- FX-101
- FX-102
- FX-103
- FX-104
- FX-105
- FX-110
- FX-111
- FX-112
- FX-113
- FQ-010
- FQ-011
updated_at: 2026-10-01
---

# 付费广告与审核客户端设计

## 范围

本页承接推荐流广告槽位、广告主控制台、审核工作台、入口守卫，以及广告界面的设计系统与解析约束。
后端契约来自 `SPEC-sponsored-ads` 与 `SPEC-review-platform`；身份、传输、精确 ID 与 Mock 边界沿用
[DES-client-platform](DES-client-platform.md)，推荐流与行为队列沿用 [DES-community-client](DES-community-client.md)，
视觉基准沿用 [DES-presentation-client](DES-presentation-client.md)。2026-10-01 W5 已按本页实现，同日随后端 W6
补齐举报入口、申诉入口与举报、回扫、申诉任务的工作台展示；与原计划不同之处在各节以「实现调整」注明；逐条状态见
[IMP-sponsored-ads-client](../implementation/IMP-sponsored-ads-client.md)。

## 推荐流广告

- **请求**（`FX-105`）：推荐请求增加 `adSlots: 1`。后端只在声明时返回可选的 `sponsored` 数组，每项包含
  `slotId`、`afterPosition` 与 `ad`（广告主名称、标题、正文、CTA、落地页与域名、图片、标识与 `why`）。
  客户端不发送 `market`，由后端按缺省演示市场 US 投放；关注流不声明广告槽位。
- **解析**（`FX-103`、`FQ-011`）：`FeedRepository` 对 `items` 保持现有的严格解析
  （`lib/features/feed/data/feed_repository.dart`）。`sponsored` 由独立解析器
  （`lib/features/feed/data/sponsored_parser.dart`）逐槽解析，单槽格式错误只丢弃该槽，不抛出页面
  错误。以下情况视为格式错误：缺少 slotId、afterPosition 非正
  整数、广告 ID 或 revision 无效、缺广告主或标题、标识不是 `sponsored`、落地页不是不带用户信息的 https
  地址、`landingDomain` 与落地页主机不一致、同页 slotId 重复。图片只保留 http(s) 或同源相对地址。
- **模型**（实现调整）：`FeedEntry` 保持自然内容条目不变，广告以独立的 `SponsoredSlot` 存放在
  `FeedState.sponsored`；展示时由 `mergeFeedRows` 生成密封类型 `FeedRow`（`FeedPostRow` / `FeedAdRow`）。
  原计划把 `FeedEntry` 改为密封类型，但那会让帖子去重、`positionOffset` 与热门标签统计都要区分广告；
  分开存放后这些逻辑无需改动，隐藏与恢复也只操作广告列表。
- **合并**：把广告插到同一 requestId 中 position 等于 afterPosition 的自然条目之后；找不到时丢弃该槽。
  帖子去重仍只比较自然条目的 post id。`positionOffset` 只累计自然条目，避免广告挤偏帖子的回退位置。
  后端每页的 slotId 都从 `s1` 编号，因此跨页按 `ad-<requestId>-<afterPosition>-<slotId>` 去重，列表 key 相同。
- **隐藏与举报**（`FX-101`）：隐藏先在本地移除该广告的全部槽位，再调用隐藏接口（匿名用户带 sessionId，
  只隐藏当前会话），失败时按原位置恢复并提示「隐藏失败，广告已恢复」；请求期间列表已刷新时不恢复旧槽位，只提示
  重试。隐藏成功后才以 `ad` 目标类型上报 `hide` 行为，保留请求链归因，失败的隐藏不计入统计。「为什么看到这条广告」以底部面板展示广告主、市场、场景与是否个性化。
  举报：溢出菜单「举报这条广告」打开底部面板，列出与后端一致的结构化原因（虚假或误导、诈骗或欺诈、冒犯或令人
  不适、不适宜的内容、与我无关或重复出现、其他），选择即提交，关闭面板不提交，不收集自由文本。举报经
  `POST /api/v2/ads/{adId}/report` 提交（匿名用户带 sessionId）；后端同时对举报人隐藏该广告，因此客户端沿用
  隐藏的处理：先在本地移除，成功提示「已举报，感谢反馈」，失败按原位置恢复并提示「举报失败，广告已恢复」。
  举报不上报行为事件（隐藏与举报走权威接口，见后端 `ADS-026`、`ADS-030`）。

## 广告卡片

- 与帖子卡片同构，便于视觉一致；用以下差异明确区分广告（`FX-100`、`FQ-010`）：
  - 头部显示广告主名称与 `FBadge` 文本「广告」，配图标，不只依赖颜色；
  - 去掉点赞、评论与标签区；
  - 底部为 CTA 行：始终显示落地页域名，以及 CTA 按钮。
- 卡片整体语义标签为「广告，由某某推广」。右上角溢出菜单提供「为什么看到这条广告」「隐藏」「举报」，
  图标按钮都有可访问名称与 tooltip（`FQ-004`）。
- 点击卡片或 CTA 先记点击事件，再用 `url_launcher` 外部打开过审落地页（`FX-102`），复用
  `lib/features/assistant/presentation/research/assistant_research_source_card.dart` 中已有的安全外链写法，不内嵌网页。
  域名始终显示在 CTA 行，因此打开前不再弹确认框；打开失败时提示目标域名。
- 样式只在 `lib/core/theme/app_theme.dart` 增加广告标识与 CTA 的令牌，覆盖亮暗主题。
  `test/architecture/forui_migration_test.dart` 禁止页面引入 Material 组件词，标识用 `FBadge` 而非 Chip。
- 广告素材经同源 `/xbh-media/` 提供，满足根仓反代 CSP 的 `img-src`。

## 曝光与点击

- `BehaviorTracker`（`lib/features/behavior/application/behavior_tracker.dart`）增加目标类型参数，
  帖子继续传 `post`，广告传 `ad`（`FX-104`）。
- 曝光去重键从 `<requestId>:<postId>` 改为 `<requestId>:<targetType>:<targetId>`。读取持久化键时，两段的
  旧格式按 `post` 解释，避免升级后重复上报帖子曝光。
- 广告卡片沿用 `post_card.dart` 的 50% 可见、连续 1 秒判定，position 取 afterPosition；只上报曝光与点击，
  不上报停留。事件仍进入现有持久队列（`lib/features/behavior/data/behavior_event_queue.dart`）。

## Mock

`lib/mock/mock_discovery.dart` 在收到 `adSlots=1` 时为每页返回两个确定性的广告槽位，并提供格式错误槽位
的开关 `mockSponsoredMalformed`，用于覆盖 `FX-103` 的失败分支（`FX-070`）。种子帖子只有 8 篇，Mock 槽位放在
本页第 3、7 个自然条目之后（后端为第 4、12 个）。广告主、广告、私有素材与审核接口集中在
`lib/mock/mock_ads.dart`，提供同形数据：用户 1 是已过审广告主并拥有 reviewer、qa 角色；广告含被拒（可申诉）
与举报成立后下线（可申诉）的样例；审核队列预置首次审核、质检、举报、回扫与申诉，以及提交时返回持有失效（7001）、
任务作废（7002）的任务；广告写入校验 expectedRevision 与幂等键，举报按身份去重并隐藏，申诉按与后端相同的规则
判定可申诉版本、重复申诉返回 7106。

## 广告主控制台

覆盖 `FX-110`，路由均需认证：

- `/ads`：广告列表、审核状态与投放状态。
- `/ads/new`、`/ads/:adId/edit`：创建与编辑，提交带 expectedRevision 与幂等键。版本冲突沿用帖子编辑的
  保留输入处理。编辑已过审广告时显示提示：「审核期间继续投放上一过审版本」。
- `/ads/:adId`：详情，展示政策码对应的本地化原因（按投放状态标题为未通过、暂停或下线原因）、暂停与下线原因
  （回扫、质检、举报）、最新 revision 与过审快照的差异，以及申诉入口（每个 revision 一次）。
- `/ads/advertiser`：申请广告主、上传与提交资质；素材与证件走现有 multipart 上传通道，目标为 ad-rpc 的私有
  素材接口 `/api/v2/ads/assets/{creative|document}`（2 MiB 上限，编辑时经 `/api/v2/ads/assets/{assetId}`
  读取本人素材预览）。素材与证件上传按「文件名 + 大小 + 内容摘要」指纹复用幂等键：重新选中同一文件重试沿用
  原键，换文件换新键，成功或收到业务错误码后作废。资质有效期以 `YYYY-MM-DD` 输入，按当日 UTC 结束时刻提交。

申诉：只在广告视图的 `appealable` 为真时显示按钮（「对未通过的 rN 申诉」或「对下线的 rN 申诉」），二次确认说明
每个版本只能申诉一次、由另一名审核员复审且结论为最终结论，确认后经 `POST /api/v2/ads/{adId}/appeal` 提交并刷新
详情；申诉中显示「rN 申诉复审中」且不可编辑。幂等键在无错误码的网络失败重试时复用，收到业务错误后作废；7106
提示「当前版本不可申诉」并刷新。回扫暂停时额外提示「政策回扫后暂停投放，等待人工复审」。

实现调整：只有已过审广告主显示「新建广告」，否则提示审核通过后才能创建（后端返回 7101）。客户端按后端限制预先校验标题 1～100、正文 1～500、
CTA 1～32 字符与 https 落地页，最终以服务端为准；常见业务错误码（7101、7103～7105、7107、2007、2008）映射为
中文提示。

政策码到中文说明的映射集中维护在 `lib/features/ads/presentation/ad_labels.dart`，未知政策码显示原始代码而不报错；
工作台与详情页优先使用 `/api/v2/ads/policies` 返回的标题，请求失败时退回本地映射。

## 审核工作台

覆盖 `FX-111`、`FX-113`：

- `/review`：显示本人授权的市场与语言、待处理数量，以及「领取下一单」。
- `/review/tasks/:taskId`：
  - 快照：文案、经鉴权接口读取的图片，以及纯文本落地页地址（高亮域名，不自动打开）。
  - 机审证据：逐阶段展示组件版本、结果、原因、耗时与输出 JSON 的键值；组件版本含 `stub` 时标注「占位」，
    影子阶段标注「影子」。
  - 政策定义与结论表单：拒绝时必须多选政策码；可勾选「提名为相似违规种子」（需另一名审核员确认）。种子库的
    确认与退役界面不在本期范围。
- **持有**：页面显示剩余时间；剩余 2 分钟时提示一次续期，也可手动续期或放弃。提交、续期或放弃返回持有失效
  （7001）、任务作废（7002）、已有结论（7004）或无权限（7003）时，任务进入只读状态，说明原因并提供「返回
  队列」，不自动重试。幂等键按「持有代次 + 结论 + 政策码 + 备注 + 提名」指纹生成：没有错误码的网络失败再次
  提交时复用，服务端返回业务错误后作废。
- **质检、申诉、举报与回扫**：任务以「质检」「申诉」「举报」「回扫」文字标签区分（`FX-113`）。质检与申诉展示原
  结论（申诉的原结论是被申诉的拒绝）；转人审原因本地化展示（如回扫的「政策回扫判定疑似违规，广告已暂停投放」）；
  举报任务显示优先级；四类任务各以提示说明结论的业务效果：回扫拒绝即下线、通过即恢复，举报拒绝表示举报成立并
  下线，申诉结论为最终结论，质检违规立即下线。
- **移动端**：单列布局，证据分段折叠，满足 `FQ-005`。

## 入口与守卫

覆盖 `FX-112`：

- 入口在个人页的「商业」分组与桌面侧栏（`lib/features/feed/presentation/widgets/feed_side_rail.dart`）。
  主导航保持 5 项。广告主控制台对已认证用户可见，审核工作台只对 reviewer、qa 或 qualification_reviewer
  可见（`policy_admin` 只管理政策，不进入工作台）。
- 角色来自登录后请求的审核员信息接口，存放在 Riverpod provider（`reviewerAccessProvider`）中；应用回到前台
  （`MainShell` 中的 `ReviewerAccessRefreshBinding`）或审核接口返回 7003 时刷新。
- `/review*` 在非审核员访问时显示无权限页；服务端仍是唯一权限依据。

## 接口与 SDK

后端在 `openapi.yaml` 新增接口后，用 `tools/sync_gateway_sdk.py` 同步 `vendor/sdk_source` 与 `lib/sdk`，
并以 `make sdk-check BACKEND_API=<已核验 openapi.yaml>` 检查（`FQ-011`、`FQ-002`）。推荐流仍由
repository 手写解析，与现状一致。

## 验证

- 单元：广告槽位解析与合并、自然内容位置计数、曝光去重键迁移、政策码映射。
- Widget：广告卡片亮暗主题与可访问标签（`test/helpers/forui_test_builder.dart`），隐藏失败恢复，工作台
  持有失效提示。
- Mock 契约测试与浏览器截图（移动与桌面）；后端投放就绪后补真实联调证据。各 scope 分别记录。

## 分期

后端 W1～W4 已提供广告主、审核与投放接口，W5 完成本页客户端实现。后端 W6 提供举报与申诉接口及举报、回扫、
申诉任务后，已补齐 `FX-101` 的举报入口、`FX-110` 的申诉入口与 `FX-113` 的任务展示；与真实后端的联调证据尚未取得。
