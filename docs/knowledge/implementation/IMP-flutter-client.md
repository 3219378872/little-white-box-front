---
id: IMP-flutter-client
layer: implementation
title: Flutter 客户端实现映射
status: diverged
owner: agent
upstream:
  - DES-flutter-client
tracks:
  - FX-001
  - FX-002
  - FX-010
  - FX-020
  - FX-021
  - FX-022
  - FX-030
  - FX-031
  - FX-032
  - FX-040
  - FX-041
  - FX-050
  - FX-051
  - FX-060
  - FX-061
  - FX-062
  - FX-070
  - FQ-001
  - FQ-002
  - FQ-003
  - FQ-004
  - FQ-005
  - FQ-006
  - FQ-007
  - FQ-008
evidence:
  - EVD-client-relative-api-2026-08-18
  - EVD-client-api-followup-2026-08-18
  - EVD-client-baseline-2026-08-13
updated_at: 2026-08-18
observed_commit: b3a10ff065d5bb8269781636e3ebba84e44ea76b
---

# Flutter 客户端实现映射

## 结论

当前实现已用 `goctl api dart` 同步后端 `gateway.api`（观察提交
`380a734f90f374fb884ac68edc4edd037e959670`），帖子写入走 `/api/v2/post*`，PUT/DELETE
由同步脚本修补，搜索降级、Assistant 帖子来源、行为事件所有权和输入边界已跟进。桌面 Feed
双列、私信分栏、个性化开关和图片私信已落地。视频/语音发送仍受网关缺少上传接口限制，故整体
仍为 `diverged`。

本页观察基准是本轮 task 提交 `f97bb47eb43ef9a3eba0e1c2b72407deef668880`。

## 代码入口

| 运行面 | 当前实现 |
| --- | --- |
| 真实入口 | `lib/main.dart` 设置认证错误回调；`apiUri` 默认发相对路径 `/api/...`，可选 `SERVER_HOST` |
| Mock 入口 | `lib/main_mock.dart` 注入 `MockHttpClient`，种子用户 1 默认登录 |
| 应用壳 | `lib/app.dart`：`MaterialApp.router`、全局 Forui 主题/本地化/toast/tooltip、行为队列初始化 |
| 路由/导航 | `lib/core/router/app_router.dart`：GoRouter guard、公开与保护路由、底栏/侧栏切换、内容限宽 |
| 认证 | `lib/features/auth/` 与 `lib/core/auth/jwt_decoder.dart`：登录、注册、token/userId 恢复、登出 |
| 共享接口 | `lib/core/api/api_adapter.dart`、`v2_api_client.dart`、`api_exceptions.dart`、`error_codes.dart` |
| v1 SDK | `vendor/sdk_source/` 为生成来源，`lib/sdk/` 为应用副本 |
| Mock transport | `lib/mock/mock_http.dart`、`mock_router.dart`、`mock_data.dart` |

## Feature 映射

| 能力 | Presentation | Application | Data/transport | 主要测试 |
| --- | --- | --- | --- | --- |
| 推荐/关注流 | `features/feed/presentation/` | `feed_notifier.dart` | `feed_repository.dart`、`feed_models.dart` | `test/features/feed/` |
| 搜索 | `features/search/presentation/` | `search_notifier.dart` | `search_repository.dart`、`search_models.dart` | `test/features/search/` |
| 帖子/评论/互动 | `features/post/`、`comment/`、PostCard | 页面局部状态 | v1 repositories、multipart adapter | PostCard、profile、Mock like 测试 |
| 资料与用户列表 | `features/profile/presentation/` | `user_posts_notifier.dart` | `user_repository.dart` | `test/features/profile/` |
| 一对一私信 | `features/message/presentation/` | `message_notifiers.dart` | `message_repository.dart`、models | `test/features/message/` |
| Assistant | `features/assistant/presentation/` | `assistant_notifier.dart` | 直接 HTTP SSE repository、models | `test/features/assistant/` |
| 行为反馈 | PostCard 可见性/交互钩子 | `behavior_tracker.dart` | 持久 queue、repository、identity store | `test/features/behavior/`、tracking 测试 |

## 已实现的关键事实

- 推荐和关注使用独立游标，Feed notifier 以 generation 抑制旧请求，并在分页追加时按帖子 ID 去重。
- `PostCard` 每 100 ms 测量可见面积，达到 50% 后计时 1 秒；曝光去重键为
  `(requestId, postId)`，离开可见区后记录已曝光会话的 dwell。
- 行为队列用 SharedPreferences 持久化，默认最多 500 条、单批 100 条；按 anonymousId/sessionId
  分组发送，只移除 accepted 或 permanently rejected，暂时失败指数退避到 1 分钟。
- Message notifier 为发送命令生成随机幂等键，失败时保存命令，显式重试复用原键；已读失败独立重试。
- Assistant repository 校验 1～2,000 字符、SSE JSON 事件和终止事件；notifier 通过 generation 和
  subscription cancel 隔离取消/陈旧流，断流不会标记正常完成。
- 帖子图片通过 multipart 并行上传，任一失败时阻止帖子写入；图片选择上限为 9。
- 页面与数据层在真实/Mock 模式共用，Mock v2 transport 覆盖推荐、关注、行为、搜索、私信和 Assistant。

## 偏离登记

| ID | 条款 | 当前事实 | 影响与收敛条件 |
| --- | --- | --- | --- |
| `DIV-001` | `FX-060` | 已收敛：点赞成功不再 `trackLike/Unlike`；Mock 拒绝权威动作 | 无 |
| `DIV-002` | `FX-030` | 已收敛：创建带幂等键，编辑/删除带 `expectedRevision`，409 保留输入 | 无 |
| `DIV-003` | `FX-032` | 已收敛：标题 120、正文 20000、标签 10，选择后校验类型与 10 MiB | 无 |
| `DIV-004` | `FX-022` | 已收敛：综合搜索展示 `degraded` 与 `unavailableTypes` | 无 |
| `DIV-005` | `FX-040` | 部分收敛：文本上限 1000，图片可上传发送；视频/语音无网关上传，发送入口禁用 | 需后端补 `POST /api/v1/media/video` 及语音上传后再闭环发送 |
| `DIV-006` | `FX-051` | 部分收敛：来源带 `revision`，只打开 `post`；仍无 excerpt 与来源已变化状态 | 等 SSE 契约补 excerpt/变化标记后再展示 |

## 对齐摘要

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| 访问、认证、推荐/关注基本流 | aligned | 路由、游标、归因上下文和陈旧响应抑制已有实现与测试 |
| 搜索 | aligned | 已建模并展示部分降级 |
| 内容核心 | aligned | v2 写路径、revision/幂等和输入边界已对齐 |
| 私信 | diverged | 文本/图片闭环；视频/语音发送受网关缺口阻塞 |
| Assistant | diverged | 仅帖子来源可点，仍缺 excerpt 与来源变化 |
| 行为反馈 | aligned | 客户端不再上报 like/unlike |
| UI/工程分层 | aligned | 详见 [Forui 实现指南](IMP-forui-ui.md) |
| Mock/真实同路径 | aligned | transport 注入而非 feature 分叉；真实网关仍需独立证据 |

验证范围和命令见
[EVD-client-relative-api-2026-08-18](../evidence/EVD-client-relative-api-2026-08-18.md)
与
[EVD-client-api-followup-2026-08-18](../evidence/EVD-client-api-followup-2026-08-18.md)。
