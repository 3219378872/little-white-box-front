---
id: IMP-flutter-client
layer: implementation
title: Flutter 客户端实现映射
status: diverged
owner: agent
upstream:
  - DES-flutter-client
  - DES-assistant-research-client
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
  - FX-088
  - FX-089
  - FX-090
  - FX-091
  - FX-092
  - FX-093
  - FX-094
  - FX-095
  - FX-096
  - FX-097
  - FX-098
  - FX-099
  - FQ-001
  - FQ-002
  - FQ-003
  - FQ-004
  - FQ-005
  - FQ-006
  - FQ-007
  - FQ-008
evidence:
  - EVD-watch-cannot-self-2026-09-06
  - EVD-desktop-nav-semantics-2026-09-05
  - EVD-code-quality-hardening-2026-09-05
  - EVD-assistant-research-2026-09-05
  - EVD-assistant-strict-reset-2026-09-01
  - EVD-audit-remediation-client-2026-08-31
  - EVD-assistant-reset-snapshot-2026-08-31
  - EVD-assistant-stream-render-2026-08-31
  - EVD-assistant-single-session-2026-08-30
  - EVD-assistant-stream-reset-2026-08-30
  - EVD-assistant-isolation-2026-08-30
  - EVD-assistant-hermes-2026-08-29
  - EVD-audit-fixes-2026-08-28
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
updated_at: 2026-09-06
observed_commit: 972a206d0f27d3c97a46d4cb7d2e5d7e5b1831b2
---

# Flutter 客户端实现映射

## 社区研究闭环

FX-095～099 已实现结构化问答、待答恢复、精确引用、原文摘录卡片、应用内导航和持久展示 DTO。
网络错误与待答暂停分开处理，迟到回答响应不能重开完成任务；Markdown 不产生可信来源或外部图片请求。
代码、测试与截图范围见[本轮证据](../evidence/EVD-assistant-research-2026-09-05.md)。全主题规格已按工程
约束重分层，技术栈与具体机制仍由设计承接；整体 baseline 设计不因此自动升级为 accepted。
整合后 477 项 Flutter 测试与三个 Mock 浏览器场景通过；正常 provider 的基础生成与全量黑盒通过，
但真实长检索请求因模型超时失败，真实模型浏览器闭环与语义质量门禁仍未关闭。

## 结论

当前实现已用 `goctl api dart` 同步后端 `gateway.api`（观察后端提交
66f4406），帖子写入走 `/api/v2/post*`，PUT/DELETE
由同步脚本修补，搜索降级、Assistant 帖子来源、行为事件所有权和输入边界已跟进。桌面 Feed
单列阅读流、私信分栏、个性化开关和图片私信已落地。视频/语音发送仍受网关缺少上传接口限制，故整体
仍为 `diverged`。

本页观察基准是 `b8c309cc9608eb8c32a43e69c35ba1932bf6e70c`。

2026-09-06 的 FQ-009 全页面视觉迁移单独记录于
[Heybox 视觉实现映射](IMP-heybox-presentation.md)，不关闭本页的非视觉偏离。

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
| Assistant | `features/assistant/presentation/`（虚拟线程、记忆、Watch 任务）嵌入 `MessagesShell` | `assistant_notifier.dart`、`assistant_thread_notifier.dart`、`memory_notifier.dart`、`watch_notifier.dart`、`agentConsentNotifierProvider` | REST + run SSE repository、thread/messages/memory/watch/consent | `test/features/assistant/`、`test/features/message/` |
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
- Assistant repository 校验 1～2,000 字符、`POST /assistant/messages` 的 disposition，以及
  `GET /assistant/runs/:id/events` 的 SSE 帧、`Last-Event-ID`/`afterSeq` 续流和终止事件；
  notifier 通过 run cursor + connection generation 隔离陈旧流和重复 seq，并以 `streamId`/
  `response_reset` 归属和清理 model attempt。匹配 reset 只清空 run 临时正文并 retire 旧 stream，
  不为失败 attempt 创建气泡或快照；工具行与来源卡保留在 run 气泡，下一 stream 只写入获胜正文。
  redirect/steer/queued 继续消费同一 run，不从 seq=0 重放。显式 Stop 只有 cancel 成功才落本地取消态，
  断流不会标记正常完成。
