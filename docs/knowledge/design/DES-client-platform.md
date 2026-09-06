---
id: DES-client-platform
layer: design
title: 客户端平台与工程边界设计
status: active
role: baseline
owner: agent
upstream:
  - SPEC-client-experience
  - SPEC-client-engineering
external_upstream:
  - little-white-box-content-community@f706309f860621e7d9079333cf33e81557253b73:SPEC-community-core
tracks:
  - FX-001
  - FX-002
  - FX-010
  - FX-070
  - FQ-001
  - FQ-002
  - FQ-003
  - FQ-006
  - FQ-007
  - FQ-008
updated_at: 2026-09-06
---

# 客户端平台与工程边界设计

## 范围

本页定义所有 feature 共用的应用壳、路由、身份、传输、生成契约、异步状态和验证边界。它是当前
Flutter/Riverpod/GoRouter 实现的基线投影，不改变已批准的产品语义；社区、私信、Assistant 与展示层
的领域机制由各自设计页承接。

## 分层与依赖

```text
presentation -> application -> feature repository -> shared transport -> gateway
                              \-> generated SDK
```

| 所有者 | 职责 | 禁止事项 |
| --- | --- | --- |
| `features/*/presentation` | 渲染状态、收集输入、导航 | 解析 HTTP、保存 token、绕过业务命令 |
| `features/*/application` | Riverpod 状态机、并发代次、重试命令 | 直接拼 URL、依赖 Widget context |
| `features/*/data` | 请求、响应校验、领域模型适配 | 页面样式、跨 feature 全局状态 |
| `core/api`、`core/auth` | 统一传输、错误、身份快照与刷新 | feature 特有展示语义 |
| `core/router` | 公开/受保护边界和响应式导航壳 | 业务数据加载 |
| `mock` | 在共享 transport 后模拟当前网关契约 | 建立第二套页面或 repository |

真实入口和 Mock 入口只在 transport 注入点分流。feature 不读取 `isMockMode`，因此同一成功、失败和
权限状态可在两种入口复用。Mock 只用于确定性开发和回归，不充当真实网关、权限或线上质量证据。

## 路由与身份

公开读取包含推荐、搜索、已发布帖子和公开资料；创作、关注流、个人中心、私信和 Assistant 受认证
保护。`GoRouter.redirect` 提供硬边界，页面入口提供可解释的登录引导，两者观察同一认证状态。

持久化令牌与单调 `sessionRevision` 组成不可变凭据快照。登录、登出和条件清理开启新 revision；同一
会话的 access/refresh token 轮换保持原 revision。刷新 single-flight 以 revision 与 refresh token
分组，迟到 refresh、401 或旧账号请求不能覆盖或清理新账号。只有明确的凭证拒绝触发条件清理；网络、
5xx 和非法成功体保持当前身份并返回可恢复错误。

公开缓存和认证缓存均带 session identity。provider 在身份改变时重建，notifier 还以 generation、
mounted 和当前命令身份拒绝迟到结果。首次加载、刷新、分页、局部失败、空态和终态分别建模；失败命令
保留原参数与幂等标识，参数变化才形成新命令。

## 契约与精确标识

默认 API URI 使用相对 `/api/...`，由页面来源提供同源反代；原生端或跨源调试可显式注入
`SERVER_HOST`。HTTP 状态与结构化业务码共同分类，未知或非法响应进入失败态。

`vendor/sdk_source` 是 `goctl api dart` 的生成来源，`lib/sdk` 是应用副本。PUT/DELETE 修补、绝对生成
路径清理和实体 ID 类型兼容集中在 `tools/sync_gateway_sdk.py`；应用适配位于 `core/api` 或 feature
repository，禁止只手改任一生成副本。`sdk-check` 必须针对已核验的后端 `gateway.api` 在临时目录重生
并逐字比较两份副本。

网关雪花 ID 是 JSON number。解码前将 16 位及以上整数字面量保护为字符串，编码时仅在 `Id`/`Ids`
键上下文把十进制字符串还原为 JSON number；自由文本不做转换。路径、query、路由和领域模型不把实体
标识转换为 Web 不精确的 Dart `int`。

## 验证与追踪

结构检查只证明图谱格式和引用闭环。行为结论必须由与范围匹配的静态、单元、集成、浏览器、设备或
真实服务证据支撑；证据同时记录结果、命令、版本和未覆盖边界。跨仓引用锚定被实际审计的提交，不把
后续未观察版本写成证据。

| 条款 | 设计位置 |
| --- | --- |
| `FX-001`、`FX-002`、`FX-010` | 路由与身份 |
| `FX-070` | 分层与依赖中的共享 Mock/真实路径 |
| `FQ-001`、`FQ-003`、`FQ-006` | 所有权、错误分类和异步状态 |
| `FQ-002` | 契约生成与精确标识 |
| `FQ-007`、`FQ-008` | 验证与追踪 |
