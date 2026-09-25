---
id: EVD-quality-remediation-2026-09-25
layer: evidence
title: 前端并发、分页与订阅错误修复验证
status: active
result: passed
owner: agent
scope:
- static
- unit
commands:
- make format-check analyze
- flutter test --no-pub --coverage --reporter expanded
- python3 tools/lcov_summary.py coverage/lcov.info --min 70
- make tools-test KNOWLEDGE_PYTHON=/home/dev/projects/little/little-white-box-front/.venv-knowledge/bin/python
- PATH=/tmp/little-quality-tools-nsA9h9/bin:$PATH make sdk-check BACKEND_API=/home/dev/projects/little/little-white-box-content-community/.worktree/task-quality-remediation-20260925/app/gateway/gateway.api
- flutter build web --no-pub --release -t lib/main.dart
artifacts:
- docs/knowledge/evidence/assets/quality-remediation-2026-09-25/validation-summary.json
observed_commit: 3c575d3d0d6a235cf2176e233cc98a73fd951c28
updated_at: '2026-09-25'
coverage:
- requirements:
  - FX-001
  - FX-002
  - FX-010
  - FX-070
  - FQ-001
  - FQ-002
  - FQ-003
  - FQ-006
  - FQ-008
  paths:
  - lib/app.dart
  - lib/main.dart
  - lib/main_mock.dart
  - lib/core/api
  - lib/core/auth
  - lib/core/router
  - lib/core/state
  - lib/mock
  - lib/sdk
  - vendor/sdk_source
  - tools
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - android/settings.gradle.kts
  - test
  - lib
  - web
- requirements:
  - FX-020
  - FX-021
  - FX-022
  - FX-030
  - FX-031
  - FX-032
  - FX-060
  - FX-061
  - FX-062
  paths:
  - lib/features/feed
  - lib/features/search
  - lib/features/post
  - lib/features/comment
  - lib/features/profile
  - lib/features/behavior
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
  - lib/features/interaction
- requirements:
  - FX-041
  paths:
  - lib/features/message
  - test/features/message
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
- requirements:
  - FX-050
  - FX-051
  - FX-086
  - FX-091
  - FX-092
  paths:
  - lib/features/assistant
  - test/features/assistant
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
- requirements:
  - FQ-004
  paths:
  - lib/core/theme
  - lib/core/widgets
  - lib/core/router/app_router.dart
  - test/helpers/forui_test_builder.dart
  - tools/heybox_visual_check.mjs
  - tools/heybox_android_check.py
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
---

# 前端并发、分页与订阅错误修复验证

验证在上述固定实现提交执行；本页、摘要和 IMP 引用随后提交。603 项 Flutter 测试通过，
手写行覆盖率 8195/9812（83.5%），维护工具 52 项通过，格式与静态分析无问题，SDK 临时重生无漂移，
真实入口 lib/main.dart 的 release Web 构建通过。编译产物不构成浏览器运行证据。

| 缺陷 | 当前行为与回归 |
| --- | --- |
| multipart 响应体无限等待 | 单次期限覆盖 headers 和完整 body；迟到成功或 401 不再解码、刷新或发起重试 |
| 已轮换同会话收到迟到 401 | JSON、multipart、SSE 复用当前凭据重试一次；换号拒绝、第二次失败不循环 |
| 楼中楼失败后跳过第一页 | 未成功加载时重试 page 1；提交后折叠并清缓存，重新展开恢复第一页 |
| 点赞收藏重复叠加 | 每个旧/新快照按关系差计算本用户贡献；覆盖请求中刷新、反向操作、独立回滚 |
| SSE 错误被当成成功流 | HTTP 4xx 和 transport_error 保留不可重试语义，不产生持久事件或前进 cursor；等待计时器和线程轮询不自动重连已拒绝 run，人工重试保留 cursor，新 run 正常连接 |

沿用旧证据全部五个 coverage 组与输入范围，补入互动模块；刷新既有 25 个 aligned 声明，
unknown/diverged 及其真实环境门禁保持原义。历史证据结果不改写。
服务端聚合计数仍可最终一致，关系已收敛时显示接口返回数值，可能短暂回跳，不虚构原子计数。
客户端期限结束等待，不承诺取消服务端已开始的写入。真实接口、浏览器、设备、live-provider、
容量和生产未运行。本轮无公开 .api 契约变更。
