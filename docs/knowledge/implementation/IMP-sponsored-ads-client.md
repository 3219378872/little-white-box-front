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
- lib/mock
updated_at: 2026-10-01
---

# 付费广告与审核客户端实现映射

2026-10-01 W5 已实现推荐流广告槽位、广告卡片与曝光点击、广告主控制台、审核工作台、入口守卫与 Mock。
`make format-check`、`make analyze`、`make test`（722 项）通过，新增代码行覆盖率约 90%，但尚未形成
当前提交上的 EVD 覆盖组，因此全部条款保持 `unknown`。举报、申诉依赖后端 W6 接口，相关条款另列缺口。
设计取舍见 [DES-sponsored-ads-client](../design/DES-sponsored-ads-client.md)。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-100 | DES-sponsored-ads-client | unknown | gap: 已实现带「广告」文字与图标标识、广告主名称与可访问标签的广告卡片，按 afterPosition 插入；Widget 与 Mock 页面测试通过，尚无 EVD 覆盖组。 |
| FX-101 | DES-sponsored-ads-client | unknown | gap: 已实现「为什么看到这条广告」与隐藏（本地先移除、失败按原位置恢复并提示）；举报入口缺失，后端举报接口属于 W6 尚未进入 `openapi.yaml`；尚无 EVD 覆盖组。 |
| FX-102 | DES-sponsored-ads-client | unknown | gap: 已实现 CTA 行常显落地页域名、只接受 https 且域名与地址一致的落地页、以外部方式打开；Widget 测试通过，尚无 EVD 覆盖组。 |
| FX-103 | DES-sponsored-ads-client | unknown | gap: 已实现逐槽容错解析与计数、广告不参与帖子去重、位置只按自然条目计数；单元与 Mock 页面测试通过，尚无 EVD 覆盖组。 |
| FX-104 | DES-sponsored-ads-client | unknown | gap: 已实现 50% 可见连续 1 秒的广告曝光、`ad` 目标类型的曝光/点击/隐藏上报与 `<requestId>:<targetType>:<targetId>` 去重键（旧两段键按帖子迁移）；单元与 Widget 测试通过，尚无 EVD 覆盖组。 |
| FX-105 | DES-sponsored-ads-client | unknown | gap: 已实现推荐请求声明 `adSlots=1` 与 Mock 的成功、格式错误槽位、隐藏分支；单元与 Mock 契约测试通过，尚无 EVD 覆盖组。 |
| FX-110 | DES-sponsored-ads-client | unknown | gap: 已实现申请广告主、上传证件并提交资质、创建与编辑广告、上传创意图片、送审、状态与政策码原因、过审版本差异与「审核期间继续投放上一过审版本」提示；申诉入口缺失，后端申诉接口属于 W6；尚无 EVD 覆盖组。 |
| FX-111 | DES-sponsored-ads-client | unknown | gap: 已实现按授权队列领取、快照与机审证据、政策定义、拒绝必选政策码、续期与放弃、持有失效与任务作废的只读提示且不重复提交；控制器、Widget 与 Mock 测试通过，尚无 EVD 覆盖组。 |
| FX-112 | DES-sponsored-ads-client | unknown | gap: 已实现个人页「商业」分组与桌面侧栏入口、按审核员信息接口显示工作台、`/review*` 非审核员无权限页、7003 与回到前台时刷新角色；Widget 测试通过，尚无 EVD 覆盖组。 |
| FX-113 | DES-sponsored-ads-client | unknown | gap: 已实现质检与申诉任务的文字标签与原结论展示，质检任务经 Mock 验证；申诉任务依赖后端 W6，尚未联调；尚无 EVD 覆盖组。 |
| FQ-010 | DES-sponsored-ads-client | unknown | gap: 广告界面复用 Forui 与 `app_theme.dart` 令牌，亮暗主题 Widget 测试通过；尚无移动与桌面浏览器截图证据。 |
| FQ-011 | DES-sponsored-ads-client | unknown | gap: SDK 已于 a912526 同步，广告槽位逐槽容错解析与帖子严格解析相互独立；单元测试通过，尚无 EVD 覆盖组。 |
