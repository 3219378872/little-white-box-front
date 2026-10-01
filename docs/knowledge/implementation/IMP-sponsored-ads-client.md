---
id: IMP-sponsored-ads-client
layer: implementation
title: 付费广告与审核客户端实现映射
status: active
owner: agent
code_paths:
- lib/features/feed
- lib/features/behavior
- lib/features/ads
- lib/features/review
- lib/features/profile
- lib/core/api/error_codes.dart
- lib/core/router
- lib/core/theme
- lib/core/widgets/app_section.dart
- lib/core/widgets/app_dialog.dart
- lib/mock
updated_at: 2026-10-01
---

# 付费广告与审核客户端实现映射

2026-10-01 W5 已实现推荐流广告槽位、广告卡片与曝光点击、广告主控制台、审核工作台、入口守卫与 Mock；同日随
后端 W6 补齐举报入口、申诉入口与举报、回扫、申诉任务展示，SDK 已从后端 `openapi.yaml` 同步。`make format-check`、
`make analyze`、`make test-coverage`（734 项，总行覆盖率 85.4%）通过，但尚未形成当前提交上的 EVD 覆盖组，
因此全部条款保持 `unknown`。
设计取舍见 [DES-sponsored-ads-client](../design/DES-sponsored-ads-client.md)。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-100 | DES-sponsored-ads-client | unknown | gap: 已实现带「广告」文字与图标标识、广告主名称与可访问标签的广告卡片，按 afterPosition 插入；Widget 与 Mock 页面测试通过，尚无 EVD 覆盖组。 |
| FX-101 | DES-sponsored-ads-client | unknown | gap: 已实现「为什么看到这条广告」、隐藏与举报（结构化原因、选择即提交；本地先移除、失败按原位置恢复并提示）；Widget 测试 `menu reports the ad with a structured reason` 与推荐流测试 `reporting removes the ad and thanks the user`、`a failed report restores the ad` 通过；未与真实后端联调；尚无 EVD 覆盖组。 |
| FX-102 | DES-sponsored-ads-client | unknown | gap: 已实现 CTA 行常显落地页域名、只接受 https 且域名与地址一致的落地页、以外部方式打开；Widget 测试通过，尚无 EVD 覆盖组。 |
| FX-103 | DES-sponsored-ads-client | unknown | gap: 已实现逐槽容错解析与计数、广告不参与帖子去重、位置只按自然条目计数；单元与 Mock 页面测试通过，尚无 EVD 覆盖组。 |
| FX-104 | DES-sponsored-ads-client | unknown | gap: 已实现 50% 可见连续 1 秒的广告曝光、`ad` 目标类型的曝光/点击/隐藏上报与 `<requestId>:<targetType>:<targetId>` 去重键（旧两段键按帖子迁移）；单元与 Widget 测试通过，尚无 EVD 覆盖组。 |
| FX-105 | DES-sponsored-ads-client | unknown | gap: 已实现推荐请求声明 `adSlots=1` 与 Mock 的成功、格式错误槽位、隐藏分支；单元与 Mock 契约测试通过，尚无 EVD 覆盖组。 |
| FX-110 | DES-sponsored-ads-client | unknown | gap: 已实现申请广告主、上传证件并提交资质、创建与编辑广告、上传创意图片、送审、状态与政策码原因（含暂停与下线原因）、过审版本差异、「审核期间继续投放上一过审版本」提示与申诉入口（`appealable` 驱动、二次确认、7106 提示）；页面测试 `an offline ad can be appealed once after confirming` 等通过；未与真实后端联调；尚无 EVD 覆盖组。 |
| FX-111 | DES-sponsored-ads-client | unknown | gap: 已实现按授权队列领取、快照与机审证据、政策定义、拒绝必选政策码、续期与放弃、持有失效与任务作废的只读提示且不重复提交；控制器、Widget 与 Mock 测试通过，尚无 EVD 覆盖组。 |
| FX-112 | DES-sponsored-ads-client | unknown | gap: 已实现个人页「商业」分组与桌面侧栏入口、按审核员信息接口显示工作台、`/review*` 非审核员无权限页、7003 与回到前台时刷新角色；Widget 测试通过，尚无 EVD 覆盖组。 |
| FX-113 | DES-sponsored-ads-client | unknown | gap: 已实现质检、申诉、举报与回扫任务的文字标签、原结论、本地化转人审原因与结论效果提示；页面测试覆盖质检、申诉、举报与回扫任务（Mock）；未与真实后端联调；尚无 EVD 覆盖组。 |
| FQ-010 | DES-sponsored-ads-client | unknown | gap: 广告界面复用 Forui 与 `app_theme.dart` 令牌，亮暗主题 Widget 测试通过；尚无移动与桌面浏览器截图证据。 |
| FQ-011 | DES-sponsored-ads-client | unknown | gap: SDK 已于 a912526 同步，广告槽位逐槽容错解析与帖子严格解析相互独立；单元测试通过，尚无 EVD 覆盖组。 |
