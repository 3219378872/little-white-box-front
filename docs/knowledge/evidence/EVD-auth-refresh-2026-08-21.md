---
id: EVD-auth-refresh-2026-08-21
layer: evidence
title: 双令牌被动刷新对齐 2026-08-21
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-010
  - FQ-002
  - FQ-007
updated_at: 2026-08-21
observed_commit: cae6e7391126a16105dd07aee52a18f35c91358b
---

# 双令牌被动刷新对齐 2026-08-21

## 范围与环境

同步后端提交 `d713fd3`（双 token 会话：access 30 分钟、refresh 7 天一次性轮换，
`POST /api/v1/auth/refresh`）到 Flutter 客户端。覆盖：SDK 再生成、登录/注册保存
refreshToken、共享 transport 被动刷新 + single-flight + 重试一次、multipart 与 Assistant SSE
接入同一刷新入口、Mock router 令牌对与 refresh 路由。工作树 `.worktree/task-auth-refresh-token`。

对照后端观察提交为工作区 `little-white-box-content-community` `main@d713fd3`
（另含 `be971f4` 公开用户路由挂 OptionalAuth，前端已带 Bearer 自动受益，无需改码）。

## 命令与结果

```bash
python3 tools/sync_gateway_sdk.py --api <backend>/app/gateway/gateway.api
# lib/sdk 与 vendor/sdk_source 的 gateway.dart 同步新增 RefreshTokenReq/Resp、
# POST /auth/refresh、LoginResp/RegisterResp.refreshToken；diff 仅含本次契约变更
flutter analyze --no-pub
# 无 error（剩余为存量 warning/info）
flutter test
# 171 个测试全部通过（含新增 token_refresh_test、auth_notifier_test 与扩展的 mock_auth_test）
make knowledge-check
# 通过
```

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-010` | 启动恢复仍按 `jwt_decoder` 校验 userId，无效即清理；认证错误时 transport 先以 refreshToken 换发并恰好重试一次（`test/sdk/api/token_refresh_test.dart`：成功轮换重试、并发合并为一次换发、换发被拒清空会话并触发 `onSessionInvalid`、无 refreshToken 不换发、非认证码不触发）；换发被拒后 `AuthNotifier.onSessionExpired` 同步内存态并由 GoRouter redirect 到登录页 |
| `FQ-002` | v1/v2 共享传输层、multipart adapter 与 Assistant SSE 三处入口统一复用 `refreshSessionTokens`；Bearer 契约不变；`buildStoredTokens` 统一双令牌落盘（`exp` 解析见 jwt 扩展） |
| `FQ-007` | 新增测试不依赖 Forui 主题或 Widget 泵送，可在独立路径运行 |

## 未证明范围

- 未连接真实网关联调刷新链路（30 分钟过期后的实际换发待联调验证）。
- 规格 `FX-010` 原文未提及刷新语义；本页把被动刷新记录为实现层策略，未改动已批准规格文本。
- 验证码限流（后端 `ebcc929`）未在前端做专门提示，仅透传业务错误。
