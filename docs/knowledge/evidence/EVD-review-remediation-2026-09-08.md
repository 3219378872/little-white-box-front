---
id: EVD-review-remediation-2026-09-08
layer: evidence
title: 全面审查前端修复与确定性回归验证
status: active
result: passed
owner: agent
scope:
- static
- unit
commands:
- make format-check analyze
- flutter test --no-pub --reporter expanded
- make tools-test KNOWLEDGE_PYTHON=/home/dev/projects/little/little-white-box-front/.venv-knowledge/bin/python
- make sdk-check BACKEND_API=/home/dev/projects/little/little-white-box-content-community/.worktree/task-review-remediation/app/gateway/gateway.api
- make knowledge-index KNOWLEDGE_PYTHON=/home/dev/projects/little/little-white-box-front/.venv-knowledge/bin/python
- make check BACKEND_API=/home/dev/projects/little/little-white-box-content-community/.worktree/task-review-remediation/app/gateway/gateway.api
  KNOWLEDGE_PYTHON=/home/dev/projects/little/little-white-box-front/.venv-knowledge/bin/python
artifacts:
- docs/knowledge/evidence/assets/review-remediation-2026-09-08/validation-summary.json
observed_commit: 775df64d9e09800412469f76668f1822e233e24f
updated_at: '2026-09-08'
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

# 全面审查前端修复与确定性回归验证

本页观察前端实现提交 `775df64d9e09800412469f76668f1822e233e24f`。开始验证时 task 工作树干净；
先在该提交完成下列代码门禁，再新增本证据和实现映射，不以证据提交自指。设计承接见
[平台](../design/DES-client-platform.md)、[社区](../design/DES-community-client.md)和
[Assistant](../design/DES-assistant-client.md)。

## 审查范围与回归

工作区本轮审查共 17 项，本页只证明其中涉及前端的 R01、R05、R08、R13、R15、R16，不把根编排或
后端独立实现的验证纳入前端结论。与修复前 497 项相比，本次 Flutter 套件为 533 项，净增 36 项；
维护工具从 51 项增至 52 项，另有既存用例改为符合真实响应的测试数据。

| 分项 | 前端修复与确定性验证 | 新增 Flutter 用例 |
| --- | --- | --- |
| R01 | SDK JSON、multipart 与 Assistant SSE 从请求开始固定会话 revision；刷新期间登录另一账号或登出不得以新身份重发旧命令，匿名请求也绑定原 revision | 7 |
| R05 | 持久行为队列保存稳定账号归属；重启、换号、重新登录同一账号、匿名会话和异步初始化均不串号；旧记录缺失归属时保留但不发送 | 4 |
| R08 | HTTP 200 的非对象、非法业务码和缺失读取字段进入失败；typed `{}` 与显式 void 信封有效，Go nil slice 保留空列表语义；验证码仓储拒绝 null/空 body/HTML | 18 |
| R13 | `UpdatePostV2Req` 由生成工具保留 images/mediaIds presence；省略字段不变更媒体，显式空数组保留清空意图；两份生成 SDK 一致 | 3 |
| R15 | 评论排序/首屏/分页使用 generation，旧成功和旧失败不覆盖新列表，旧分页不污染新排序 | 3 |
| R16 | 资料列表刷新使旧分页失效并解除 busy；刷新失败后仍可重新分页，迟到旧页不追加 | 1 |

R08 的既有验证码 Widget 测试现走真实 `AuthRepository` 与 SDK：raw `{}` 启动 60 秒倒计时并防重发，
raw `null` 显示失败且不进入倒计时。后端验证码成功响应应按生成的 `SendVerifyCodeResp` 返回对象；
本页不以 fake transport 证明真实短信已发送。Assistant SSE 使用独立流消费，不经过 JSON 成功体校验。
R13 仅证明 Dart 请求保留媒体变更意图及生成一致性，不证明服务端媒体归属检查或数据库映射重建。

聚焦回归文件位于 `test/core/api/session_isolation_regression_test.dart`、
`test/core/api/response_validation_test.dart`、`test/features/auth`、
`test/features/behavior/data/behavior_identity_test.dart`、`test/sdk/post_update_presence_test.dart`、
`test/features/comment/application/comment_generation_test.dart` 与
`test/features/profile/application/user_posts_notifier_test.dart`。

## 实际结果

| 检查 | 结果 |
| --- | --- |
| `make format-check analyze` | exit 0；203 个 Dart 文件、0 个待格式化变更，analyze 无问题 |
| `flutter test --no-pub --reporter expanded` | exit 0；533 项全部通过，约 37 秒 |
| `make tools-test KNOWLEDGE_PYTHON=...` | exit 0；52 项全部通过 |
| `make sdk-check BACKEND_API=...` | exit 0；临时重生成，`lib/sdk` 与 `vendor/sdk_source` 均无生成漂移 |
| `make knowledge-index KNOWLEDGE_PYTHON=...` | exit 0；刷新证据与实现层索引 |
| `make check BACKEND_API=... KNOWLEDGE_PYTHON=...` | exit 0；格式、分析、533 项 Flutter、52 项工具、知识与 SDK 总门禁通过 |

总门禁在新增证据与映射后执行，源码、测试、依赖和生成输入仍与观察提交一致。知识校验为 63 个正式
文档、54 个条款，状态仍为 25 aligned、28 unknown、1 diverged；另以所属仓 YAML 解析器核对五组
coverage 与旧记录完全一致，并逐行确认所有 unknown/diverged 未改变。

SDK 检查显式使用后端 task 工作树的 `app/gateway/gateway.api`，输入 SHA-256 为
`b8b4438226607295c964647a1ca66d1b328e72f159ca3e2686c968af3158b7cc`。正式跨仓语义引用未改变。
持久结果摘要见本页 artifacts；运行原始日志暂存于
`/tmp/little-review-fix-validation-20260908-ka9yNl/frontend-validation.log`，不把临时日志作为唯一证据。

## 证明边界

五个 coverage 组的 requirements 与 paths 完整保留
[EVD-module-refactor-2026-09-07](EVD-module-refactor-2026-09-07.md) 的范围，包含共享应用、测试、
工具、依赖与 Web 输入，不缩窄历史输入快照。只刷新原有 25 条 aligned 映射，所有 unknown/diverged
及其 gap 保持原样；旧 EVD 的观察、结果和浏览器产物不改写。

本次 scope 只有 static/unit，覆盖确定性单元、Widget、fake/Mock transport、维护工具和生成比较。
没有运行真实网关、真实数据库、真实短信或媒体上传、真实模型/provider、浏览器、原生/实体设备、
容量或生产验证；没有重测覆盖率，不能沿用历史 81.7% 为本提交结果。旧浏览器通过记录不视为本次
重新验收。`FQ-007`、设备/视觉条款、Assistant 真实交互未知项及私信媒体能力差异均不因此升级。
