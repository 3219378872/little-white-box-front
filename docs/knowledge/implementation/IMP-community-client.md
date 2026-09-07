---
id: IMP-community-client
layer: implementation
title: 社区发现与内容实现映射
status: active
owner: agent
code_paths:
- lib/features/feed
- lib/features/search
- lib/features/post
- lib/features/comment
- lib/features/profile
- lib/features/behavior
updated_at: 2026-09-07
---

# 社区发现与内容实现映射

推荐/关注、搜索、帖子/评论、资料列表和行为队列分别位于对应 feature 目录。repository 使用共享
transport，notifier 以 generation 与命令指纹控制分页、刷新和重试；presentation 只消费状态与命令。
历史证据不作为当前版本通过依据。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-020 | DES-community-client | aligned | EVD-module-refactor-2026-09-07 |
| FX-021 | DES-community-client | aligned | EVD-module-refactor-2026-09-07 |
| FX-022 | DES-community-client | aligned | EVD-module-refactor-2026-09-07 |
| FX-030 | DES-community-client | aligned | EVD-module-refactor-2026-09-07 |
| FX-031 | DES-community-client | aligned | EVD-module-refactor-2026-09-07 |
| FX-032 | DES-community-client | aligned | EVD-module-refactor-2026-09-07 |
| FX-060 | DES-community-client | aligned | EVD-module-refactor-2026-09-07 |
| FX-061 | DES-community-client | aligned | EVD-module-refactor-2026-09-07 |
| FX-062 | DES-community-client | aligned | EVD-module-refactor-2026-09-07 |