- Assistant 气泡在展示层剥离回答文本中的引用残留（仅 assistant 消息，用户消息原样显示）：半角
  `[type:id]` 与全角 `［post:id］` 标记，以及后端为 ASST-010 追加的 `Community sources` /
  `SOURCE` / `COMMUNITY_CONTENT_JSON` 证据行。可跳转来源按钮由结构化 source 事件渲染，同时显示
  标题与 `sourceType:sourceId`（无标题时仅后者），不受文本剥离影响。
- Assistant 回答正文经剥离后用 `gpt_markdown 1.1.8` 渲染（标题、列表、加粗、代码块、表格等），
  沿用 Forui 排版与前景色；用户消息保持纯 Text。Forui 无 Markdown 组件故新增该依赖；链接暂不
  外跳（未接 `onLinkTap`）。
- 流式回答由 `StreamingMarkdownBody` 按字素揭示 committed 前缀（FX-094）；`AssistantMessage.text`
  仍是协议正文，揭示缓冲不进 notifier。稳定前缀与尾巴双层 `GptMarkdown`，仅未闭合代码围栏走等宽
  Text。`!isStreaming` 不挂 Ticker，直接 `GptMarkdown`。
- 助手列表钉住底部只听 `UserScrollNotification`；字素揭示经 `onRevealed` 同帧 `jumpTo`。内容变高
  不 unpin。已删除按 last-message identity 重启 180ms `animateTo` 的 `_scheduleScroll`。
- Assistant 首屏加载、清历史、增量刷新和更早消息分页分别以 generation 与 busy 状态隔离；POST
  返回、持久历史和 SSE 终止事件按 runId 收敛到单一回答。断流耗尽后保留 active run、seq、工具状态
  与排队状态，同 run thread 轮询或显式「重新连接」从最后 `afterSeq` 续订；只有通过 seq/streamId
  fence 的真实事件才清除断流错误，旧 attempt 的迟到 token 不能伪造恢复。
- Consent 首次读取为 single-flight；页面级发送 fence 防止并发授权框和重复 POST。queued 输入在
  compact/attachment 阶段保持排队提示，到 model_request、工具/SSE 或终止证据才清除。输入等待期间
  用户新编辑的草稿不会被前一发送完成回调清空。
- 帖子图片通过 multipart 并行上传，任一失败时阻止帖子写入；图片选择上限为 9。
- 帖子提交在点击时冻结标题、正文、标签及本地/网络图片，避免上传等待期间 UI 变化改写在途命令；
  图片选择器返回后检查 Widget 生命周期。登录/注册、Memory/Watch 对话框和 Assistant 附件异步回调
  均以当前 route/session identity 隔离，资料关注增加 single-flight busy fence。
- 时间展示统一由 `lib/core/formatters/time_formatter.dart` 处理秒级兼容数据和当前毫秒时间戳；生成 SDK
  将 Snowflake ID 字段保留为 `Object`，避免 Flutter Web 将 int64 舍入。SDK 同步脚本可从主检出或
  嵌套 task worktree 自动定位同级后端，生成来源与应用副本保持逐字一致。
- 页面与数据层在真实/Mock 模式共用。Mock router 按当前 `gateway.api` 分发：成功体为类型 payload，
  错误为 `{code, message}` 加 `errx` HTTP 状态，JWT 路由要求 `Bearer`，可选鉴权写 `x-auth-state`，
  Feed 条目为扁平网关字段，关注流按关注关系过滤，行为接口拒绝权威动作。
- v1 SDK 与 multipart adapter 发送 `Authorization: Bearer …`，与网关 JWT 中间件和 `V2ApiClient` 一致。
- 搜索帖子解析 `authorId`/`authorName`/`authorAvatar`，结果项展示作者头像与名称，头像可进入作者资料。
- HTTP JSON 在 `decodeApiJson`/`encodeApiJson` 中保全 16 位及以上整数：解码成字符串，编码还原成 JSON
  number。详情、资料、私信路由使用路径十进制，不再 `int.parse` 雪花 ID。
