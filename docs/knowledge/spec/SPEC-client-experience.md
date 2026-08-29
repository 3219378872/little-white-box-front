---
id: SPEC-client-experience
layer: spec
title: 客户端体验与接口规格
status: approved
owner: human
upstream:
  - INT-content-community-client
updated_at: 2026-08-29
approved_at: 2026-08-13
---

# 客户端体验与接口规格

本规格已于 2026-08-13 获得人类明确批准。2026-08-29 按当前对话明确授权，重写 Assistant 条款
（保留 FX-050～059、FX-080～093 编号，替换语义），删除模式开关和 Watch 命中收件箱要求。接口
语义以同级后端仓库 `SPEC-assistant-agent`、`SPEC-agent-memory`、`SPEC-agent-watch` 与当前
`gateway.api` 为准。条款定义目标行为；当前代码是否满足条款，以实现层和证据层为准。

## 访问与身份

- `FX-001`：匿名用户可以进入推荐流、搜索、已发布帖子详情、公开用户资料以及登录/注册页面；匿名
  读取失败不得被伪装成空结果。
- `FX-002`：发布或编辑帖子、个人中心、关注流、私信和 Assistant 只对已认证用户提供。匿名用户触发
  受保护入口时跳转登录，登录用户进入登录/注册页时回到内容流。
- `FX-010`：客户端启动时从持久化 token 恢复身份；token 无效、过期或要求登录时清理本地会话并刷新
  路由。鉴权失败之外的业务错误不得误清会话。

## 内容发现

- `FX-020`：推荐流支持首屏、刷新和游标加载更多；同一游标链保留 `requestId`，每项保留从 1 开始的
  `position`、`recallSource`、`modelVersion` 和 `experimentId`，分页结果在客户端按帖子 ID 去重。
- `FX-021`：关注流只对认证用户加载，使用 `(createdAt, postId)` 游标；空关注流显示合法空态，不以推荐
  内容冒充关注内容。
- `FX-022`：搜索区分综合、用户和标签，明确呈现 idle、loading、success、empty 和 failure。综合搜索的
  部分降级必须保留并展示 `degraded` 与 `unavailableTypes`，帖子搜索整体不可用不得显示为空结果。

## 内容、媒体与互动

- `FX-030`：创建帖子支持草稿和直接发布；编辑、发布状态转换与删除必须携带服务端要求的幂等键和最后
  读取的 revision，冲突时保留用户输入并显示可恢复错误，不得覆盖并发修改。
- `FX-031`：帖子详情支持评论分页与排序、点赞/取消、收藏/取消；用户资料支持本人或公开帖子列表，并按
  服务端可见性决定是否暴露收藏列表。失败互动必须回滚本地乐观状态。
- `FX-032`：客户端至少接受后端允许的标题 1～120 字符、正文 1～20,000 字符、最多 9 张图片和 10 个
  标签；图片只提交 JPEG、PNG 或 WebP，单图不得超过 10 MiB。多图上传任一失败时不得继续发布帖子。

## 一对一私信

- `FX-040`：认证用户可以分页读取会话和历史消息，发送文本、图片、视频或语音消息。文本为 1～1,000
  个字符；每次发送生成最长 128 字符的幂等键，同一失败命令重试必须复用原键。
- `FX-041`：进入会话后只标记当前用户的该会话已读；已读失败可以独立重试。会话列表、线程和导航未读数
  在成功标记后收敛，不因局部刷新失败伪造零未读。

## Assistant

接口语义以同级后端仓库 `SPEC-assistant-agent`、`SPEC-agent-memory`、`SPEC-agent-watch` 与当前
`gateway.api` 为准。Assistant 不是机器人用户，也不写入普通 Message API。

- `FX-050`：Assistant 是认证用户在消息页中的固定虚拟私信线程「小白盒 Agent」。独立 `/assistant`
  主导航入口删除；旧 `/assistant*` 重定向到 `/messages/assistant*`。输入为 1～2,000 个字符，一次
  发送生成稳定 `requestId`。
- `FX-051`：可点击来源只接受 SSE `source_card` 中的已验证标识（handle、kind、authorityId、title、
  revision）。客户端不得从 Markdown 或回答正文解析帖子 ID、链接或引用。帖子来源可打开已发布帖子；
  网页等非帖子类型以类型标识展示，不作为帖子证据。没有来源卡不影响普通回答成功。
- `FX-052`：桌面 MessagesShell 在会话列表上方固定「小白盒 Agent」，选中后右侧展示助手线程。移动端
  路径为 `/messages/assistant`。记忆页 `/messages/assistant/memory`、Watch 页
  `/messages/assistant/watch`，均认证守卫。
- `FX-053`：首次用户 run 前必须查询 `GET /assistant/consent`。未授权须展示能力说明——当前工具分组、
  数据边界、delete_post 逐次确认、Memory/Watch 与长任务预算——用户同意后才 `POST /assistant/consent`。
  取消则不发送。未经同意不得发起用户 run。
- `FX-054`：收到 `AGENT_NOT_AUTHORIZED` 结构化错误时重新触发授权流程；授权成功后允许重发当前消息。
- `FX-055`：发送支持图片附件：从相册选择图片，按发布规则校验类型与大小（JPEG/PNG/WebP、单图
  ≤10 MiB），上传换取 mediaId 后以缩略图呈现且发送前可移除；附件随当次消息提交。
