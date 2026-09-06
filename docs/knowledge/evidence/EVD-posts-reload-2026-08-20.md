---
id: EVD-posts-reload-2026-08-20
layer: evidence
title: 资料帖子列表进入时重新拉取 2026-08-20
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
observed_commit: 2ebbf44f5061624e3ab5f527e7990d99906e8e32
updated_at: 2026-08-20
---

# 资料帖子列表进入时重新拉取 2026-08-20

## 范围与环境

核验个人资料「帖子」tab 每次成为当前页时重新请求第一页，并从其它路由返回且仍停在帖子 tab
时同样重新请求，避免会话内旧缓存挡住刚发布的帖子。

## 命令与结果

在前端 `task/posts-reload-on-enter` 工作树：

```text
dart analyze lib/features/profile test/features/profile
flutter test test/features/profile
python3 tools/knowledge_base.py check
```

`dart analyze` 无 issue；`flutter test test/features/profile` 退出码 0，15 个测试通过，含帖子
tab 再次进入与从推入路由返回时重新拉取。`knowledge-check` 退出码 0。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-031` | `UserPostList` 对帖子与收藏共用 `_reloadIfActive()`：tab 变为 `active` 以及 `didPopNext` 时 `refresh()` |
| `FQ-006` | 沿用 `UserPostsNotifier` generation；进行中的首屏加载仍可挡住紧随其后的 refresh |

## 未证明范围

未在真实网关浏览器中走发布→个人中心的端到端点击。无收藏 tab 的他人资料路径未单独做 Widget 测试。
