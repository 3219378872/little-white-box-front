---
id: EVD-mock-gateway-align-2026-08-20
layer: evidence
title: Mock API 对齐网关契约 2026-08-20
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-070
  - FQ-002
  - FQ-003
  - FQ-007
  - FQ-008
updated_at: 2026-08-20
observed_commit: c202150884df8b57c5d82a1179585d8f0544ff95
---

# Mock API 对齐网关契约 2026-08-20

## 范围与环境

核验仓库内 Mock router 与后端 `app/gateway/gateway.api` 及
`rest_decision_table_test.go` 的 HTTP 契约对齐：路径/动词、成功 payload 形状、
`{code, message}` 错误信封、Bearer JWT、可选鉴权 `x-auth-state`、Feed 扁平条目、
关注关系、行为白名单。工作树 `.worktree/task-align-mock-api`。

对照后端观察提交以该工作区 `little-white-box-content-community` 当前 `gateway.api`
为准。

## 命令与结果

```bash
dart analyze lib/mock test/mock lib/sdk/api/api.dart lib/core/api/api_adapter.dart
# 无 error；仅生成 SDK / 既有文档 info
flutter test test/mock
# 全部通过
flutter test
# 全部通过
make knowledge-check
```

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-070` | `mock_router.dart` 按网关路由表分发；成功体不再包 `{code,desc,data}`；JWT 路由无 Bearer 回 401/`1006`；推荐/关注条目为扁平 `RecommendFeedItem`/`FeedItem`；`test/mock/mock_gateway_contract_test.dart` 覆盖 health、鉴权态、写路径 401、私密收藏 `3007` |
| `FQ-002` | v1 `apiPost`/`multipart` 补 `Bearer`，与 `V2ApiClient` 和网关 JWT 中间件一致；workaround 留在 SDK 副本与 adapter，不改页面 |
| `FQ-003` | Mock 错误只返回 `{code, message}` 与 `errx` HTTP 状态 |
| `FQ-007` | Mock 契约、v2 transport、点赞、登录测试在 Forui 无关路径上可独立运行 |
| `FQ-008` | 本页与 IMP 同步 |

## 未证明范围

- 未对真实网关重跑 `rest_decision_table_test` 或浏览器联调。
- Mock 不模拟 RPC 失败、搜索降级、签名校验的 HS256 JWT、评论作者批量补全缺口。
- 种子关注关系（用户 1 关注 2 和 3）和开发密码 `123456` 是 Mock 数据，不是生产账号。
