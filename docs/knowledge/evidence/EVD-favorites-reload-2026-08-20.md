---
id: EVD-favorites-reload-2026-08-20
layer: evidence
title: 收藏列表进入时重新拉取 2026-08-20
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-031
  - FQ-006
updated_at: 2026-08-20
observed_commit: pending
---

# 收藏列表进入时重新拉取 2026-08-20

## 范围与环境

核验个人资料「收藏」tab 每次成为当前页时重新请求第一页，并从其它路由返回且仍停在收藏 tab
时同样重新请求。请求代次丢弃被刷新打断的首屏响应。

## 命令与结果

在前端 `task/favorites-reload-on-enter` 工作树记录实际命令与结果。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-031` | `UserPostList` 在收藏 tab 变为 `active`、以及 `didPopNext` 时 `refresh()`；资料页把收藏页 `active` 绑到当前 tab |
| `FQ-006` | `UserPostsNotifier` 为首屏加载与刷新增加 generation；较新 refresh 丢弃进行中的 `loadFirstPage` |

## 未证明范围

未在真实网关浏览器中走收藏→详情→返回的端到端点击。他人资料公开收藏 tab 与本人路径相同，未单独
做 Widget 测试。
