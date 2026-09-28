---
id: EVD-cloudwego-sdk-2026-09-28
layer: evidence
title: OpenAPI Gateway SDK 迁移验证
status: active
result: passed
owner: agent
scope:
- static
- unit
observed_commit: 9aff299e68a7160a69a5bd24e91fff2184c76666
updated_at: '2026-09-28'
external_upstream:
- little-white-box-content-community@e20814b5d91ffb2cb7f7bf52fbe2b15e64ae2be3:SPEC-community-core
commands:
- make check KNOWLEDGE_PYTHON=/home/dev/projects/little/little-white-box-front/.venv-knowledge/bin/python BACKEND_API=/home/dev/projects/little/little-white-box-content-community/.worktree/task-cloudwego-migration/app/gateway/openapi.yaml
- make build-web TARGET=lib/main.dart
artifacts:
- docs/knowledge/evidence/assets/cloudwego-migration-2026-09-28/validation-summary.json
coverage:
- requirements:
  - FQ-002
  paths:
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
  - android
---

# OpenAPI SDK 迁移验证

在观察提交运行组合门禁：627 项 Flutter 测试、47 项维护工具测试、分析、格式、知识与 SDK
漂移检查全部通过。真实入口 `lib/main.dart` 的 Web release 构建通过。SDK 两份副本由同一
OpenAPI 生成，契约提交与 SHA-256 记录在仓库内产物中。

生成规则覆盖无损 ID、JSON 别名、缺省与 nullable、PATCH 数组 presence、HTTP 动词和 query。
媒体与 SSE 只生成路由 helper，由原有应用传输消费；不再生成把文件/事件流当作普通 JSON 的空包装。
这些结果证明本次契约工具与现有应用兼容，不证明真实浏览器、设备或生产运行。
