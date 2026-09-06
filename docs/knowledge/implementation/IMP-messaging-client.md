---
id: IMP-messaging-client
layer: implementation
title: 一对一私信实现映射
status: diverged
owner: agent
upstream:
  - DES-messaging-client
tracks:
  - FX-040
  - FX-041
code_paths:
  - lib/features/message
  - test/features/message
evidence:
  - EVD-audit-remediation-client-2026-08-31
updated_at: 2026-09-06
---

# 一对一私信实现映射

会话、线程、发送命令和已读状态位于 `lib/features/message`。文本和图片发送路径存在，幂等重试保留
完整命令；`receiverId` 和 `mediaId` 经共享 int64 编码器输出 JSON number。当前网关没有可供私信闭环
使用的视频和语音上传契约，因此不能把 `FX-040` 标为对齐。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-040 | DES-messaging-client | diverged | gap: backend gateway has no video or voice upload contract, so those media sends cannot complete |
| FX-041 | DES-messaging-client | unknown | gap: current conversation, read-state, and unread convergence tests pending |
