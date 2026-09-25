---
id: IMP-messaging-client
layer: implementation
title: 一对一私信实现映射
status: active
owner: agent
code_paths:
- lib/features/message
- test/features/message
updated_at: 2026-09-25
---

# 一对一私信实现映射

会话、线程、发送命令和已读状态位于 `lib/features/message`。文本和图片发送路径存在，幂等重试保留
完整命令；`receiverId` 和 `mediaId` 经共享 int64 编码器输出 JSON number。当前网关没有可供私信闭环
使用的视频和语音上传契约，因此不能把 `FX-040` 标为对齐。

初始历史与读取期间发送的新消息按 ID 合并，发送/重试完成保护新草稿，非法未读汇总保留旧计数；
这些局部修复见 `EVD-quality-remediation-2026-09-25`，不关闭上述媒体能力缺口。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-040 | DES-messaging-client | diverged | gap: backend gateway has no video or voice upload contract, so those media sends cannot complete |
| FX-041 | DES-messaging-client | aligned | EVD-quality-remediation-2026-09-25 |