- 导航未读图标继承 `IconTheme` 尺寸（桌面侧栏 16、移动底栏 24），不硬编码 24，避免「消息」项与其他入口错位。
- 桌面 `FSidebarItem` 以单一可操作语义节点暴露名称、选中态和点击动作；嵌套路由 child 的语义容器
  阻止 route barrier 裁掉相邻侧栏。消息入口保持稳定名称「消息」，未读数作为附加描述，视觉角标不重复
  朗读；这些语义包装不改变 240px 侧栏、内容区域位置或路由回调
  （见 [EVD-desktop-nav-semantics-2026-09-05](../evidence/EVD-desktop-nav-semantics-2026-09-05.md)）。
- 应用 locale 固定为 `zh`，与当前全中文可见界面一致，使 Forui/Material 内置辅助语义也使用中文；登录页
  密码可见性动作分别暴露「显示密码」与「隐藏密码」。
- 验证码输入与「获取验证码」底对齐，按钮使用默认 `md` 尺寸匹配 `FTextField`；登录和注册共用 `VerifyCodeField`。
- 个人资料帖子列表与收藏列表在成为当前 tab、以及从其它路由返回且仍为当前 tab 时重新拉取第一页；
  `UserPostsNotifier` 用 generation 丢弃被刷新打断的首屏响应。
- 登录/注册成功后 `go('/feed')`。关注流、资料等入口 `push` 登录页时 URL 仍是公开路径，仅靠
  `refreshListenable` 不会卸掉登录页。
- 双令牌会话：登录/注册保存网关返回的 `refreshToken`，有效期取各自 JWT `exp`；共享 transport 遇
  认证错误（401 或 `1004/1005/1006`）时用 refreshToken 换发并恰好重试一次（single-flight 合并并发），
  调用方缓存的 `Authorization` 不能盖掉换发后的重试头。换发被拒则清空令牌并经 `onSessionInvalid`
  同步 `AuthNotifier`；换发网络失败、5xx 或 2xx 非法响应均保留 refreshToken，不把原始 401 交给
  `onAuthError`。multipart 与 Assistant SSE 复用同一刷新入口及“凭据仍在则不清会话”判定。Mock router
  返回 30 分钟/7 天令牌对并提供 `POST /auth/refresh`
  一次性轮换（唯一 `jti`），重放旧 refreshToken 返回 `401/1005`。应用壳经
  `authTransportBindingProvider` 把 `onSessionInvalid` 与 `onAuthError` 统一绑定到
  `AuthNotifier.onSessionExpired`：无 refreshToken 的过期会话、multipart 与 SSE 直连路径同样
  重置内存态（见 [EVD-auth-session-reset-2026-08-25](../evidence/EVD-auth-session-reset-2026-08-25.md)、
  [EVD-non-agent-bugs-2026-08-27](../evidence/EVD-non-agent-bugs-2026-08-27.md)）。
- 令牌持久层为每次登录/登出维护 `sessionRevision`，刷新只在 revision 与 refreshToken 仍匹配时替换，
  401 只在完整 access/refresh 凭据仍匹配时删除。刷新 single-flight 按 revision + refreshToken 隔离；
  旧账号 refresh、迟到 401、multipart 或 SSE 都不能覆盖或清除新账号。`AuthNotifier` 串行恢复、登录、
  登出与失效发布。公开与认证 provider 分别观察 session identity，Feed、Comment、Interaction、Post、
  Profile、User posts、Message 与 Assistant 在换号时重建，迟到响应由 generation/mounted 丢弃。
- 编辑资料页 build watch 身份状态：冷启动深链进入时等待身份恢复后自动触发资料加载；资料读取失败
  渲染可重试 ErrorView，不再永久停在进度圈或只弹 toast。
- 推荐/关注流在一页可见项为空且 `hasMore` 时继续翻页，不以合法空态短接；刷新失败与加载更多
  失败分开，页脚「重试」分别调用 `refresh` / `loadMore`。
- 综合搜索零命中时若 `degraded` 仍展示降级横幅；缺省结果列表按空数组解析。
- 创建帖以标题/正文/图片/标签/状态/mediaIds 完整指纹、评论以帖子/父评论/回复用户/正文完整指纹判断
  同一失败命令；相同命令复用幂等键，命令变化换新键。已上传本地图片按选择指纹复用，避免响应丢失后
  重新上传换 mediaId；匿名评论跳登录时保留输入。
- 帖子详情页评论读取失败（首屏或分页）进入可重试错误态：空列表渲染「评论加载失败」ErrorView，
  已有条目在列表尾部提供重试按钮，均不再伪装成「还没有评论」；分页重试续拉下一页，排序切换复位游标。
