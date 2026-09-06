---
id: EVD-favorites-reload-2026-08-20
layer: evidence
title: 收藏列表进入时重新拉取 2026-08-20
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-031
  - FQ-006
scope:
  - static
  - unit
commands:
  - flutter test test/features/profile
observed_commit: ccfb538003128c8e5ca953a547a3598252de4fd6
updated_at: 2026-08-20
---

# 收藏列表进入时重新拉取 2026-08-20

## 范围与环境

核验个人资料「收藏」tab 每次成为当前页时重新请求第一页，并从其它路由返回且仍停在收藏 tab
时同样重新请求。请求代次丢弃被刷新打断的首屏响应。

## 命令与结果

在前端 `task/favorites-reload-on-enter` 工作树：

```text
dart analyze lib/core/router lib/features/profile test/features/profile
flutter test test/features/profile
python3 tools/knowledge_base.py check
```

`dart analyze` 仅有测试里一处 info，已改为合法 `_` 占位；`flutter test test/features/profile`
退出码 0，13 个测试通过，含收藏 tab 再次进入与从推入路由返回时重新拉取。`knowledge-check`
退出码 0。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-031` | `UserPostList` 在收藏 tab 变为 `active`、以及 `didPopNext` 时 `refresh()`；资料页把收藏页 `active` 绑到当前 tab |
| `FQ-006` | `UserPostsNotifier` 为首屏加载与刷新增加 generation；较新 refresh 丢弃进行中的 `loadFirstPage` |

## 未证明范围

未在真实网关浏览器中走收藏→详情→返回的端到端点击。他人资料公开收藏 tab 与本人路径相同，未单独
做 Widget 测试。
