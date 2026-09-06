---
id: EVD-assistant-isolation-2026-08-30
layer: evidence
title: Assistant 账号隔离与恢复状态机 2026-08-30
status: superseded
result: partial
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-002
  - FX-050
  - FX-055
  - FX-057
  - FX-058
  - FX-080
  - FX-083
  - FX-085
  - FX-088
  - FX-089
  - FX-090
  - FX-091
  - FX-093
  - FQ-002
  - FQ-006
  - FQ-007
  - FQ-008
scope:
  - static
  - unit
commands:
  - make analyze
  - make test
  - make knowledge-check
observed_commit: a0bc7abef22417cc5f3583420b7ffbda0d1ffdf6
updated_at: 2026-08-30
---

# Assistant 账号隔离与恢复状态机 2026-08-30

## 范围

在 `task/assistant-isolation` 工作树修复 Assistant 客户端审查项：所有有状态 provider 按认证
`userId` 重建，旧 notifier dispose 时取消 SSE；同 run redirect/steer/queued 保留 cursor，重连以独立
connection generation 屏蔽旧流 `onDone` 和重复 seq。发送失败保留 requestId、附件与 contextPostId，
confirm、Stop、memory undo 和 consent revoke 不再在请求失败时呈现成功。

消息读取对齐同级后端 `task/assistant-completeness` 工作树中的当前 `.api`：无 cursor 返回最新页，
`beforeId` 加载更早消息，`afterId` 只拉新增消息；响应含 `hasMore`、`nextBeforeId`。SDK 由该 `.api`
经 `tools/sync_gateway_sdk.py` 同步到 `vendor/sdk_source` 与 `lib/sdk`，新 ID 字段保留为 Object。

## 定向证据

- provider 容器测试在 user 1 的 SSE、附件、消息和 consent 存在时切到 user 2，断言 notifier 重建、
  旧订阅取消、旧事件不能进入新状态；logout 再次重建为空状态。
- SSE 测试断言 redirect/queued 不新建 seq=0 连接，重复 seq 不追加；旧连接 error 后的 onDone 不会
  终止新连接，新连接从最后 seq 恢复。
- application/repository/Widget 测试覆盖稳定重试命令、contextPostId、最新页和 before/after cursor、
  confirm/Stop 失败可重试、memory_changed undo、consent revoke，以及打开线程后接收 Watch 新消息。

## 验证

在 `task/assistant-isolation` 工作树实际执行：

```text
flutter test test/features/assistant/application/assistant_notifier_test.dart \
  test/features/assistant/application/assistant_agent_test.dart \
  test/features/assistant/data/assistant_repository_test.dart \
  test/features/assistant/presentation/assistant_page_test.dart \
  test/mock/mock_v2_transport_test.dart
# 48 tests passed

make analyze
# No issues found

make test
# 331 tests passed

python3 -m unittest discover -s tools -p 'test_*.py'
# 4 tests passed

make knowledge-check
# OK (33 formal documents, 47 requirements, 75 local links)
```

本页保持 `partial`，不以 Mock、单元或 Widget 测试替代真实网关与浏览器证据。

## 未证明范围

- 未在真实网关执行账号 A 流式中换到账号 B、代理断流重连或 Watch 定时投递。
- 未验证真机图片选择上传；GET 历史仍只消费后端已声明字段，不推测附件或 contextPostId。
- 同级后端分页契约来自并行 task 工作树；前后端 task 分支整合后仍需跨仓真实栈回归。
