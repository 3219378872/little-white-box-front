# AGENTS.md

这是小白盒内容社区的 Flutter 前端仓库。Flutter 应用位于仓库根目录；项目开发约束以本文件为入口，
正式知识从 [docs/knowledge/README.md](docs/knowledge/README.md) 按需加载。

## 项目事实

- 应用使用 Flutter、Riverpod 和 GoRouter；日常 Flutter 命令均从仓库根目录运行。
- 当前选定的组件库是 Forui，`pubspec.yaml` 声明 `forui: ^0.24.2`，实际解析版本以 `pubspec.lock` 为准。
- 应用允许 Material 与 Forui 共存。现有 `MaterialApp.router` 负责 Flutter 应用壳，Forui 主题、组件和 overlay 能力由全局 builder 注入。
- `vendor/sdk_source/` 是生成 SDK 的来源，`lib/sdk/` 是应用使用的副本；应用适配应优先放在 `lib/core/api/` 或 feature repository 中。

## 知识权限与加载顺序

- 正式链路为“意图 → 规格 → 设计 → 实现 ↔ 证据”。先从知识总路由定位主题，不默认遍历整个 `docs/`。
- 意图和规格的语义所有权属于人类。agent 可按当前对话中的明确要求整理或修改；没有明确批准时保持
  `draft` 或 `baseline`，不得标为 `approved`。
- 只有 `approved` 意图/规格及其 `accepted` 设计约束未来实现。源码、配置、依赖锁、生成契约和测试是
  当前事实；偏离设计时将实现标记 `diverged`，不得反向修改上层掩盖差异。
- 修改行为时先定位规格条款，再读设计、实现和最近证据；完成后同步实现映射和带日期证据，保持实现与
  证据双向引用，并运行 `make knowledge-check`。
- `docs/knowledge/archive/` 仅为历史快照。涉及接口语义时还要重新核对同级后端仓库的当前意图、规格和
  生成契约，不能以归档联调文档代替。

## Forui 文档与版本边界

- 项目内指南见 [docs/knowledge/implementation/IMP-forui-ui.md](docs/knowledge/implementation/IMP-forui-ui.md)。涉及 Forui 的任务应先读取该文件。
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
- `make knowledge-check`：校验五层知识 ID、引用、条款覆盖、本地链接和实现—证据闭环。
- `make dev`：使用仓库内 Mock API 启动 Web 开发模式。
- `make dev-real SERVER_HOST=http://127.0.0.1:8888`：连接真实网关启动 Web。
- `make help`：查看完整命令列表。

根据变更范围执行相关检查；完成任务时报告实际运行的命令和结果。

## Task 工作树与提交

- 每个 task 开始前，先确认仓库根目录 `main` 工作树干净，再创建 `task/<task-name>` 分支及
  `.worktree/task-<task-name>` 工作树；所有任务编辑、验证和任务提交均在该工作树完成，并在编辑后立即
  检查实际工作目录与 `git status`，避免改到根目录。
- task 完成并在 task 分支形成提交后，回到仓库根目录，同步最新 `main`，再将 task 分支 rebase 到最新
  `main`。发生冲突时在 task 工作树解决，完成后重新运行受影响检查；不得通过丢弃任一侧改动绕过冲突。
- rebase 与验证通过后，在根目录将 `main` 以 fast-forward 方式整合到 task 提交，不创建额外 merge
  commit。确认 task 提交已可从 `main` 到达且根目录状态正确后，移除 `.worktree/task-<task-name>` 并
  删除 `task/<task-name>` 分支，最后推送 `main`。
- 不得在整合前清理工作树或强制删除 task 分支；不得把根目录中的无关改动带入 task 提交。完成时报告
  task 提交、rebase/冲突处理、清理、推送和实际验证结果。
