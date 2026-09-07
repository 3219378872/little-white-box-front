---
id: EVD-dependency-major-upgrades-2026-09-07
layer: evidence
title: 客户端主要依赖升级验证 2026-09-07
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
- git show --check --format=fuller f3659ccc5be6ba1889e7e772866c3b65ea99ee37
observed_commit: f3659ccc5be6ba1889e7e772866c3b65ea99ee37
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

# 客户端主要依赖升级验证

本页观察前端提交 `f3659ccc5be6ba1889e7e772866c3b65ea99ee37`。该提交将 `go_router` 升到 18.0.1、
`flutter_riverpod` 升到 3.4.3、`cached_network_image` 升到 4.0.0、`connectivity_plus` 升到 7.3.1、
`forui` 升到 0.26.0；锁文件不再包含已停用的 `forui_assets`。`StateNotifier` 继续经
`package:flutter_riverpod/legacy.dart` 接入，`AppProviderScope` 关闭 Riverpod 3 默认失败重试。
Forui 0.26 改为 `material_ui` 本地化后，应用壳补回 Flutter `GlobalMaterialLocalizations` /
`GlobalCupertinoLocalizations`，以保持 `zh` 区域设置。Dart 3.13 formatter 顺带重排既有文件空白，
不改变业务语义。

## 实际结果

| 命令 | 结果 |
| --- | --- |
| `make format-check` | exit 0，174 个 `lib`/`test` Dart 文件均已格式化，0 个待变更 |
| `make analyze` | exit 0，`No issues found` |
| `make test` | exit 0，496 项 Flutter 测试全部通过 |
| `make tools-test` | exit 0，51 项维护工具测试通过 |
| `make sdk-check BACKEND_API=...` | exit 0，Gateway SDK 非写入重生成比较无漂移 |
| `git show --check ...` | exit 0，无空白错误 |

## 未覆盖边界

本页仅证明本地静态分析、单元/Widget、Mock transport 集成、维护工具和 SDK 比较。它不替代浏览器、实体
设备、真实网关、真实 provider 或生产验证；现有 `unknown` 与 `diverged` 条款及其 gap 保持原样。Android
AGP 已升到 8.12.1，但本次未跑 Gradle 组装或实体设备。
