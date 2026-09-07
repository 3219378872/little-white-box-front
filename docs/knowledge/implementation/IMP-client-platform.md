---
id: IMP-client-platform
layer: implementation
title: 客户端平台实现映射
status: active
owner: agent
code_paths:
- lib/app.dart
- lib/core/api
- lib/core/auth
- lib/core/router
- lib/mock
- lib/sdk
- vendor/sdk_source
- tools/knowledge_base.py
- tools/sync_gateway_sdk.py
- tools/test_knowledge_base.py
- tools/requirements-knowledge.txt
- Makefile
updated_at: 2026-09-07
---

# 客户端平台实现映射

应用壳、路由、身份与通用 transport 位于 `lib/app.dart` 和 `lib/core`；Mock 通过 HTTP client 注入复用
feature 路径。生成 SDK 的来源与应用副本由 `tools/sync_gateway_sdk.py` 同步，业务修补留在 core 或
repository。本页不保存观察提交；版本和命令只进入证据页。

历史 EVD 保留当时结果，按覆盖组判断是否仍能证明当前输入。以下表是本领域唯一当前权威映射；
当前本地门禁只收敛其实际覆盖的条款，要求真实接口与浏览器的 `FQ-007` 仍保持未知。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-001 | DES-client-platform | aligned | EVD-knowledge-slim-2026-09-07 |
| FX-002 | DES-client-platform | aligned | EVD-knowledge-slim-2026-09-07 |
| FX-010 | DES-client-platform | aligned | EVD-knowledge-slim-2026-09-07 |
| FX-070 | DES-client-platform | aligned | EVD-knowledge-slim-2026-09-07 |
| FQ-001 | DES-client-platform | aligned | EVD-knowledge-slim-2026-09-07 |
| FQ-002 | DES-client-platform | aligned | EVD-knowledge-slim-2026-09-07 |
| FQ-003 | DES-client-platform | aligned | EVD-knowledge-slim-2026-09-07 |
| FQ-006 | DES-client-platform | aligned | EVD-knowledge-slim-2026-09-07 |
| FQ-007 | DES-client-platform | unknown | gap: current evidence lacks the real-interface and browser validation required by the spec |
| FQ-008 | DES-client-platform | aligned | EVD-knowledge-slim-2026-09-07 |
