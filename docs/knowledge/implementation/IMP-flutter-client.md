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
  - FX-052
  - FX-053
  - FX-054
  - FX-055
  - FX-056
  - FX-057
  - FX-058
  - FX-059
  - FX-060
  - FX-061
  - FX-062
  - FX-070
  - FX-080
  - FX-081
  - FX-082
  - FX-083
  - FX-084
  - FX-085
  - FX-086
  - FX-087
  - FQ-001
  - FQ-002
  - FQ-003
  - FQ-004
  - FQ-005
  - FQ-006
  - FQ-007
  - FQ-008
evidence:
  - EVD-non-agent-bugs-2026-08-27
  - EVD-assistant-agent-runtime-2026-08-27
  - EVD-exposure-event-driven-2026-08-25
  - EVD-family-provider-autodispose-2026-08-25
  - EVD-paginated-load-more-error-2026-08-25
  - EVD-auth-session-reset-2026-08-25
  - EVD-client-found-bugs-fix-2026-08-22
  - EVD-assistant-agent-mode-2026-08-26
  - EVD-assistant-md-render-2026-08-22
  - EVD-assistant-evidence-strip-2026-08-22
  - EVD-assistant-source-display-2026-08-22
  - EVD-comment-replies-2026-08-22
  - EVD-web-json-int64-2026-08-20
  - EVD-mock-gateway-align-2026-08-20
  - EVD-client-login-home-redirect-2026-08-20
  - EVD-feed-pagination-ux-2026-08-20
  - EVD-posts-reload-2026-08-20
  - EVD-favorites-reload-2026-08-20
  - EVD-client-ui-align-2026-08-20
  - EVD-search-post-author-2026-08-20
  - EVD-auth-refresh-2026-08-21
  - EVD-client-relative-api-2026-08-18
  - EVD-client-api-followup-2026-08-18
  - EVD-client-baseline-2026-08-13
updated_at: 2026-08-27
observed_commit: 06d4365
---

# Flutter 客户端实现映射

## 结论

当前实现已用 `goctl api dart` 同步后端 `gateway.api`（观察提交
d713fd3fa0fad4e08312873a68bbdcbc1b7e41d7），帖子写入走 `/api/v2/post*`，PUT/DELETE
由同步脚本修补，搜索降级、Assistant 帖子来源、行为事件所有权和输入边界已跟进。桌面 Feed
双列、私信分栏、个性化开关和图片私信已落地。视频/语音发送仍受网关缺少上传接口限制，故整体
仍为 `diverged`。

本页观察基准是本轮 task 提交 `06d4365`。

## 代码入口

| 运行面 | 当前实现 |
| --- | --- |
| 真实入口 | `lib/main.dart` 只装全局错误兜底；`apiUri` 默认发相对路径 `/api/...`，可选 `SERVER_HOST` |
| Mock 入口 | `lib/main_mock.dart` 注入 `MockHttpClient`，种子用户 1 默认登录 |
| 应用壳 | `lib/app.dart`：watch `authTransportBindingProvider` 装配传输层会话重置回调、`MaterialApp.router`、全局 Forui 主题/本地化/toast/tooltip、行为队列初始化 |
| 路由/导航 | `lib/core/router/app_router.dart`：GoRouter guard、公开与保护路由、底栏/侧栏切换、内容限宽 |
| 认证 | `lib/features/auth/` 与 `lib/core/auth/`（`jwt_decoder.dart`、`session_tokens.dart`）：登录、注册、双令牌落盘、token/userId 恢复、被动刷新、登出与会话失效清理 |
| 共享接口 | `lib/core/api/api_adapter.dart`、`v2_api_client.dart`、`json_int64.dart`、`api_exceptions.dart`、`error_codes.dart`；刷新入口在 `lib/sdk/api/api.dart` 的 `refreshSessionTokens` |
| v1 SDK | `vendor/sdk_source/` 为生成来源，`lib/sdk/` 为应用副本 |
| Mock transport | `lib/mock/mock_http.dart`、`mock_router.dart`、`mock_data.dart`；契约测试 `test/mock/` |

## Feature 映射

