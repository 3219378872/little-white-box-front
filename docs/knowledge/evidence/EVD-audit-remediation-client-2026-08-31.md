---
id: EVD-audit-remediation-client-2026-08-31
layer: evidence
title: 客户端会话隔离与 Assistant 写入并发整改 2026-08-31
status: partial
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-002
  - FX-010
  - FX-020
  - FX-040
  - FX-041
  - FX-050
  - FX-081
  - FX-082
  - FX-085
  - FQ-002
  - FQ-003
  - FQ-006
  - FQ-007
  - FQ-008
updated_at: 2026-08-31
observed_commit: fd31aa39ce428e2dbc5bc4af395897c5cf6b04f8
---

# 客户端会话隔离与 Assistant 写入并发整改 2026-08-31

## 范围

在 `task/audit-remediation` 工作树修复跨账号会话竞态与缓存污染：持久令牌加入 session revision，
refresh/401/multipart/SSE 全部按请求快照条件替换或删除；认证状态变更串行发布，公开与受保护 provider
按 session identity 重建。Feed、Comment、Interaction、Post detail、Profile、User posts、Message 与
Assistant 新增账号 A 请求迟到于账号 B 的回归覆盖。

同步同级后端实现提交
`f21b68795233b34ee07ffa5c574bb8f06add9ac6` 的 `gateway.api`，生成 Watch `expectedVersion`、更新响应
task/version 与 Assistant run `streamId` 契约。Memory 写入按完整命令指纹复用 requestId，并修复
changeId 在刷新与 undo 失败后的可恢复性；Watch 更新/删除采用 version CAS，冲突后刷新权威列表。

## 验证

在前端 `task/audit-remediation` 工作树实际执行：

实现提交 `fd31aa39ce428e2dbc5bc4af395897c5cf6b04f8` 已 rebase 到前端 `main`
`63966e26b9a97980abe4a63c7f55dd77423432b3`，冲突解决保留主线的 grapheme 分块、`streamId` 与
reset 状态机，并叠加本次 session fencing、Watch CAS 与 Memory 幂等改动。rebase 后重新执行：

```text
make analyze
# No issues found

make test
# 396 tests passed

make test-coverage
# 396 Flutter tests + 4 Python tests passed
# total line coverage: 6355/7995 lines (79.5%), threshold 70%

flutter test test/features/assistant/data/assistant_repository_test.dart
# 12 tests passed（含补充的自定义 SSE token 与持久会话隔离）

python3 tools/test_sync_gateway_sdk.py
# 3 tests passed

make knowledge-check
# OK (38 formal documents, 48 requirements, 80 local links)
```

`vendor/sdk_source/data/gateway.dart` 与 `lib/sdk/data/gateway.dart` 经逐字比较一致，`git diff --check`
通过。聚焦测试还覆盖 refresh single-flight、旧 refresh/401 对新账号无效、跨账号迟到读取、Message
load/read/send generation、Memory requestId/undo 与 Watch `409/2007` 收敛。

## 未证明范围

- 本页证据仍以单元、Widget、Mock transport 和静态门禁为主，故保持 `partial`。
- 尚未在真实同源栈和浏览器执行账号切换、Watch version conflict、Memory 失败重试/undo。
- 同级后端 Watch 契约已形成稳定提交；三仓合并后仍需做真实栈回归。
- 未覆盖真机图片选择上传、外部 live provider 或生产 profile/迁移。
