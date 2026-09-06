---
id: DES-messaging-client
layer: design
title: 一对一私信客户端设计
status: active
role: baseline
owner: agent
upstream:
  - SPEC-client-experience
external_upstream:
  - little-white-box-content-community@f706309f860621e7d9079333cf33e81557253b73:SPEC-community-core
tracks:
  - FX-040
  - FX-041
updated_at: 2026-09-06
---

# 一对一私信客户端设计

## 边界与状态

私信是认证用户间的一对一能力。会话列表、线程历史和未读数分别保存首屏、分页、局部失败与重试状态；
列表失败不把未读数归零，线程失败不影响其它会话。会话和消息标识始终沿用平台层的精确十进制表示。

## 读取与已读

会话列表和线程历史使用服务端游标，已有条目上的加载更多失败显示页脚重试并保留内容。进入线程后发送
已读命令；成功才更新当前用户的线程、列表和徽标，失败保留独立重试入口，不预测另一参与者状态。

## 发送

application 层创建 `SendMessageCommand`，包含接收者、类型、正文、可选 mediaId 和稳定幂等键。相同失败
命令重试复用整个对象，用户修改任一参数才创建新键。repository 校验文本边界并将 `receiverId`、
`mediaId` 编成不丢精度的 JSON number；发送成功后以服务端返回的 messageId 收敛。

媒体消息只引用当前用户已成功上传且有权使用的 mediaId。图片、视频和语音的选择/上传能力属于消息
发送闭环的一部分；客户端不能用 URL、占位按钮或错误类型冒充尚未获得的上传结果。当前实现缺口只在
实现层登记，不修改本设计或已批准规格。

| 条款 | 设计位置 |
| --- | --- |
| `FX-040` | 边界、分页和稳定发送命令 |
| `FX-041` | 已读与未读状态收敛 |
