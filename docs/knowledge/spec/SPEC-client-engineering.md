---
id: SPEC-client-engineering
layer: spec
title: 客户端工程规格
status: approved
owner: human
upstream:
  - INT-content-community-client
updated_at: 2026-08-13
approved_at: 2026-08-13
---

# 客户端工程规格

本规格已于 2026-08-13 获得人类明确批准，是客户端架构、UI、验证和知识同步的正式工程约束。

## 架构与所有权

- `FQ-001`：Flutter 应用位于仓库根目录，使用 Riverpod 管理状态、GoRouter 管理路由。feature 按
  presentation、application、data 分层，共享能力放在 `lib/core/`，不得让页面直接承担 transport 解析。
- `FQ-002`：`vendor/sdk_source/` 是生成 SDK 来源，`lib/sdk/` 是应用使用副本；生成代码不得承载应用特有
  修复。回调转 Future、错误适配、v2 通用访问和 feature 特殊协议放在 `lib/core/api/` 或 repository。
- `FQ-003`：客户端按 HTTP 状态和 `{code, message}` 解释错误，同时兼容迁移期旧字段用于展示；业务分支
  以 code 为准，未知/格式错误响应进入明确失败态，认证错误触发统一会话清理。

## UI 与适配

- `FQ-004`：Material 可以作为应用壳或无等价能力时使用；新建或迁移界面优先 Forui 和
  `FLucideIcons`。Forui 主题、本地化、toaster 和 tooltip 在应用根统一装配，页面不得复制全局主题。
- `FQ-005`：共享主题同时覆盖亮/暗色和 touch/desktop variant；主导航根据断点在底部导航与桌面侧栏间
  切换，正文使用有上限的内容宽度，路由和信息层级不因平台改变。
- `FQ-006`：异步状态必须区分首次加载、刷新、加载更多、空态、局部失败和终态；新请求用 generation、
  cancel 或等价机制抑制陈旧结果，失败重试不得无意重复权威写入。

## 验证与知识同步

- `FQ-007`：依赖 Forui theme 的 Widget 测试复用 `foruiTestBuilder`。变更按范围运行静态分析、单元/
  Widget 测试和必要的 Web/浏览器验证，证据记录实际命令、版本、结果及未覆盖边界。
- `FQ-008`：行为变化必须从意图/规格定位条款，更新设计与实现映射，并以证据闭环；历史计划只能归档。
  `make knowledge-check` 必须验证 ID、层间引用、条款覆盖、实现—证据双向引用和本地链接。
