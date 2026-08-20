---
id: EVD-client-login-home-redirect-2026-08-20
layer: evidence
title: 登录成功进入内容流 2026-08-20
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-002
  - FQ-007
updated_at: 2026-08-20
observed_commit: PENDING
---

# 登录成功进入内容流 2026-08-20

## 范围与环境

核验登录接口成功后页面进入内容流。关注流、资料、帖子互动等入口使用 `push('/auth/login')`，
GoRouter 默认不把 imperative push 反映到 URL；`refreshListenable` 仍按底层公开路径判断，
不会卸掉登录页。

工具环境：工作树 `.worktree/task-login-home-redirect`，`flutter test`、`dart analyze`、
`make knowledge-check`。

## 命令与结果

在 `.worktree/task-login-home-redirect`：

```text
dart analyze lib/features/auth lib/core/router test/core/router test/features/auth
flutter test test/core/router/app_router_test.dart test/features/auth/presentation/login_page_test.dart
make knowledge-check
```

结果写入本页时以实际命令输出为准。

## 条款证据

| 条款 | 直接证据 | 结论 |
| --- | --- | --- |
| `FX-002` | 登录/注册成功后 `go('/feed')`；`auth refresh after a pushed login page does not replace it with feed` 证明仅 refresh 不够；`password login from a pushed login page opens feed` 证明点登录后进入首页 | 登录用户离开登录页进入内容流 |
| `FQ-007` | 上述 Widget 测试与 analyze | 路由行为有测试 |

## 未证明范围

- 未在真实浏览器点击登录按钮做端到端核验（Flutter web 为 canvas，表单填写依赖 Widget 测试）。
- 注册成功路径与登录共用同一 `go('/feed')`，未单独做注册 Widget 测试。