| 能力 | Presentation | Application | Data/transport | 主要测试 |
| --- | --- | --- | --- | --- |
| 推荐/关注流 | `features/feed/presentation/` | `feed_notifier.dart` | `feed_repository.dart`、`feed_models.dart` | `test/features/feed/` |
| 搜索 | `features/search/presentation/` | `search_notifier.dart` | `search_repository.dart`、`search_models.dart` | `test/features/search/` |
| 帖子/评论/互动 | `features/post/`、`comment/`、PostCard | 页面局部状态 | v1 repositories、multipart adapter | PostCard、profile、Mock like 测试 |
| 资料与用户列表 | `features/profile/presentation/` | `user_posts_notifier.dart` | `user_repository.dart` | `test/features/profile/` |
| 一对一私信 | `features/message/presentation/` | `message_notifiers.dart` | `message_repository.dart`、models | `test/features/message/` |
| Assistant | `features/assistant/presentation/`（会话、记忆、追踪、结构化卡片） | `assistant_notifier.dart`、`memory_notifier.dart`、`watch_notifier.dart`、`agentConsentNotifierProvider` | 直接 HTTP SSE repository、models、consent/memory/watch/feedback | `test/features/assistant/` |
| 行为反馈 | PostCard 可见性/交互钩子 | `behavior_tracker.dart` | 持久 queue、repository、identity store | `test/features/behavior/`、tracking 测试 |

## 已实现的关键事实

- 推荐和关注使用独立游标，Feed notifier 以 generation 抑制旧请求，并在分页追加时按帖子 ID 去重。
  全部 family provider 为 `autoDispose`：状态随最后一个监听者移除释放，重进即重建刷新；
  在途响应用 `mounted` + generation 双守卫（见 [EVD-family-provider-autodispose-2026-08-25](../evidence/EVD-family-provider-autodispose-2026-08-25.md)）。
- Feed 在剩余滚动空间不足 200px（含首屏未填满）时请求下一页；加载中显示底部进度，游标耗尽显示
  「没有更多了」，加载更多失败保留已有条目并提供底部重试。资料页帖子/收藏列表与会话列表
  （`PaginatedListView`）同构：失败态挂起滚动自动翻页，footer 显示失败文案 + 重试，
  重试复用原游标（见 [EVD-paginated-load-more-error-2026-08-25](../evidence/EVD-paginated-load-more-error-2026-08-25.md)）。
- `PostCard` 由 `visibility_detector` 事件回调驱动可见性（不再每卡 100ms 轮询几何），
  可见比例 ≥50% 持续 1 秒上报曝光；去重键 `(requestId, postId)`，离开可见区记录 dwell。
- `encodeApiJson` 仅对键名以 `Id`/`Ids` 结尾的字段把 ≥16 位数字串还原为 JSON number
  （数组元素继承所属键），自由文本中的长数字串保持字符串原样上行。
- 行为队列用 SharedPreferences 持久化，默认最多 500 条、单批 100 条；按 anonymousId/sessionId
  分组发送，只移除 accepted 或 permanently rejected，暂时失败指数退避到 1 分钟。
- Message notifier 为发送命令生成随机幂等键，失败时保存命令，显式重试复用原键；已读失败独立重试。
- Assistant repository 校验 1～2,000 字符、SSE JSON 事件和终止事件；notifier 通过 generation 和
  subscription cancel 隔离取消/陈旧流，断流不会标记正常完成。
- Assistant 气泡在展示层剥离回答文本中的引用残留（仅 assistant 消息，用户消息原样显示）：半角
  `[type:id]` 与全角 `［post:id］` 标记，以及后端为 ASST-010 追加的 `Community sources` /
  `SOURCE` / `COMMUNITY_CONTENT_JSON` 证据行。可跳转来源按钮由结构化 source 事件渲染，同时显示
  标题与 `sourceType:sourceId`（无标题时仅后者），不受文本剥离影响。
- Assistant 回答正文经剥离后用 `gpt_markdown 1.1.8` 渲染（标题、列表、加粗、代码块、表格等），
  沿用 Forui 排版与前景色；用户消息保持纯 Text。Forui 无 Markdown 组件故新增该依赖；链接暂不
  外跳（未接 `onLinkTap`）。
- 帖子图片通过 multipart 并行上传，任一失败时阻止帖子写入；图片选择上限为 9。
- 页面与数据层在真实/Mock 模式共用。Mock router 按当前 `gateway.api` 分发：成功体为类型 payload，
  错误为 `{code, message}` 加 `errx` HTTP 状态，JWT 路由要求 `Bearer`，可选鉴权写 `x-auth-state`，
  Feed 条目为扁平网关字段，关注流按关注关系过滤，行为接口拒绝权威动作。
