---
id: EVD-feed-pagination-ux-2026-08-20
layer: evidence
title: Feed 分页结束与加载更多失败 2026-08-20
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-020
  - FX-021
  - FQ-006
updated_at: 2026-08-20
observed_commit: bd2ebf158a086ebeecfc6dcc4f13bf112350c008
---

# Feed 分页结束与加载更多失败 2026-08-20

## 范围与环境

核验推荐/关注流滑近底部继续用游标加载更多，分页结束显示「没有更多了」，加载更多失败时保留已有
条目并在底部提供重试。不改变后端推荐快照大小。

## 命令与结果

在前端 `task/feed-pagination-ux` 工作树：

```text
dart analyze lib/features/feed test/features/feed
flutter test test/features/feed
python3 tools/knowledge_base.py check
```

`dart analyze` 无 issue；`flutter test test/features/feed` 退出码 0，26 个测试通过，含游标下一页、
溢出列表滚动加载、加载更多失败重试，以及结束 footer。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-020` | Feed 在剩余滚动空间 ≤200px 时 `loadMore()`；`hasMore=false` 时显示「— 没有更多了 —」 |
| `FX-021` | 关注 tab 共用同一 footer 与加载更多路径；匿名关注仍为登录引导 |
| `FQ-006` | 加载更多失败保留已加载条目并展示底部错误与重试；进行中显示进度 |

## 未证明范围

未在真实网关浏览器中滑到底核对结束 footer。推荐候选快照耗尽后不再有下一页，属于后端召回窗口，
不在本次前端变更范围。