- `FX-056`：SSE `tool_call` / `tool_result` 在会话流内渲染为进度行（图标与人可读摘要），终止后折叠
  为摘要行；`confirm_required` 渲染为含操作摘要的确认卡片。
- `FX-057`：确认卡片一次性有效：`POST /assistant/runs/:id/confirm` 携带 `{callId, approved}` 后转为
  不可交互并显示结果；超时或失败按拒绝/过期呈现，不得阻塞后续事件渲染。
- `FX-058`：忙碌输入语义：当前 run 处于 `model_request` 时新消息 redirect；`tool_executing` 时
  steer；compact/附件等不能安全注入的阶段 FIFO 排队（服务端上限 32）。输入在忙碌时仍可发送。只有
  显式 Stop 调用 `POST /assistant/runs/:id/cancel` 硬取消；断线不取消 run。
- `FX-059`：客户端必须忽略无法识别的 SSE `type`，不得把未知事件当成错误终止。持久事件类型为
  `run_started|token|tool_call|tool_result|confirm_required|source_card|memory_changed|done|error`。

- `FX-080`：`GET /assistant/consent` 同时展示 `consentVersion` 与 `currentVersion`。已授权但版本
  低于当前披露版本时，再次展示完整工具分组清单并确认后才能 `POST` 升级；未升级不得发起用户 run，
  记忆/Watch 页仍可只读提示需升级。
- `FX-081`：认证用户可打开记忆页，列出 `target=memory|user` 的自然语言条目（content + version），
  展示容量 used/limit；可新增、替换、删除，并按 changeId 撤销。不展示 layer/score/suppressed。
  越权/失败展示可恢复错误，不伪装空成功。
- `FX-082`：认证用户可列出、创建、启用/停用、删除 Watch 任务。条件类型仅 `author_new_post` |
  `tag_new_post` | `keyword_new_post` | `post_revised`。未知类型不得提交。不提供独立命中收件箱。
- `FX-083`：Watch 主动消息进入 Assistant 虚拟线程并计入未读，不是系统通知中心，不写入普通私信。
  消息导航未读徽标 = 普通私信未读 + Assistant 未读。
- `FX-084`：仅 `source_card` 渲染结构化来源卡；只使用服务端给出的已验证标识，不得用模型自由文本
  里的数字冒充 postId。
- `FX-085`：`memory_changed` 系统行不计未读，并提供撤销入口（`POST /assistant/memory/changes/:id/undo`）；
  失败独立提示，不阻塞后续事件。
- `FX-086`：帖子详情在 Agent 已授权时提供「盯作者」「盯本帖修订」入口（创建 `author_new_post` /
  `post_revised`），未授权则引导去 `/messages/assistant` 而非 `/assistant`。
- `FX-087`：推荐类来源卡在适用时提供不喜欢/不感兴趣，调用 `POST /assistant/recommend/feedback`
  （reason 如 `dislike`），失败不回写成功态。
- `FX-088`：打开消息能力时并行拉取会话列表与 `GET /assistant/thread`。消息 feature 挂载期间每 30
  秒轮询 thread。未读数在成功标记已读后收敛，不因局部刷新失败伪造零未读。
- `FX-089`：`POST /assistant/messages` 返回 `messageId`、`sessionId`、`runId` 和
  `disposition=started|redirected|steered|queued`；客户端不等待模型完成即接受异步 run。
- `FX-090`：`GET /assistant/runs/:id/events` 以 SSE 消费事件；重连携带 `Last-Event-ID` 与
  `afterSeq`。断流保留已收到文本并显示失败/恢复状态，不伪造 done。
- `FX-091`：显式 Stop 调用 `POST /assistant/runs/:id/cancel`；取消后忽略该 run 的后续事件。
- `FX-092`：新会话 `POST /assistant/sessions` 滚动 session，但不删除历史、MEMORY/USER 或 Watch。
  清除历史 `DELETE /assistant/history` 不影响后三者。
- `FX-093`：进入助手线程后 `POST /assistant/thread/read` 标记已读；已读失败可独立重试。Watch 主动
  消息计入未读，`memory_changed` 不计未读。

## 行为反馈

- `FX-060`：客户端行为接口只提交 exposure、click、dwell、view、play、share、hide 和 dislike；like、
  unlike、favorite、unfavorite、comment、follow、unfollow 由权威业务事务生成，客户端不得重复上报。
- `FX-061`：曝光要求同一推荐请求中的帖子至少 50% 可见并连续保持 1 秒，同一
  `(requestId, postId)` 只记录一次；曝光、点击和停留携带身份、请求、场景、位置、来源、版本与实验上下文。
- `FX-062`：行为队列持久化等待发送的事件，单批最多 100 条，按匿名身份和会话分组；只移除服务端已
  接受或永久拒绝的事件，离线或暂时失败时有界退避重试，分析失败不阻塞用户操作。

## Mock 与真实网关

- `FX-070`：`lib/main.dart` 和 `lib/main_mock.dart` 只在 transport、服务地址和开发用种子会话上不同；
  页面、状态管理、repository、数据模型和错误分支保持同路径。Mock 必须覆盖成功、鉴权、分页、幂等、
  流式终止和批量部分结果等关键契约，但其结果不能替代真实网关联调。

## 验收边界

每个条款至少需要设计映射、实现状态和带版本证据。自动化测试可以证明解析、状态转换和 Widget 行为；
真实鉴权、CORS、流式代理、服务端权限、推荐质量和跨服务一致性必须由单独的真实环境证据证明。
