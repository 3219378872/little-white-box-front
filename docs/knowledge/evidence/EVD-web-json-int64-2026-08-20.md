---
id: EVD-web-json-int64-2026-08-20
layer: evidence
title: Web JSON 雪花 ID 精度 2026-08-20
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-001
  - FX-031
  - FQ-002
  - FQ-007
updated_at: 2026-08-20
observed_commit: 12f9c213803612df3306d62ada7317606c47e536
---

# Web JSON 雪花 ID 精度 2026-08-20

## 范围与环境

核验 Flutter Web 打开推荐流雪花 ID 帖子时，详情请求使用完整十进制，而不是 IEEE-754 舍入后的 ID。
现场网关对 `348206251022356480`（继续联调帖）返回 200，对 JS `toString()` 得到的
`348206251022356500` 返回 `2001 内容不存在`。

工作树：`task/web-int64-json-ids`。

## 命令与结果

```text
dart analyze lib
flutter test
make knowledge-check
```

`dart analyze lib` 无 error。`flutter test` 退出码 0，142 个测试通过，含
`test/core/api/json_int64_test.dart` 对 `348206251022356480` 的编解码与 `apiGet` 路径。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-001`/`FX-031` | 推荐卡片导航 `/post/${jsonInt64Id(post.id)}`；详情路由不再 `int.parse`；`GetPost` 路径带完整十进制 |
| `FQ-002` | 编解码在 `lib/core/api/json_int64.dart`，由应用拥有的 `lib/sdk/api/api.dart` 调用；生成模型 ID 放宽由 `tools/sync_gateway_sdk.py` 固定步骤完成 |
| `FQ-007` | 上述 analyze/test 在本工作树执行 |

## 未证明范围

未在浏览器对正在运行的 `:3003` 开发服热重载后点开「继续联调帖」做端到端点击。合并并重启
`make dev-real` 后才能在现场网关上复核。后端仍把 ID 编成 JSON number；本证据只证明前端可以在不改
契约的前提下保住十进制。
