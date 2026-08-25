---
id: EVD-auth-session-reset-2026-08-25
layer: evidence
title: 传输层认证失败同步内存会话态 2026-08-25
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-010
updated_at: 2026-08-25
observed_commit: 1135038
---

# 传输层认证失败同步内存会话态 2026-08-25

## 范围与环境

核验认证失效后的完整会话清理：access token 过期且无 refreshToken（旧版本会话、存储损坏）
时，传输层 `onAuthError` 只清 localStorage 不重置内存 `AuthNotifier`，路由守卫继续放行受保护页，
形成"已登录但全部报错"死区。DES-flutter-client「会话与令牌刷新」本就要求宿主用回调同步
`AuthNotifier` 内存态，实现层此前只做了一半。

修复：新增 `authTransportBindingProvider` 统一把 SDK 刷新被拒的 `onSessionInvalid` 与 adapter/
multipart/SSE 直连路径的 `onAuthError` 绑定到 `AuthNotifier.onSessionExpired()`；装配点从
`main.dart` 移到共享应用壳 `XiaobaiheApp`（main_mock 同步受益，符合 FX-070 入口差异边界）。

## 命令与结果

在前端 `task/auth-session-reset` 工作树：

```text
make analyze        # No issues found!
make test           # +272: All tests passed!
make test-coverage  # total: 4774/6455 lines (74.0%) >= COVERAGE_MIN=70, exit 0
```

新增两条单测：无 refreshToken 时 `api_adapter.onAuthError` 触发会话重置；
SDK `onSessionInvalid` 触发同一重置。断言 `isAuthenticated` 翻转为 false 且持久化令牌被清除。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| FX-010 | token 无效/过期时清理本地令牌并刷新路由：回调绑定后 `refreshListenable` 收到通知，
受保护路由由 GoRouter redirect 送回登录页；非认证业务错误不经过该路径，无误清。 |

## 残留与后续

令牌仍存 localStorage（CSP 由根仓反代下发），存储加固方向见
PROP-token-storage-hardening.md，不在本次范围。
