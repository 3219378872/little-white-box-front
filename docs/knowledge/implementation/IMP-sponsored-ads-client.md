---
id: IMP-sponsored-ads-client
layer: implementation
title: 付费广告与审核客户端实现映射
status: active
owner: agent
code_paths:
- lib/features/feed
- lib/features/behavior
- lib/features/profile
- lib/core/router
- lib/core/theme
- lib/mock
updated_at: 2026-10-01
---

# 付费广告与审核客户端实现映射

推荐流广告、广告主控制台与审核工作台尚无实现。`code_paths` 暂列将被修改的既有入口，新功能模块落地后
补充。全部条款在取得当前提交上的有效证据前保持 `unknown`。计划见
[DES-sponsored-ads-client](../design/DES-sponsored-ads-client.md) 的分期。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-100 | DES-sponsored-ads-client | unknown | gap: 尚未实现（依赖后端投放契约，计划 W5）。 |
| FX-101 | DES-sponsored-ads-client | unknown | gap: 尚未实现（依赖后端投放契约，计划 W5）。 |
| FX-102 | DES-sponsored-ads-client | unknown | gap: 尚未实现（依赖后端投放契约，计划 W5）。 |
| FX-103 | DES-sponsored-ads-client | unknown | gap: 尚未实现（依赖后端投放契约，计划 W5）。 |
| FX-104 | DES-sponsored-ads-client | unknown | gap: 尚未实现（依赖后端投放契约，计划 W5）。 |
| FX-105 | DES-sponsored-ads-client | unknown | gap: 尚未实现（依赖后端投放契约，计划 W5）。 |
| FX-110 | DES-sponsored-ads-client | unknown | gap: 尚未实现（依赖后端广告主接口，计划 W3～W5）。 |
| FX-111 | DES-sponsored-ads-client | unknown | gap: 尚未实现（依赖后端审核接口，计划 W3～W5）。 |
| FX-112 | DES-sponsored-ads-client | unknown | gap: 尚未实现（依赖后端审核员信息接口，计划 W3～W5）。 |
| FX-113 | DES-sponsored-ads-client | unknown | gap: 尚未实现（依赖后端质检与申诉任务，计划 W5～W6）。 |
| FQ-010 | DES-sponsored-ads-client | unknown | gap: 尚未实现，待广告界面落地后验证亮暗与移动、桌面场景。 |
| FQ-011 | DES-sponsored-ads-client | unknown | gap: 尚未实现，待后端接口进入 `openapi.yaml` 后同步 SDK。 |
