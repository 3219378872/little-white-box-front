---
id: EVD-watch-cannot-self-2026-09-06
layer: evidence
title: Watch 盯自己错误与小 ID JSON 编码 2026-09-06
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-086
  - FQ-002
  - FQ-003
  - FQ-007
scope:
  - static
  - unit
commands:
  - flutter test
  - make test
observed_commit: 972a206d0f27d3c97a46d4cb7d2e5d7e5b1831b2
updated_at: 2026-09-06
---

# Watch 盯自己错误与小 ID JSON 编码 2026-09-06

## 范围与环境

验证两件事：本人帖「盯作者 / 盯本帖修订」展示「不能关注自己的动态」且不发创建请求；
`jsonInt64JsonValue` 把小 ID 和雪花 ID 都编成 JSON number，避免网关 `int64` 解析成通用参数错误。

工作树：`task/watch-cannot-self`。

## 命令与结果

```text
dart analyze lib/core/api/json_int64.dart lib/features/assistant/data/assistant_repository.dart \
  lib/features/message/data/message_repository.dart lib/features/post/presentation/post_detail_page.dart \
  lib/mock/mock_router.dart lib/core/api/error_codes.dart
flutter test test/core/api/json_int64_test.dart \
  test/features/assistant/data/assistant_repository_test.dart \
  test/features/post/presentation/post_detail_page_test.dart
```

`dart analyze` 无 issue。`flutter test` 退出码 0，36 项通过，含
`jsonInt64JsonValue emits numbers for small and snowflake ids`、
`createWatch sends targetId as a JSON number`、
`own posts show a self-watch error without creating a task`。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| FX-086 | 详情页作者等于当前用户时 toast「不能关注自己的动态」，`FakeAssistantSource.lastCreateCondition` 仍为 null |
| FQ-002 | `targetId: 1` 与雪花 ID 请求体均为 JSON number |
| FQ-003 | Mock 与真实错误码 6005 文案一致 |
| FQ-007 | 上述定向测试 |

## 未证明范围

未在本证据中跑全量 `make test` / 真实浏览器。根仓 e2e 与真实网关 6005 由编排仓记录。
