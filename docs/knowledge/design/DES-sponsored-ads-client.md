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
视觉基准沿用 [DES-presentation-client](DES-presentation-client.md)。截至 2026-10-01 尚无实现，逐条状态见
[IMP-sponsored-ads-client](../implementation/IMP-sponsored-ads-client.md)。

## 推荐流广告

- **请求**（`FX-105`）：推荐请求增加 `adSlots: 1`。后端只在声明时返回可选的 `sponsored` 数组，每项包含
  `slotId`、`afterPosition` 与 `ad`（广告主名称、标题、正文、CTA、落地页与域名、图片、标识与 `why`）。
- **解析**（`FX-103`、`FQ-011`）：`FeedRepository` 对 `items` 保持现有的严格解析
  （`lib/features/feed/data/feed_repository.dart`）。`sponsored` 由独立解析器逐槽解析，单槽格式错误
  只丢弃该槽并计数，不抛出页面错误。
- **模型**：`FeedEntry`（`lib/features/feed/data/feed_models.dart`）改为密封类型：自然内容条目保留现有
  post 与归因上下文；广告条目包含 slotId、afterPosition、ad 与归因上下文。
- **合并**：页面解析后，把广告条目插到 position 等于 afterPosition 的自然条目之后；找不到时丢弃该槽。
  帖子去重仍只比较自然条目的 post id。`positionOffset` 只累计自然条目，避免广告挤偏帖子的回退位置。
  列表 key 为 `ad-<requestId>-<slotId>`。
- **隐藏与举报**（`FX-101`）：隐藏先在本地移除，再调用隐藏接口，失败时按原位置恢复并提示。举报弹出
  原因选择后提交。「为什么看到这条广告」以底部面板展示市场、场景与是否个性化。

## 广告卡片

- 与帖子卡片同构，便于视觉一致；用以下差异明确区分广告（`FX-100`、`FQ-010`）：
  - 头部显示广告主名称与 `FBadge` 文本「广告」，配图标，不只依赖颜色；
  - 去掉点赞、评论与标签区；
  - 底部为 CTA 行：始终显示落地页域名，以及 CTA 按钮。
- 卡片整体语义标签为「广告，由某某推广」。右上角溢出菜单提供「为什么看到这条广告」「隐藏」「举报」，
  图标按钮都有可访问名称与 tooltip（`FQ-004`）。
- 点击卡片或 CTA 先记点击事件，再用 `url_launcher` 外部打开过审落地页（`FX-102`），复用
  `lib/features/assistant/presentation/assistant_research_widgets.dart` 中已有的安全外链写法，不内嵌网页。
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
的开关，用于覆盖 `FX-103` 的失败分支（`FX-070`）。广告主与审核接口在 Mock 中提供同形数据：领取、续期、
提交成功，以及持有失效、任务作废两种失败。

## 广告主控制台

覆盖 `FX-110`，路由均需认证：

- `/ads`：广告列表、审核状态与投放状态。
- `/ads/new`、`/ads/:adId/edit`：创建与编辑，提交带 expectedRevision 与幂等键。版本冲突沿用帖子编辑的
  保留输入处理。编辑已过审广告时显示提示：「审核期间继续投放上一过审版本」。
- `/ads/:adId`：详情，展示政策码对应的本地化原因、最新 revision 与过审快照的差异，以及申诉入口
  （每个 revision 一次）。
- `/ads/advertiser`：申请广告主、上传与提交资质；素材与证件走现有 multipart 上传通道，目标为私有存储接口。

政策码到中文说明的映射集中维护在一处，未知政策码显示原始代码而不报错。

## 审核工作台

覆盖 `FX-111`、`FX-113`：

- `/review`：显示本人授权的市场与语言、待处理数量，以及「领取下一单」。
- `/review/tasks/:taskId`：
  - 快照：文案、经鉴权接口读取的图片，以及纯文本落地页地址（高亮域名，不自动打开）。
  - 机审证据：命中规则、相似种子、各 issue 分数；占位模型分数标注「占位」。
  - 政策定义与结论表单：拒绝时必须多选政策码。
- **持有**：页面显示剩余时间；剩余 2 分钟时提示续期，也可手动续期或放弃。提交返回持有失效或任务作废时，
  明确说明并回到队列，不自动重试。只有网络重试复用同一幂等键。
- **质检与申诉**：任务以「质检」「申诉」标签区分，并展示原结论（`FX-113`）。
- **移动端**：单列布局，证据分段折叠，满足 `FQ-005`。

## 入口与守卫

覆盖 `FX-112`：

- 入口在个人页的「商业」分组与桌面侧栏（`lib/features/feed/presentation/widgets/feed_side_rail.dart`）。
  主导航保持 5 项。广告主控制台对已认证用户可见，审核工作台只对 reviewer 或 qa 可见。
- 角色来自登录后请求的审核员信息接口，存放在 Riverpod provider 中；应用回到前台或审核接口返回无权限时刷新。
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

后端 W1～W3 提供广告主与审核接口后，控制台与工作台可提前开发；推荐流卡片与曝光依赖后端 W4 的投放
契约，计划在 W5 完成联调。
