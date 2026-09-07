---
id: EVD-dart-format-gate-2026-09-07
layer: evidence
title: Dart 格式门禁与基线验证 2026-09-07
status: active
result: passed
owner: agent
scope:
- static
- unit
- integration
commands:
- make format-check
- make analyze
- make test
- make tools-test
- make sdk-check BACKEND_API=/home/dev/projects/little/little-white-box-content-community/app/gateway/gateway.api
- make check BACKEND_API=/home/dev/projects/little/little-white-box-content-community/app/gateway/gateway.api
- git show --check --format=fuller 33d59320a4b7167d0497d9bfaeaba6ed9138e0ce
observed_commit: 33d59320a4b7167d0497d9bfaeaba6ed9138e0ce
updated_at: 2026-09-07
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
  - lib/core/api
  - lib/core/auth
  - lib/core/router
  - lib/mock
  - lib/sdk
  - vendor/sdk_source
  - tools
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - test
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
- requirements:
  - FX-041
  paths:
  - lib/features/message
  - test/features/message
- requirements:
  - FX-050
  - FX-051
  - FX-086
  - FX-091
  - FX-092
  paths:
  - lib/features/assistant
  - test/features/assistant
- requirements:
  - FQ-004
  paths:
  - lib/core/theme
  - lib/core/widgets
  - lib/core/router/app_router.dart
  - test/helpers/forui_test_builder.dart
  - tools/heybox_visual_check.mjs
  - tools/heybox_android_check.py
---

# Dart 格式门禁与基线验证

本页观察前端提交 `33d59320a4b7167d0497d9bfaeaba6ed9138e0ce`。该提交新增只读
`make format-check`，以 `dart format --output=none --set-exit-if-changed lib test` 阻止格式偏移，
并将它纳入 `make check`；随后由 Dart formatter 重排 32 个既有偏移文件。没有改变业务逻辑、公开
API、依赖版本或生成 SDK 契约。

本次只重验因 `Makefile` 和格式化输入变化而失效的已对齐组。原有 INT、SPEC、DES、未知与 diverged
结论保持不变；旧 EVD 保留其历史观察，不被改写。

## 实际结果

| 命令 | 结果 |
| --- | --- |
| `make format-check` | exit 0，173 个 `lib`/`test` Dart 文件均已格式化，0 个待变更 |
| `make analyze` | exit 0，`No issues found` |
| `make test` | exit 0，496 项 Flutter 测试全部通过 |
| `make tools-test` | exit 0，51 项维护工具测试通过 |
| `make sdk-check BACKEND_API=...` | exit 0，Gateway SDK 非写入重生成比较无漂移 |
| `make check BACKEND_API=...` | exit 0，包含格式、分析、测试、知识和 SDK 全部质量入口通过 |
| `git show --check ...` | exit 0，无空白错误 |

## 未覆盖边界

本页仅证明本地静态分析、单元/Widget、Mock transport 集成、维护工具和 SDK 比较。它不替代浏览器、实体
设备、真实网关、真实 provider 或生产验证；现有 `unknown` 与 `diverged` 条款及其 gap 保持原样。
