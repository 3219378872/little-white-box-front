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
  - EVD-client-baseline-2026-08-13
updated_at: 2026-08-13
observed_commit: edf598f291c889c3ec3bbdc597ab3acff6a0c9fd
---

# Flutter 客户端实现映射

## 结论

当前实现具备完整 Flutter feature 分层、响应式 Forui 应用壳、v1/v2/Assistant 三种接口适配、真实与
Mock 双入口，以及推荐反馈持久队列。它没有完全满足已批准规格，故整体状态为 `diverged`，而不是因为
测试存在与否自动标记 `aligned`。

本页观察基准是主分支提交 `edf598f291c889c3ec3bbdc597ab3acff6a0c9fd`；后续知识整理文件不改变
本页所描述的运行时代码。

## 代码入口

| 运行面 | 当前实现 |
| --- | --- |
| 真实入口 | `lib/main.dart` 设置认证错误回调，使用默认 HTTP client 和 `SERVER_HOST` |
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
| `DIV-001` | `FX-060` | `PostCard._toggleLike()` 在权威点赞接口成功后仍调用 `trackLike/trackUnlike`；tracker 和 Mock 也接受这两个客户端动作 | 与后端 `SPEC-feedback-reliability` 的事件所有权冲突，可能重复归因。应删除客户端上报并调整测试，服务端 outbox 作为唯一来源 |
| `DIV-002` | `FX-030` | v1 `CreatePostReq` 没有幂等键；`GetPostResp`、`UpdatePostReq` 和删除命令没有 revision | 创建重试可能重复，编辑无法检测并发覆盖。需先更新后端契约并重新生成 SDK，再接入编辑冲突状态 |
| `DIV-003` | `FX-032` | PostEditor 限制标题 100、正文 10,000、标签 5；图片上限 9，未在选择后显式校验 10 MiB | 拒绝一部分后端允许输入，且超大文件只能依赖服务端失败。需统一边界并为失败保留编辑状态 |
| `DIV-004` | `FX-022` | `SearchResults` 不包含 `degraded` 或 `unavailableTypes`，综合搜索无法区分部分降级和完整成功 | 可能把缺失类型解释为零结果。需扩展 v2 model、repository、UI 和 Mock/测试 |
| `DIV-005` | `FX-040` | MessageThread 只发送文本，输入上限 4,000；repository 未执行 1,000 字符边界 | 超出当前后端规格，且图片/视频/语音没有 UI/媒体引用流程。需收紧文本校验并另行设计媒体消息 |
| `DIV-006` | `FX-051` | `AssistantSourceReference` 只有 `sourceType/sourceId/title`，页面还能打开 `user` 来源；没有 excerpt、revision/hash 或来源变化状态 | 无法在客户端证明事实片段和版本，也扩大了帖子证据边界。需与 SSE 契约同步后仅接受可验证帖子来源 |

## 对齐摘要

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| 访问、认证、推荐/关注基本流 | aligned | 路由、游标、归因上下文和陈旧响应抑制已有实现与测试 |
| 搜索 | diverged | 基本类型与状态齐全，部分降级字段缺失 |
| 内容核心 | diverged | 草稿/发布入口和 multipart 已有，revision/创建幂等与部分边界未对齐 |
| 私信 | diverged | 分页、未读和幂等重试已有，媒体类型与文本上限未对齐 |
| Assistant | diverged | 流式状态可靠，证据元数据与来源边界不足 |
| 行为反馈 | diverged | 曝光、停留和队列可靠性较完整，权威互动被客户端重复上报 |
| UI/工程分层 | aligned | 详见 [Forui 实现指南](IMP-forui-ui.md) |
| Mock/真实同路径 | aligned | transport 注入而非 feature 分叉；真实网关仍需独立证据 |

验证范围和命令见
[EVD-client-baseline-2026-08-13](../evidence/EVD-client-baseline-2026-08-13.md)。修复偏离时必须先确认
任务范围和变更顺序；上游规格现已批准，但本次批准本身不授权自动修改运行时代码。