- 详情赞/藏与他人资料关注在未登录时跳转登录；`InteractionNotifier` 忽略进行中的重复点赞/收藏。
- 编辑资料在身份未就绪或资料未加载成功时禁用保存。
- `PostCard` 从后台回到前台且仍 ≥50% 可见时重装曝光计时。
- Assistant 是消息页固定虚拟线程，不是主导航 destination。桌面会话列表置顶「小白盒 Agent」，
  移动端 `/messages/assistant`；旧 `/assistant*` 重定向。并行拉取会话列表与 thread，导航未读
  合并 Assistant 未读，thread 每 30 秒轮询（FX-050/052/083/088）。
- 首次发送前查询 consent；版本偏低只读提示并要求升级。忽略未知 SSE `type`。来源只渲染
  `source_card`，不从 Markdown 解析。工具进度、确认、`memory_changed` undo、推荐反馈按新事件
  类型处理（FX-051/053～059/080/084/085/087）。
- 认证用户可打开 `/messages/assistant/memory` 与 `/messages/assistant/watch`。记忆列出
  MEMORY/USER、容量 used/limit，支持 content+version 写入与 undo。Watch 仅任务 CRUD，无命中
  收件箱。帖子详情盯梢未授权引导 `/messages/assistant`；作者是自己时本地提示「不能关注自己的动态」。
  Watch `targetId` 经 `jsonInt64JsonValue` 编码为 JSON number（FX-081/082/086）。
- Memory add/replace/remove 以完整命令指纹复用稳定 requestId；成功后才清理待重试命令。列表刷新保留
  `lastChangeId`，undo 失败保留入口，成功才清除。Memory provider 在当前认证 session 内常驻，避免
  对话框和错误提示造成的短暂无监听窗口丢失待重试 requestId；它仍依赖 session identity，换号或登出
  会重建并清空旧命令。Watch update/delete 发送 task `expectedVersion`，update 直接采用响应
  task/version；`409/2007` 冲突先刷新任务列表并保留冲突错误。
- `POST /assistant/messages` 接受 started/redirected/steered/queued；忙碌时仍可发送；显式 Stop
  才 `POST /assistant/runs/:id/cancel`。无新会话入口；清历史不删除 MEMORY/USER/Watch（FX-058/089～093）。
- Assistant、consent、thread、Memory 与 Watch provider 以认证 `userId` 为依赖键；换号或登出会销毁
  旧状态并取消旧 SSE，新身份在页面未卸载时也重新加载。失败发送保留完整命令（稳定 requestId、附件、
  contextPostId），重试不新增气泡；confirm、Stop、memory undo 与授权撤销仅在服务端成功后呈现成功态。
- Assistant 消息首屏读取最新 50 条，以 `beforeId` 加载更早消息、`afterId` 增量接收新消息，两种 cursor
  互斥。线程轮询观察到更大的 `lastMessageId` 时，已打开页面增量拉取 Watch 主动消息；POST 透传已有
  `contextPostId`，GET 不推测附件或上下文字段（FX-050/055/057/083/085/088～093）。
- Assistant、Memory 与 Watch 的 loading/error/empty/partial-list 状态均可见且可重试；Memory/Watch
  load generation 防止旧读取覆盖新写入。Watch 非空列表的写入或刷新错误保留现有任务并显示内联重试。

## 偏离登记

| ID | 条款 | 当前事实 | 影响与收敛条件 |
| --- | --- | --- | --- |
| `DIV-001` | `FX-060` | 已收敛：点赞成功不再 `trackLike/Unlike`；Mock 拒绝权威动作 | 无 |
| `DIV-002` | `FX-030` | 已收敛：完整命令指纹决定创建/评论幂等键复用，编辑/删除带 `expectedRevision`，409 保留输入 | 无 |
| `DIV-003` | `FX-032` | 已收敛：标题 120、正文 20000、标签 10，选择后校验类型与 10 MiB | 无 |
| `DIV-004` | `FX-022` | 已收敛：综合搜索展示 `degraded` 与 `unavailableTypes`，零命中降级不再伪装成普通空结果 | 无 |
| `DIV-005` | `FX-040` | 部分收敛：文本上限 1000，图片可上传发送；视频/语音无网关上传，视觉迁移后不显示占位发送入口 | 需后端补 `POST /api/v1/media/video` 及语音上传后再闭环发送 |
| `DIV-006` | `FX-051` | 已按 `source_card` 展示 handle/kind/authorityId/title/revision；不从 Markdown 解析来源。来源已变化/不可用的细粒度标记仍取决于服务端 payload | 服务端若在 `payloadJson` 给出变化标记再展示 |

