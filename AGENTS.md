# AGENTS.md

这是小白盒内容社区的 Flutter 前端仓库。Flutter 应用位于仓库根目录；项目开发约束以本文件为入口，专项说明按 `docs/` 中的文档执行。

## 项目事实

- 应用使用 Flutter、Riverpod 和 GoRouter；日常 Flutter 命令均从仓库根目录运行。
- 当前选定的组件库是 Forui，`pubspec.yaml` 声明 `forui: ^0.24.2`，实际解析版本以 `pubspec.lock` 为准。
- 应用允许 Material 与 Forui 共存。现有 `MaterialApp.router` 负责 Flutter 应用壳，Forui 主题、组件和 overlay 能力由全局 builder 注入。
- `vendor/sdk_source/` 是生成 SDK 的来源，`lib/sdk/` 是应用使用的副本；应用适配应优先放在 `lib/core/api/` 或 feature repository 中。

## Forui 文档与版本边界

- 项目内指南见 [docs/forui.md](docs/forui.md)。涉及 Forui 的任务应先读取该文件。
- 使用 <https://forui.dev/docs/llms.txt> 查找相关概念、组件或指南页面。
- 需要完整教程、API 细节或代码示例时，使用 <https://forui.dev/docs/llms-full.txt>，或打开索引中对应的具体页面。
- 官方在线文档可能先于项目依赖更新。若示例与本仓库不兼容，以 `pubspec.lock` 中的版本和当前代码可用 API 为准，并查阅对应版本的 pub.dev API 文档或升级说明；不得凭最新文档直接假定旧版本支持相同接口。

## UI 开发规则

- 新建界面或迁移现有界面时，有等价能力则优先使用 Forui 组件和 `FLucideIcons`。
- Material 仍可用于应用壳、无合适 Forui 等价物的能力和未纳入当前任务的既有界面；不要在无关任务中进行全量组件迁移。
- 共享颜色、排版和组件样式集中维护在 `lib/core/theme/app_theme.dart`。不要在页面内创建独立 `FTheme` 或复制品牌色。
- 保留 `lib/app.dart` 中的 Forui 本地化、`FTheme`、`FToaster` 和 `FTooltipGroup` 全局装配。新增 toast、tooltip 等组件时复用这些上层能力。
- 主题必须同时覆盖亮色和暗色，并继续根据目标平台选择 touch 或 desktop variant。
- 依赖 Forui theme 的 Widget 测试使用 `test/helpers/forui_test_builder.dart` 提供的 `foruiTestBuilder`，不要为每个测试重复搭建主题。
- 引入新的 UI 依赖前，先确认 Forui 和 Flutter SDK 是否已提供所需能力。

## 命令入口

- `make setup`：解析 Flutter 依赖。
- `make analyze`：运行静态分析。
- `make test`：运行测试套件。
- `make dev`：使用仓库内 Mock API 启动 Web 开发模式。
- `make dev-real SERVER_HOST=http://127.0.0.1:8888`：连接真实网关启动 Web。
- `make help`：查看完整命令列表。

根据变更范围执行相关检查；完成任务时报告实际运行的命令和结果。
