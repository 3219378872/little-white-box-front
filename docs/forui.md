# Forui 开发指南

Forui 是本项目新建和迁移界面的首选组件库。本文记录官方文档入口、当前集成方式以及项目内的使用约束；它不复制官方完整教程。

## 官方 LLM 文档

| 入口 | 用途 |
| --- | --- |
| <https://forui.dev/docs/llms.txt> | 精简索引，列出概念、指南、组件和参考页面。先用它定位与任务相关的文档。 |
| <https://forui.dev/docs/llms-full.txt> | 完整 Markdown 教程，包含 API 说明和代码示例。需要全面上下文或精确用法时查阅。 |

推荐的查阅顺序：

1. 在 `llms.txt` 中找到相关组件、主题或指南。
2. 优先阅读索引指向的具体页面，避免加载与任务无关的完整文档。
3. 需要跨组件上下文、完整示例或无法确定具体页面时，再查阅 `llms-full.txt`。
4. 对照 `pubspec.lock` 确认本项目实际使用的 Forui 版本。

这两个在线入口反映 Forui 当前发布的文档，可能与本项目锁定的 `0.24.2` 产生差异。出现接口不一致时，不要照搬最新示例；应核对对应版本的 pub.dev API 文档和 Forui 升级说明，再决定升级依赖还是采用当前版本写法。

## 当前集成

- `lib/app.dart` 保留 `MaterialApp.router`，在其 builder 中统一挂载 `FTheme`、`FToaster` 和 `FTooltipGroup`，同时注册 `FLocalizations` 支持的 locale 与 delegate。
- `lib/core/theme/app_theme.dart` 同时维护 Material 和 Forui 的亮暗主题。Forui 使用 neutral 基础主题、项目品牌主色，并根据运行平台选择 touch 或 desktop variant。
- `lib/core/router/app_router.dart` 的主导航壳使用 `FScaffold` 和 `FBottomNavigationBar`。页面仍可按迁移进度混用 Material 与 Forui。
- `test/helpers/forui_test_builder.dart` 为依赖 Forui theme 的 Widget 测试提供统一 builder。

不要在 feature 页面重复创建 `FTheme`、toaster 或 tooltip group。全局能力缺失时，应先判断它是否属于应用壳，再在共享入口补充。

## 组件与样式约束

- 新建或迁移 UI 时，先在官方索引中查找等价的 Forui 组件；存在合适组件时优先使用它。
- 图标优先使用 Forui 内置的 `FLucideIcons`，避免手绘 SVG 或为单个图标增加依赖。
- Material 与 Forui 可以共存。应用壳、尚未迁移的界面或 Forui 没有合适等价物的场景可以继续使用 Material。
- 公共颜色、排版和组件风格在 `AppTheme` 中维护。页面级差异优先使用主题提供的 style 或 delta 能力，不复制整套主题数据。
- 所有主题调整都要检查亮色、暗色以及 touch、desktop variant。不要只按当前开发设备硬编码平台样式。
- toast、tooltip 等 overlay 组件应使用应用根节点已经提供的上下文，不在局部嵌套重复的全局容器。
- 不因单个界面迁移而重写无关页面。组件迁移应保持现有路由、状态管理和数据行为不变。

## 测试与验证

依赖 Forui theme 的 Widget 测试应使用统一 helper：

```dart
MaterialApp(
  builder: foruiTestBuilder,
  home: const WidgetUnderTest(),
)
```

测试文件导入 `test/helpers/forui_test_builder.dart`。如果被测组件还依赖 toaster、tooltip 或本地化能力，应按实际依赖补充最小测试壳，并考虑将重复装配提升到共享 helper。

完成 Forui 相关修改后，按变更范围运行：

```bash
make analyze
make test
```

涉及依赖升级时，先更新约束并运行 `make setup`，检查 `pubspec.lock` 差异，再执行静态分析和完整测试。升级后还应核对 Forui 的 upgrading 指南和 data-driven fixes，避免保留已废弃 API。
