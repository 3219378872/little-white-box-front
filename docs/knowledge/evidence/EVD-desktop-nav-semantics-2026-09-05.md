---
id: EVD-desktop-nav-semantics-2026-09-05
layer: evidence
title: 桌面导航与中文辅助语义验证 2026-09-05
status: active
result: partial
owner: agent
upstream:
  - IMP-client-platform
  - IMP-presentation-client
covers:
  - FQ-004
  - FQ-005
  - FQ-007
  - FQ-008
scope:
  - static
  - unit
  - browser
commands:
  - make analyze
  - make test
  - make knowledge-check
observed_commit: b8c309cc9608eb8c32a43e69c35ba1932bf6e70c
updated_at: 2026-09-05
---

# 桌面导航与中文辅助语义验证 2026-09-05

## 范围与环境

本证据观察前端提交 `b8c309cc9608eb8c32a43e69c35ba1932bf6e70c`。变更只涉及应用 locale、桌面
主导航语义边界、未读描述以及相应 Widget 测试；未修改路由表、路由目标、API、状态管理、数据请求、
数据库或可见业务流程。

验证环境为 Flutter 3.44.7、Dart 3.12.2、Forui 0.24.2，以及 Playwright 管理的 Chrome for Testing
151.0.7922.34。浏览器证据来自本地 Mock 入口的 release Web 构建，不是开发模式或真实网关联调。

## 命令与结果

在前端 `task/desktop-nav-semantics` 工作树实际执行：

```text
dart format lib/app.dart lib/core/router/app_router.dart \
  test/core/router/app_router_test.dart \
  test/features/auth/presentation/login_page_test.dart
# 4 个变更文件完成格式化

flutter test test/core/router/app_router_test.dart \
  test/features/auth/presentation/login_page_test.dart
# 21 tests passed

make analyze
# No issues found

make test
# 479 tests passed

make build-web
# flutter build web --release -t lib/main_mock.dart 成功

git diff --check
# 通过
```

最终构建以 `python3 -m http.server 39012 --bind 127.0.0.1 --directory build/web` 独立提供；通过
`NODE_PATH=/home/dev/.local/lib/node_modules node <内联 Playwright AX 验收脚本>` 启动 1280x900
Chrome，主动启用 Flutter accessibility 后得到：

- 240px 桌面侧栏范围内，「首页」「搜索」「消息」「发布」「我的」各恰有一个可操作 `button`；首页初始
  `aria-current=true`。
- 「消息」名称保持稳定，Mock 的 3 条未读作为 `aria-description="3 条未读"` 暴露，视觉角标没有形成
  重复语义。
- 通过语义节点点击「搜索」后 URL 为 `#/search`，且「首页」变为未选中、「搜索」变为
  `aria-current=true`。
- 点击「我的」并退出后到达 `#/auth/login`；密码动作名称由「显示密码」切换为「隐藏密码」。
- 页面异常与失败请求均为 0。Feed 与登录页截图分别位于
  `/tmp/desktop-nav-semantics-feed-20260905.png` 和
  `/tmp/desktop-nav-semantics-final-20260905.png`。

## 条款证据

- `FQ-004`：每个桌面目的地的 label、button/tap 与 selected 状态合并为一个节点；消息角标排除重复
  朗读，未读数作为描述保留。应用固定中文 locale 后，密码可见性等框架内置辅助文案与中文界面一致。
- `FQ-005`：Widget 回归断言桌面侧栏仍为 `Rect.fromLTWH(0, 0, 240, 900)`，Feed 内容仍为
  `Rect.fromLTWH(264, 0, 992, 900)`，五个侧栏条目盒子继续对齐；浏览器截图未见重叠或位移。
- `FQ-007`：目标 Widget 测试覆盖节点唯一性、名称、点击动作、选中态、未读描述、路由切换及中文密码
  动作；全量静态分析、479 个测试、release Web 构建和 Chrome DOM/AX 验收均通过。
- `FQ-008`：本页以代码提交为观察基准，反向引用实现映射并记录命令、结果、条款覆盖及未验证边界；
  `make knowledge-check` 用于校验实现与证据的双向引用。

## 未证明范围

- Chrome DOM/AX 自动验收不等于 NVDA、JAWS、VoiceOver 或 TalkBack 的人工读屏体验，也不能替代
  Windows/macOS/Linux 原生构建、移动真机、Firefox 或 Safari 验证。
- Mock release Web 证明本地路由与语义交互，不证明真实网关、外部 provider、production profile、
  数据迁移或生产流量行为；这些边界未因本次前端语义改动扩大。
- 本轮未改变移动底部导航的现有语义结构；证据只覆盖本次修复的桌面侧栏和全局中文辅助语义。
