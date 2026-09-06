---
id: DES-assistant-client
layer: design
title: Assistant 虚拟线程与研究交互设计
status: active
role: baseline
owner: agent
upstream:
  - SPEC-client-experience
external_upstream:
  - little-white-box-content-community@f706309f860621e7d9079333cf33e81557253b73:SPEC-assistant-agent
  - little-white-box-content-community@f706309f860621e7d9079333cf33e81557253b73:SPEC-agent-memory
  - little-white-box-content-community@f706309f860621e7d9079333cf33e81557253b73:SPEC-agent-watch
tracks:
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
updated_at: 2026-09-06
---

# Assistant 虚拟线程与研究交互设计

## 入口、授权与线程

Assistant 是消息页固定的「小白盒 Agent」虚拟线程，不是主导航 destination、普通机器人账号或模式
开关。桌面在会话列表置顶，移动使用 `/messages/assistant`；记忆、Watch 及旧 `/assistant*` 入口均
落到同一认证用户线程。会话列表与 thread 并行读取，thread 挂载时最迟每 30 秒刷新，导航未读为普通
私信和 Assistant 未读之和。

首次用户任务先读取授权版本并展示能力、数据、删除确认、记忆、Watch 和预算边界。取消不发送；授权
不足或版本落后时重新披露，成功后可以复用原消息命令重试。consent、thread、消息、Memory 与 Watch
provider 都以 session identity 为边界，换号销毁旧缓存和 SSE。

## 命令、附件与异步 run

发送命令包含 message、requestId、attachments 和可选 contextPostId。图片在发送前校验、上传、预览和
移除，失败命令保留完整参数与 requestId。服务端返回 runId 与 started/redirected/steered/queued 后即
进入异步展示，不等待模型完成。忙碌时仍可发送；redirect、steer 和有界 FIFO 由服务端结果决定，只有
显式 Stop 调用 cancel。没有新会话入口；清历史不删除 MEMORY/USER 或 Watch。

## SSE 与 attempt 隔离

run SSE 使用独立 transport，并以 `Last-Event-ID` 与 `afterSeq` 恢复。repository 校验帧，忽略未知
type，只把明确 done/error 当终止。notifier 同时使用 run cursor、连接 generation、seq 和 streamId
隔离重放与迟到事件。

首个有效 token 选中当前 stream；只有同 stream token 可追加。匹配的 `response_reset` 清空该 run
临时正文并释放 stream，旧 stream 和未获选 attempt 的迟到 token 永远不能恢复失败正文。工具行、来源
卡和确认按稳定 ID 更新；确认提交后只有服务端成功才收敛为不可交互。断流保留已提交内容、活动 run 和
cursor，显示可恢复错误，不伪造取消或完成。

展示层可按字素揭示 committed 前缀，但协议正文仍由 notifier 持有。终止、取消、reset 或禁用动画时
立即对齐 committed；历史前缀不重新播放，揭示缓冲不持久化。

## 记忆、Watch 与未读

Memory 只列出用户可见的 MEMORY/USER 自然语言条目、version 和容量，支持 add/replace/remove/undo。
每个写命令按操作与规范化参数生成稳定指纹，失败保留 requestId；undo 成功才清 changeId。隐藏画像、
内部 score 或 suppressed 状态不进入 UI。

Watch 只管理四种支持条件的任务 CRUD，无独立命中收件箱。更新和删除携带 expectedVersion；版本冲突
先刷新权威列表，再保留错误供用户决定。帖子可发起盯作者/盯修订；未授权引导到 Assistant，目标是
当前用户本人时本地显示规定提示且不发送创建请求。Watch 命中作为 Assistant 主动消息进入线程并计
未读；memory_changed 不计未读并提供 undo。进入线程后已读失败可独立重试。

## 结构化问答与来源

待答问题绑定 run/question/call/message，支持单选、多选、文字、未知、无偏好、跳过和先搜索，所有选项
默认不选。提交失败保留输入并复用相同命令标识；过期或取消后只能以 questionContext 显式继续新 run，
不能重开旧终态。历史与 SSE 按问题、消息和 run 身份合并，避免重放产生重复卡片。

可信来源只来自服务端提交的结构化来源或 answer snapshot，不从 Markdown、模型链接、标题、摘要或
模型数字推断。一个帖子或网页一张卡；引用可定位卡片，站内来源走正常内容权限，外部只允许结构化
HTTP/HTTPS 地址。失效来源隐藏不可展示摘录并标注受影响引用。检索型回答在服务端结构化提交后完整
呈现，普通对话继续流式；Memory/USER 不得成为来源卡。

## 条款映射

| 范围 | 条款 |
| --- | --- |
| 入口、授权、线程 | `FX-050`、`FX-052`～`FX-054`、`FX-080`、`FX-088`、`FX-092`、`FX-093` |
| 命令、附件、run | `FX-055`～`FX-058`、`FX-089`、`FX-091` |
| SSE、attempt、揭示 | `FX-059`、`FX-090`、`FX-094` |
| Memory、Watch | `FX-081`～`FX-087` |
| 问答、答案、来源 | `FX-051`、`FX-084`、`FX-095`～`FX-099` |
