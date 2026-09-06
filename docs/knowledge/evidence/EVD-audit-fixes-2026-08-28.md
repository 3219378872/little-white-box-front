---
id: EVD-audit-fixes-2026-08-28
layer: evidence
title: 审查修复 2026-08-28
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-002
  - FX-010
  - FX-030
  - FQ-002
  - FQ-006
  - FQ-007
scope:
  - static
  - unit
commands:
  - make analyze
  - make test-coverage
  - make knowledge-check
observed_commit: 291097faf360b4bac3a8d7875d7c69d7b863011c
updated_at: 2026-08-28
---

# 审查修复 2026-08-28

## 范围

- 普通 API 与 Assistant SSE 仅在 refresh token 被明确认证拒绝时清会话；网络/5xx 保留凭据并返回可重试错误。
- 发帖和评论按完整命令指纹复用幂等键；本地图片上传结果在相同选择上复用。
- 后端 Memory PATCH nullable primitive 契约同步到两份 SDK；同步脚本修补 goctl 的 nullable
  primitive JSON 代码生成缺陷并有 Python 单测。
- 覆盖率只排除 `lib/sdk/api/gateway.dart` 与 `lib/sdk/data/gateway.dart` 两份明确生成物；应用 transport、
  repository、状态机与页面仍计入 70% 门禁。

## 命令与结果

```text
make analyze
# No issues found

make test-coverage
# 313 tests passed
# handwritten total: 5293/6824 lines (77.6%), threshold 70%

python3 -m unittest discover -s tools -p 'test_*.py'
# 2 tests passed

make knowledge-check
# OK (31 formal documents, 41 requirements, 70 local links)
```

跨仓真实栈使用后端 `249f766` 与本提交构建 release bundle：E2E 116 passed / 1 skipped；跳过项为
外部 LLM 条件，不影响本证据覆盖的 transport、幂等或 SDK 路径。

## 未证明范围

- 未人为等待 access token 自然过期 30 分钟；刷新成功、认证拒绝、网络失败和 503 由 transport 测试覆盖。
- 视频/语音私信仍受既有 Gateway 上传能力缺口约束。