## 对齐摘要

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| 访问、认证、推荐/关注基本流 | aligned | 路由、游标、归因上下文和陈旧响应抑制已有实现与测试；双令牌被动刷新对齐后端 `d713fd3` 契约（真实网关联调待做） |
| 搜索 | aligned | 已建模并展示部分降级；搜索帖子带作者身份并在结果中展示 |
| 内容核心 | aligned | v2 写路径、revision/幂等和输入边界已对齐；评论楼中楼按需展开加载（内嵌预览 + replies 分页接口）见 [EVD-comment-replies-2026-08-22](../evidence/EVD-comment-replies-2026-08-22.md)，接口语义缺口登记于后端仓 PROP-20260822-comment-reply-thread（open） |
| 私信 | diverged | 文本/图片闭环；视频/语音发送受网关缺口阻塞 |
| Assistant | partial | 客户端自有边界已补齐 session revision/凭据快照、账号缓存隔离、SSE cursor/generation、稳定重试、严格 `streamId`/`response_reset` attempt fencing、断流后显式/轮询重连、Consent single-flight、展示层字素揭示（FX-094）、Memory 写入幂等、Watch version CAS、真实失败态、最新消息分页、memory undo、授权撤销与 Watch 增量刷新；`EVD-code-quality-hardening-2026-09-05` 覆盖本轮 run/history/queued/重连与页面生命周期状态机，`EVD-assistant-strict-reset-2026-09-01` 证明 reset 后只有一个 run 气泡且最终正文只含获胜 attempt，`EVD-audit-remediation-client-2026-08-31` 已在真实同源 release 浏览器覆盖桌面换号、Memory 503 稳定重试/undo 与 Watch `409/2007` 收敛；浏览器 SSE 断流/重连与真机图片上传仍待补。整体仓库仍因私信视频/语音发送缺口保持 diverged |
| 行为反馈 | aligned | 客户端不再上报 like/unlike |
| UI/工程分层 | aligned | 详见 [Forui 实现指南](IMP-forui-ui.md) |
| Mock/真实同路径 | aligned | transport 注入；Mock HTTP 契约对齐 `gateway.api`；账号切换、Memory 与 Watch 关键写路径已有独立真实同源浏览器证据，其余契约仍按各证据页边界解释 |

验证范围和命令见
[EVD-web-json-int64-2026-08-20](../evidence/EVD-web-json-int64-2026-08-20.md)、
[EVD-mock-gateway-align-2026-08-20](../evidence/EVD-mock-gateway-align-2026-08-20.md)、
[EVD-client-login-home-redirect-2026-08-20](../evidence/EVD-client-login-home-redirect-2026-08-20.md)、
[EVD-feed-pagination-ux-2026-08-20](../evidence/EVD-feed-pagination-ux-2026-08-20.md)、
[EVD-posts-reload-2026-08-20](../evidence/EVD-posts-reload-2026-08-20.md)、
[EVD-favorites-reload-2026-08-20](../evidence/EVD-favorites-reload-2026-08-20.md)
与
[EVD-client-ui-align-2026-08-20](../evidence/EVD-client-ui-align-2026-08-20.md)、
[EVD-desktop-nav-semantics-2026-09-05](../evidence/EVD-desktop-nav-semantics-2026-09-05.md)、
[EVD-code-quality-hardening-2026-09-05](../evidence/EVD-code-quality-hardening-2026-09-05.md)、
[EVD-assistant-hermes-2026-08-29](../evidence/EVD-assistant-hermes-2026-08-29.md)、
[EVD-assistant-strict-reset-2026-09-01](../evidence/EVD-assistant-strict-reset-2026-09-01.md)、
[EVD-assistant-isolation-2026-08-30](../evidence/EVD-assistant-isolation-2026-08-30.md)、
[EVD-assistant-single-session-2026-08-30](../evidence/EVD-assistant-single-session-2026-08-30.md)。
