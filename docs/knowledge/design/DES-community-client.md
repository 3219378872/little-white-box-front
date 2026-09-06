---
id: DES-community-client
layer: design
title: 社区发现与内容客户端设计
status: active
role: baseline
owner: agent
upstream:
  - SPEC-client-experience
external_upstream:
  - little-white-box-content-community@f706309f860621e7d9079333cf33e81557253b73:SPEC-community-core
  - little-white-box-content-community@f706309f860621e7d9079333cf33e81557253b73:SPEC-content-discovery
  - little-white-box-content-community@f706309f860621e7d9079333cf33e81557253b73:SPEC-feedback-reliability
tracks:
  - FX-020
  - FX-021
  - FX-022
  - FX-030
  - FX-031
  - FX-032
  - FX-060
  - FX-061
  - FX-062
updated_at: 2026-09-06
---

# 社区发现与内容客户端设计

## 范围

本页承接推荐、关注、搜索、帖子、评论、互动、资料列表和行为反馈。身份、传输、精确 ID、通用异步
状态和 Mock 边界由 [DES-client-platform](DES-client-platform.md) 提供；页面视觉由
[DES-presentation-client](DES-presentation-client.md) 提供。

## 发现与搜索

推荐 repository 保存字符串游标及 request、position、source、model、experiment 等完整归因；刷新
建立新请求链，分页沿用当前链。notifier 以 generation 丢弃陈旧响应、按精确帖子 ID 去重，并在合法
空页仍有游标时继续请求。关注流使用独立的服务端游标，只在认证后请求，合法空态不回退成推荐内容。

搜索以统一模型区分帖子、用户和标签，并保留 `degraded` 与 `unavailableTypes`。待输入、加载、成功、
空态、部分降级和整体失败各自可见；帖子搜索不可用不能显示成普通零结果。帖子结果携带作者身份，进入
资料仍走正常权限与错误边界。

## 内容写入与读取

页面在提交时冻结标题、正文、标签、网络图片和本地图片选择，避免上传期间编辑改写在途命令。创建按
完整参数指纹复用幂等键；编辑、状态转换与删除携带最后读取的 revision。冲突、超时或结果不确定时
保留输入并要求显式刷新/重试，不自动换标识重复权威写入。

图片先校验类型、大小和数量，再并行上传；任一上传失败则不发送帖子写请求。生成 SDK 承载网关模型，
repository 负责 multipart 与业务适配。帖子详情将正文、评论首屏/分页/排序、互动状态分别建模；评论
楼中楼先展示已有预览，展开后按接口分页。首屏和分页失败都保留可恢复入口，不伪装为空评论。

资料帖子与收藏使用带身份的 family provider。列表成为当前 tab、或从子路由返回且仍为当前 tab 时
重新请求第一页；首屏代次与分页代次均不能让旧结果覆盖新状态。点赞、收藏、关注只在服务端成功后
收敛，进行中的重复操作被抑制，失败回滚局部乐观状态。

## 行为反馈

客户端只拥有曝光、点击、停留、浏览、播放、分享、隐藏和不喜欢事件；点赞、评论、收藏和关注等权威
动作不重复上报。`PostCard` 由可见性事件驱动：同一 requestId/postId 达到 50% 且连续 1 秒只记录一次
曝光，离开可见区记录停留。

事件按身份/会话分组进入持久队列，单批最多 100 条。只有服务端逐项接受或永久拒绝后才删除；临时失败
指数退避且不阻塞用户主操作。反馈始终保留请求、位置、来源、版本和实验上下文。

## 条款映射

| 条款 | 设计位置 |
| --- | --- |
| `FX-020`、`FX-021`、`FX-022` | 发现与搜索 |
| `FX-030`、`FX-031`、`FX-032` | 内容写入与读取 |
| `FX-060`、`FX-061`、`FX-062` | 行为反馈 |
