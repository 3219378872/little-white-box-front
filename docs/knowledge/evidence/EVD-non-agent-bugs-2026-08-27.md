---
id: EVD-non-agent-bugs-2026-08-27
layer: evidence
title: 非 Agent 模块缺陷修复 2026-08-27
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-002
  - FX-010
  - FX-021
  - FX-022
  - FX-030
  - FX-031
  - FX-061
  - FQ-006
  - FQ-007
updated_at: 2026-08-27
observed_commit: 53511f3
---

# 非 Agent 模块缺陷修复 2026-08-27

## 范围与环境

工作树 `.worktree/task-non-agent-bugs`。修复审查中确认的非 Assistant 缺陷：V2 换发后
Authorization 被调用方缓存头覆盖、换发网络失败误清会话、关注流空页 `hasMore` 死路、
搜索降级零命中伪装成空结果、Feed 刷新失败被当成加载更多、发帖/评论幂等键每点新造、
评论分页失败静默、评论输入未成功即清空、详情赞藏与资料关注未登录不跳转、互动连点竞态、
编辑资料未加载完可保存、卡片进后台后曝光计时不恢复。

## 命令与结果

```bash
flutter analyze --no-pub
# No issues found
flutter test
# 309 tests passed
```

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-010` | `_apiRequest` 在合并调用方 header 之后写入当前 `Authorization`；换发网络失败保留 refreshToken，`fail` 不再带认证码，`apiCall` 不触发 `onAuthError`。`test/sdk/api/token_refresh_test.dart` 覆盖缓存头重试与换发网络失败 |
| `FX-021` | `FeedNotifier` 在 `items` 为空且 `hasMore` 时继续翻页；`test/features/feed/application/feed_notifier_test.dart` 空页后续可见项 |
| `FX-022` | 综合搜索 `degraded` 在零命中时仍展示横幅；`null` 结果列表当空数组。`search_page_test` / `search_repository_test` |
| `FX-030` / `FQ-006` | 创建帖与评论对同一失败命令复用幂等键；评论分页失败设 `hasError`，重试续拉下一页而非伪装空区 |
| `FX-002` / `FX-031` | 详情赞/藏未登录跳转登录；`InteractionNotifier` 忽略进行中的重复点赞；评论提交成功后才清空输入 |
| `FX-061` | `PostCard` 从后台回到前台且仍 ≥50% 可见时重装 1 秒曝光计时 |
| `FQ-007` | 上述路径均有自动化测试；`flutter analyze --no-pub` 无 issue |

## 未证明范围

- 未连接真实网关验证 30 分钟 access token 过期后的 V2 换发重试。
- `GetUserResp` 仍无 `isFollowing`，他人资料关注按钮初始态未修。
- 私信视频/语音发送仍受网关缺口阻塞（`DIV-005`）。
