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
- lib/features/interaction
updated_at: 2026-09-25
---

# 社区发现与内容实现映射

推荐/关注、搜索、帖子/评论、互动、资料列表和行为队列分别位于对应 feature 目录。repository 使用共享
transport，notifier 以 generation 与命令指纹控制分页、刷新和重试；presentation 只消费状态与命令。
历史证据不作为当前版本通过依据。

评论回复首屏失败仍重试第一页，发送成功后重置展开态与缓存；互动以每个消费者的服务器关系快照
计算乐观贡献差，避免刷新或打开详情时重复累计。编辑器、资料关注与搜索字段校验继续由定向及全量
回归覆盖。历史验证见 `EVD-quality-fixes-2026-09-19`，本轮验证在后续证据提交登记。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-020 | DES-community-client | aligned | EVD-quality-fixes-2026-09-19 |
| FX-021 | DES-community-client | aligned | EVD-quality-fixes-2026-09-19 |
| FX-022 | DES-community-client | aligned | EVD-quality-fixes-2026-09-19 |
| FX-030 | DES-community-client | aligned | EVD-quality-fixes-2026-09-19 |
| FX-031 | DES-community-client | aligned | EVD-quality-fixes-2026-09-19 |
| FX-032 | DES-community-client | aligned | EVD-quality-fixes-2026-09-19 |
| FX-060 | DES-community-client | aligned | EVD-quality-fixes-2026-09-19 |
| FX-061 | DES-community-client | aligned | EVD-quality-fixes-2026-09-19 |
| FX-062 | DES-community-client | aligned | EVD-quality-fixes-2026-09-19 |
