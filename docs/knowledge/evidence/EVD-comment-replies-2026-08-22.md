---
id: EVD-comment-replies-2026-08-22
layer: evidence
title: 评论楼中楼展开加载 2026-08-22
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-031
scope:
  - static
  - unit
commands:
  - flutter test test/features/comment/ test/features/post/
  - flutter test test/mock/
  - make test
  - make analyze
observed_commit: 647df1721b13ee8bb54d4401967942b7a5b83d0f
updated_at: 2026-08-22
---

# 评论楼中楼展开加载 2026-08-22

## 范围与环境

核验帖子详情页评论楼中楼的按需读取：列表内嵌前 3 条回复预览与 `replyCount`，
点击「共 N 条回复」即时渲染预览并同时拉取 `GET /api/v1/comments/:id/replies`
第一页全量替换，「加载更多回复」按页追加，「收起回复」折叠；对楼中楼内回复
时归一到顶级父评论并 @被回复用户。契约来自同级后端仓 23295da（语义缺口登记于
后端 PROP-20260822-comment-reply-thread，open）。

## 命令与结果

在前端 `task/comment-replies` 工作树：

```text
python3 tools/sync_gateway_sdk.py --api <后端仓>/app/gateway/gateway.api
flutter analyze --no-pub
flutter test test/features/comment/ test/features/post/   # 25 passed
flutter test test/mock/                                   # 24 passed
make test                                                 # 250 passed
```

- SDK 同步生成 `getCommentReplies` 与 `CommentItem.replyCount/replies`（递归类型），
  未手改生成文件。
- Repository 新增 `fetchReplies`，query 契约测试断言
  `/api/v1/comments/<id>/replies?page&pageSize`。
- Widget 测试：展开触发 replies 接口 page=1、5 条全量渲染且无「加载更多」（5≤10）、
  收起后隐藏。
- Mock 契约测试：replies 路由匿名可读且带 `x-auth-state: anonymous`；列表内嵌
  预览 ≤3 条、replies 接口 total=replyCount 且时间正序；回复楼中楼返回 404。

## 已知边界

- `make analyze` 在 main 基线即失败（20 个既有 lint，集中在生成 SDK 与无关文件）；
  本次生成的 `getCommentReplies` 按生成器原样带入 1 个同类
  `unnecessary_brace_in_string_interps`，禁改生成文件故不处理，未引入其他新告警。
- 真实网关联调待做（与 Mock 同路径，transport 可切换）；本证据基于仓库内
  Mock 契约与 fake 网关。
