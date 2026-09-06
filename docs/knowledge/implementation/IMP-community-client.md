---
id: IMP-community-client
layer: implementation
title: 社区发现与内容实现映射
status: unknown
owner: agent
upstream:
  - DES-community-client
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
code_paths:
  - lib/features/feed
  - lib/features/search
  - lib/features/post
  - lib/features/comment
  - lib/features/profile
  - lib/features/behavior
evidence:
  - EVD-audit-remediation-client-2026-08-31
  - EVD-code-quality-hardening-2026-09-05
  - EVD-heybox-presentation-2026-09-06
updated_at: 2026-09-06
---

# 社区发现与内容实现映射

推荐/关注、搜索、帖子/评论、资料列表和行为队列分别位于对应 feature 目录。repository 使用共享
transport，notifier 以 generation 与命令指纹控制分页、刷新和重试；presentation 只消费状态与命令。
历史证据不作为当前版本通过依据。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-020 | DES-community-client | unknown | gap: current recommendation pagination and attribution tests pending |
| FX-021 | DES-community-client | unknown | gap: current authenticated following-feed tests pending |
| FX-022 | DES-community-client | unknown | gap: current search degradation and failure-state tests pending |
| FX-030 | DES-community-client | unknown | gap: current write idempotency and revision tests pending |
| FX-031 | DES-community-client | unknown | gap: current detail, comment, interaction, and profile-list tests pending |
| FX-032 | DES-community-client | unknown | gap: current input and transactional image-upload tests pending |
| FX-060 | DES-community-client | unknown | gap: current event-ownership regression tests pending |
| FX-061 | DES-community-client | unknown | gap: current visibility and attribution tests pending |
| FX-062 | DES-community-client | unknown | gap: current durable queue and retry tests pending |