- v1 SDK 与 multipart adapter 发送 `Authorization: Bearer …`，与网关 JWT 中间件和 `V2ApiClient` 一致。
- 搜索帖子解析 `authorId`/`authorName`/`authorAvatar`，结果项展示作者头像与名称，头像可进入作者资料。
- HTTP JSON 在 `decodeApiJson`/`encodeApiJson` 中保全 16 位及以上整数：解码成字符串，编码还原成 JSON
  number。详情、资料、私信路由使用路径十进制，不再 `int.parse` 雪花 ID。
- 导航未读图标继承 `IconTheme` 尺寸（桌面侧栏 16、移动底栏 24），不硬编码 24，避免「消息」项与其他入口错位。
- 验证码输入与「获取验证码」底对齐，按钮使用默认 `md` 尺寸匹配 `FTextField`；登录和注册共用 `VerifyCodeField`。
- 个人资料帖子列表与收藏列表在成为当前 tab、以及从其它路由返回且仍为当前 tab 时重新拉取第一页；
  `UserPostsNotifier` 用 generation 丢弃被刷新打断的首屏响应。
- 登录/注册成功后 `go('/feed')`。关注流、资料等入口 `push` 登录页时 URL 仍是公开路径，仅靠
  `refreshListenable` 不会卸掉登录页。
- 双令牌会话：登录/注册保存网关返回的 `refreshToken`，有效期取各自 JWT `exp`；共享 transport 遇
  认证错误（401 或 `1004/1005/1006`）时用 refreshToken 换发并恰好重试一次（single-flight 合并并发），
  调用方缓存的 `Authorization` 不能盖掉换发后的重试头。换发被拒则清空令牌并经 `onSessionInvalid`
  同步 `AuthNotifier`；换发网络失败保留 refreshToken，不把原始 401 交给 `onAuthError`。multipart 与
  Assistant SSE 复用同一刷新入口。Mock router 返回 30 分钟/7 天令牌对并提供 `POST /auth/refresh`
  一次性轮换（唯一 `jti`），重放旧 refreshToken 返回 `401/1005`。应用壳经
  `authTransportBindingProvider` 把 `onSessionInvalid` 与 `onAuthError` 统一绑定到
  `AuthNotifier.onSessionExpired`：无 refreshToken 的过期会话、multipart 与 SSE 直连路径同样
  重置内存态（见 [EVD-auth-session-reset-2026-08-25](../evidence/EVD-auth-session-reset-2026-08-25.md)、
  [EVD-non-agent-bugs-2026-08-27](../evidence/EVD-non-agent-bugs-2026-08-27.md)）。
- 编辑资料页 build watch 身份状态：冷启动深链进入时等待身份恢复后自动触发资料加载；资料读取失败
  渲染可重试 ErrorView，不再永久停在进度圈或只弹 toast。
- 推荐/关注流在一页可见项为空且 `hasMore` 时继续翻页，不以合法空态短接；刷新失败与加载更多
  失败分开，页脚「重试」分别调用 `refresh` / `loadMore`。
- 综合搜索零命中时若 `degraded` 仍展示降级横幅；缺省结果列表按空数组解析。
- 创建帖与评论对同一失败命令复用幂等键；评论输入待提交成功后再清空。
- 帖子详情页评论读取失败（首屏或分页）进入可重试错误态：空列表渲染「评论加载失败」ErrorView，
  已有条目在列表尾部提供重试按钮，均不再伪装成「还没有评论」；分页重试续拉下一页，排序切换复位游标。
- 详情赞/藏与他人资料关注在未登录时跳转登录；`InteractionNotifier` 忽略进行中的重复点赞/收藏。
- 编辑资料在身份未就绪或资料未加载成功时禁用保存。
- `PostCard` 从后台回到前台且仍 ≥50% 可见时重装曝光计时。
- Assistant 运行时忽略无法识别的 SSE `type`，未知事件不终止流、不记为连接错误（FX-059）。
- Agent 授权同时保存 `consentVersion`/`currentVersion`；版本偏低时记忆/Watch 写入口禁用并只读提示
  升级，同意后 POST 升级（FX-080）。
