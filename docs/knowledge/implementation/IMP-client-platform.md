---
id: IMP-client-platform
layer: implementation
title: 客户端平台实现映射
status: unknown
owner: agent
upstream:
  - DES-client-platform
tracks:
  - FX-001
  - FX-002
  - FX-010
  - FX-070
  - FQ-001
  - FQ-002
  - FQ-003
  - FQ-006
  - FQ-007
  - FQ-008
code_paths:
  - lib/app.dart
  - lib/core/api
  - lib/core/auth
  - lib/core/router
  - lib/mock
  - lib/sdk
  - vendor/sdk_source
  - tools/sync_gateway_sdk.py
evidence:
  - EVD-assistant-research-2026-09-05
  - EVD-audit-remediation-client-2026-08-31
  - EVD-code-quality-hardening-2026-09-05
  - EVD-desktop-nav-semantics-2026-09-05
updated_at: 2026-09-06
---

# 客户端平台实现映射

应用壳、路由、身份与通用 transport 位于 `lib/app.dart` 和 `lib/core`；Mock 通过 HTTP client 注入复用
feature 路径。生成 SDK 的来源与应用副本由 `tools/sync_gateway_sdk.py` 同步，业务修补留在 core 或
repository。本页不保存观察提交；版本和命令只进入证据页。

历史 EVD 保留当时结果但已 `superseded`，不能自动证明当前 HEAD。以下表是本领域唯一当前权威映射；
首轮迁移先保持未知，待当前提交完成声明 gate 后由新 EVD 收敛。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-001 | DES-client-platform | unknown | gap: post-migration current-revision route and public-read gate pending |
| FX-002 | DES-client-platform | unknown | gap: post-migration current-revision auth-boundary gate pending |
| FX-010 | DES-client-platform | unknown | gap: post-migration current-revision session-recovery gate pending |
| FX-070 | DES-client-platform | unknown | gap: post-migration current-revision shared Mock/real path gate pending |
| FQ-001 | DES-client-platform | unknown | gap: post-migration current-revision dependency and state-owner gate pending |
| FQ-002 | DES-client-platform | unknown | gap: current SDK regeneration and int64 regression gate pending |
| FQ-003 | DES-client-platform | unknown | gap: post-migration current-revision error-classification gate pending |
| FQ-006 | DES-client-platform | unknown | gap: post-migration current-revision async-state gate pending |
| FQ-007 | DES-client-platform | unknown | gap: declared current validation commands have not run on the migration commit |
| FQ-008 | DES-client-platform | unknown | gap: migrated graph and validator fixtures have not passed on a committed revision |
