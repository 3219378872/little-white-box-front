---
id: EVD-client-relative-api-2026-08-18
layer: evidence
title: 前端 API 改为相对路径 2026-08-18
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FQ-001
  - FQ-002
  - FQ-007
  - FQ-008
updated_at: 2026-08-18
observed_commit: 8d01b7598c1b5ed47cbc0bf24ad4c1cd64ba2163
---

# 前端 API 改为相对路径 2026-08-18

## 范围与环境

核验默认请求 URI 为相对路径 `/api/...`，以及显式 `SERVER_HOST` 仍可拼绝对地址。工作树
`.worktree/task-relative-api-paths`。

## 命令与结果

```bash
flutter test test/sdk/vars/api_uri_test.dart test/features/assistant/data/assistant_repository_test.dart
# 6 tests passed
flutter test
# 126 tests passed
flutter analyze
# 无 error；22 条既有 info
make knowledge-check
# OK (9 formal documents, 25 requirements, 43 local links)
```

## 条款证据

| 条款 | 直接证据 | 结论 |
| --- | --- | --- |
| `FQ-002` | `lib/sdk/vars/vars.dart` 的 `apiUri`；`lib/sdk/api/api.dart`、multipart、Assistant SSE 共用 | 相对路径集中在 transport |
| `FQ-001` | feature 仍走 repository，不直接拼 host | 页面不承担 URL 拼接 |
| `FQ-007` | `api_uri_test` 覆盖空 host 与绝对 host | 单测覆盖解析 |
| `FQ-008` | 本页与 IMP/DES 同步 | 知识闭环 |

## 未证明范围

- 未在浏览器对真实网关走同源反代做端到端点击。
- 原生端未验证必须提供 `SERVER_HOST` 的失败路径。