- 认证用户可打开 `/assistant/memory` 与 `/assistant/watch`。记忆只列出 profile/interest/task，
  区分已确认，支持改值/分值、删除、「不要记住这个」；失败展示 ErrorView 不伪装空成功。Watch 任务
  仅四种条件，命中收件箱可标已读并打开已发布帖子，不写入私信或通知中心（FX-081～083）。
  记忆与 Watch 标识经 `jsonInt64Id` 编解码后再走 SDK 路径。
- SSE `card`/`actions`/`watch_hit` 渲染结构化卡片、动作按钮与命中提示；卡片 payload 只采用服务端
  已验证 `postId`，推荐卡片「不喜欢/不感兴趣」调用 recommend/feedback（FX-084/085/087）。
- 帖子详情在已登录时提供「盯作者」「盯本帖修订」；未授权或版本偏低引导去 Assistant（FX-086）。

## 偏离登记

| ID | 条款 | 当前事实 | 影响与收敛条件 |
| --- | --- | --- | --- |
| `DIV-001` | `FX-060` | 已收敛：点赞成功不再 `trackLike/Unlike`；Mock 拒绝权威动作 | 无 |
| `DIV-002` | `FX-030` | 已收敛：创建带幂等键且失败重试复用原键，编辑/删除带 `expectedRevision`，409 保留输入 | 无 |
| `DIV-003` | `FX-032` | 已收敛：标题 120、正文 20000、标签 10，选择后校验类型与 10 MiB | 无 |
| `DIV-004` | `FX-022` | 已收敛：综合搜索展示 `degraded` 与 `unavailableTypes`，零命中降级不再伪装成普通空结果 | 无 |
| `DIV-005` | `FX-040` | 部分收敛：文本上限 1000，图片可上传发送；视频/语音无网关上传，发送入口禁用 | 需后端补 `POST /api/v1/media/video` 及语音上传后再闭环发送 |
| `DIV-006` | `FX-051` | 部分收敛：来源带 `revision`，只打开 `post`；仍无 excerpt 与来源已变化状态 | 等 SSE 契约补 excerpt/变化标记后再展示 |

## 对齐摘要

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| 访问、认证、推荐/关注基本流 | aligned | 路由、游标、归因上下文和陈旧响应抑制已有实现与测试；双令牌被动刷新对齐后端 `d713fd3` 契约（真实网关联调待做） |
| 搜索 | aligned | 已建模并展示部分降级；搜索帖子带作者身份并在结果中展示 |
| 内容核心 | aligned | v2 写路径、revision/幂等和输入边界已对齐；评论楼中楼按需展开加载（内嵌预览 + replies 分页接口）见 [EVD-comment-replies-2026-08-22](../evidence/EVD-comment-replies-2026-08-22.md)，接口语义缺口登记于后端仓 PROP-20260822-comment-reply-thread（open） |
| 私信 | diverged | 文本/图片闭环；视频/语音发送受网关缺口阻塞 |
| Assistant | diverged | enhanced_search 仍缺 excerpt 与来源变化；Agent 模式（FX-052～058）与运行时（FX-059、FX-080～087）已实现并经自动化验证，真实网关与真机图片上传证据待补 |
| 行为反馈 | aligned | 客户端不再上报 like/unlike |
| UI/工程分层 | aligned | 详见 [Forui 实现指南](IMP-forui-ui.md) |
| Mock/真实同路径 | aligned | transport 注入；Mock HTTP 契约对齐 `gateway.api`；真实网关仍需独立证据 |

验证范围和命令见
[EVD-web-json-int64-2026-08-20](../evidence/EVD-web-json-int64-2026-08-20.md)、
[EVD-mock-gateway-align-2026-08-20](../evidence/EVD-mock-gateway-align-2026-08-20.md)、
[EVD-client-login-home-redirect-2026-08-20](../evidence/EVD-client-login-home-redirect-2026-08-20.md)、
[EVD-feed-pagination-ux-2026-08-20](../evidence/EVD-feed-pagination-ux-2026-08-20.md)、
[EVD-posts-reload-2026-08-20](../evidence/EVD-posts-reload-2026-08-20.md)、
[EVD-favorites-reload-2026-08-20](../evidence/EVD-favorites-reload-2026-08-20.md)
与
[EVD-client-ui-align-2026-08-20](../evidence/EVD-client-ui-align-2026-08-20.md)、
[EVD-assistant-agent-runtime-2026-08-27](../evidence/EVD-assistant-agent-runtime-2026-08-27.md)。
