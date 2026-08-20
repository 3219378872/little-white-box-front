---
id: EVD-search-post-author-2026-08-20
layer: evidence
title: 搜索帖子作者身份 2026-08-20
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-022
updated_at: 2026-08-20
observed_commit: 6121f49985bcb4edb3ebd6a65d7e4bfe2dee40c3
---

# 搜索帖子作者身份 2026-08-20

## 范围与环境

核验搜索结果解析并展示 `authorId`/`authorName`/`authorAvatar`，以及头像进入作者资料。
后端工作树 `task/search-post-author` 为搜索契约增加了对应字段。

## 命令与结果

在前端 `task/search-post-author` 工作树：

```text
dart analyze lib/features/search test/features/search
flutter test test/features/search
```

`dart analyze` 仅有搜索仓库既有 info；`flutter test test/features/search` 退出码 0，5 个测试通过，
含结果打开帖子与点击头像打开作者。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-022` | `SearchPostResult` 解析作者字段；搜索页帖子项展示头像与作者名；Mock `/api/v2/search` 回填同一字段 |

## 未证明范围

未在浏览器对真实网关重启后的 `/api/v2/search` 做端到端点击验证。雪花 ID 在 Flutter Web 上的
数值精度不在本证据范围。
