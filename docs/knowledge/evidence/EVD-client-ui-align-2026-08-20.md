---
id: EVD-client-ui-align-2026-08-20
layer: evidence
title: 侧栏消息项与验证码行对齐 2026-08-20
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FQ-004
  - FQ-005
  - FQ-007
scope:
  - static
  - unit
commands:
  - flutter test test/core/router/app_router_test.dart test/features/auth/presentation/login_page_test.dart
  - flutter test
observed_commit: e9aa8613eee3a1c2041843b2e29cf694e9442b95
updated_at: 2026-08-20
---

# 侧栏消息项与验证码行对齐 2026-08-20

## 范围与环境

核验桌面侧栏「消息」入口与其他入口同宽同高同左缘，以及验证码输入框与「获取验证码」底对齐。
工作树 `.worktree/task-nav-login-align`。

## 命令与结果

在前端 `task/nav-login-align` 工作树：

```text
flutter test test/core/router/app_router_test.dart test/features/auth/presentation/login_page_test.dart
# 15 tests passed
flutter analyze
# 无 error；22 条既有 info，均不在本轮改动文件
flutter test
# 130 tests passed
python3 tools/knowledge_base.py check
# OK (11 formal documents, 25 requirements, 47 local links)
```

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FQ-004` | 仍用 Forui `FSidebarItem` / `FTextField` / `FButton`，未引入第二套主题 |
| `FQ-005` | 未读图标跟随侧栏 16 / 底栏 24 的 `IconTheme`；touch 测试壳下验证码按钮与默认 `md` 输入框底对齐。1280 宽浏览器截图中带未读角标的「消息」项与其他侧栏入口同盒 |
| `FQ-007` | `app_router_test` 断言 6 个桌面侧栏项同盒；有未读角标时仍同盒。`login_page_test` 断言按钮底边等于输入框底边，且按钮顶边低于 label |

## 未证明范围

Mock 入口会预登录，`/auth/login` 会被重定向，因此验证码行未在真实浏览器里点开；该行以 Widget 几何测试为准。暗色主题未单独截图。
