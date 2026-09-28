---
id: IMP-messaging-client
layer: implementation
title: 一对一私信实现映射
status: active
owner: agent
code_paths:
- lib/features/message
- test/features/message
- lib/features/media
- lib/core/api/api_adapter.dart
updated_at: '2026-09-27'
---

# 一对一私信实现映射

会话、线程、发送命令和已读状态位于 `lib/features/message`。文本和图片发送路径存在，幂等重试保留
完整命令；`receiverId` 和 `mediaId` 经共享 int64 编码器输出 JSON number。视频与音频经新 Gateway 契约上传，媒体任务复用上传键并保留上传结果，消息服务检查媒体归属及类型。
本轮验证见 `EVD-media-uploads-2026-09-27`。

初始历史与读取期间发送的新消息按 ID 合并，发送/重试完成保护新草稿，非法未读汇总保留旧计数；
这些局部修复见 `EVD-quality-remediation-2026-09-25`；本轮媒体能力由上述新证据独立覆盖。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-040 | DES-messaging-client | unknown | gap: OpenAPI SDK 与工具链迁移，待新提交上的对应验收证据。 |
| FX-041 | DES-messaging-client | unknown | gap: OpenAPI SDK 与工具链迁移，待新提交上的对应验收证据。 |
