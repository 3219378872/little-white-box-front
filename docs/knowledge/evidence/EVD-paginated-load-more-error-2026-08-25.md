---
id: EVD-paginated-load-more-error-2026-08-25
layer: evidence
title: 加载更多失败可见且可重试 2026-08-25
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-031
  - FX-040
scope:
  - static
  - unit
commands:
  - make analyze
  - make test
  - make test-coverage
observed_commit: af4aa7b381f32d072137d9f0c7a4d0f7094dbe46
updated_at: 2026-08-25
---

# 加载更多失败可见且可重试 2026-08-25

## 范围与环境

修复分页「加载更多」失败被静默吞掉的问题：资料页帖子/收藏列表（`UserPostList`）在有数据时
忽略 error，坏游标（服务端 code=2）触底后无限重发同一游标且无任何提示；共享组件
`PaginatedListView` 声明了 `error` 字段但 build 从不使用（会话列表同样不可见）。对照组：
feed 主路径早已有错误文案 + 重试 footer 的正确模式。

改动：两处列表尾部槽统一三态（加载中 spinner / 失败文案 + 重试按钮 / 没有更多了）；
`PaginatedListView` 空列表遇错误改渲染 `ErrorView`；滚动监听在失败态挂起自动翻页，
重试按钮显式触发（notifier 侧 `loadNextPage` 与 feed/message 一致在重试时先清错，
复用原游标不跳页）；`UserPostsNotifier.loadNextPage` 同步补 `clearError`。

## 命令与结果

在前端 `task/paginated-error-surface` 工作树：

```text
make analyze        # No issues found!
make test           # +276: All tests passed!
make test-coverage  # total: 4797/6488 lines (73.9%) >= COVERAGE_MIN=70, exit 0
```

新增测试：notifier 层失败保留 items/cursor/hasMore、重试复用原游标 `['','c2','c2']`
并清错追加；widget 层 footer 渲染重试可点、失败态下滚动不触发 onLoadMore、
空列表 + 错误渲染 ErrorView 而非「暂无内容」。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| FX-031 | 用户资料帖子列表分页：翻页失败不再伪装成「没有更多」，文案 + 重试可恢复；
坏游标不再无限循环请求。 |
| FX-040 | 会话列表（PaginatedListView）：加载更多失败对用户可见、可点重试；
error 字段从声明变为实际参与渲染。 |
