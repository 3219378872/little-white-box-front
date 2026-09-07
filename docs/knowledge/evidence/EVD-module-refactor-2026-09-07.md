---
id: EVD-module-refactor-2026-09-07
layer: evidence
title: 客户端职责拆分与浏览器回归验证
status: active
result: passed
owner: agent
scope:
- static
- unit
- integration
- browser
- synthetic
commands:
- make format-check analyze test-coverage sdk-check BACKEND_API=/home/dev/projects/little/little-white-box-content-community/.worktree/task-modularize/app/gateway/gateway.api
  KNOWLEDGE_PYTHON=/home/dev/projects/little/little-white-box-front/.venv-knowledge/bin/python
- flutter build web --release --no-pub -t lib/main_mock.dart --no-web-resources-cdn
  --dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/
- PLAYWRIGHT_MODULE=/tmp/lwb-playwright-runtime/node_modules/playwright/index.mjs
  BROWSER_BASE_URL=http://127.0.0.1:43008 BROWSER_OUTPUT_DIR=/tmp/little-modularize.Ju7CGp/browser-matrix
  node tools/heybox_visual_check.mjs
- PLAYWRIGHT_MODULE=/tmp/lwb-playwright-runtime/node_modules/playwright/index.mjs
  BROWSER_BASE_URL=http://127.0.0.1:43008 BROWSER_OUTPUT_DIR=/tmp/little-modularize.Ju7CGp/browser-research
  node tools/assistant_browser_check.mjs
artifacts:
- docs/knowledge/evidence/assets/module-refactor-2026-09-07/browser-matrix/report.json
- docs/knowledge/evidence/assets/module-refactor-2026-09-07/browser-research/report.json
- docs/knowledge/evidence/assets/module-refactor-2026-09-07/browser-matrix/narrow-light-post.png
- docs/knowledge/evidence/assets/module-refactor-2026-09-07/browser-matrix/desktop-dark-comments.png
- docs/knowledge/evidence/assets/module-refactor-2026-09-07/browser-research/desktop-light-answer.png
observed_commit: 9e8c4b7bfb9515cf01d7a02cc0d535fd9c3732a7
updated_at: '2026-09-07'
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

# 客户端职责拆分与浏览器回归验证

本页观察提交 9e8c4b7bfb9515cf01d7a02cc0d535fd9c3732a7。该提交保留 main 上已经完成的依赖升级，
只按职责移动 Mock、Assistant notifier 与页面构建代码，保留原导入出口、单一 provider 身份、共享状态、
Widget 树与事件处理语义。设计见 [DES-assistant-client](../design/DES-assistant-client.md)。
原文跳转浏览器检查补充等待正文加载完成，避免把页面壳的加载态截图当成正文渲染证据。

## 实际结果

| 检查 | 结果 |
| --- | --- |
| 格式与分析 | 197 个 Dart 文件无待格式化变更；analyze 无问题 |
| 单元与 Widget | 497 项全部通过；覆盖率 81.7%，高于既有 70% 门槛 |
| 维护工具 | 51 项全部通过 |
| SDK | 从核验的后端 gateway.api 临时重生成，两份 SDK 无漂移 |
| Mock Web | release 构建成功，CanvasKit 本地托管 |
| 页面矩阵 | Chromium 151.0.7922.34；5 组、120 图；0 pageerror、0 failed request，均非空、无水平溢出 |
| Assistant 交互 | 桌面亮色、移动亮色/暗色三组；问答已提交、2 张来源卡、引用/原文导航与历史返回通过 |

矩阵覆盖 390x844、1440x1000 的亮暗主题与 320x740 亮色窄屏，包含减少动画、长标题、评论分页、
实际详情入栈/返回。全部页面的结构化结果保存在 browser-matrix/report.json；仓库归档其中五组
帖子正文/评论和窄屏编辑器截图。browser-research 归档三组问答、回答、引用及原文共 12 张截图与报告。
目视复核窄屏正文、桌面暗色评论和桌面/移动 Assistant 回答，未见新遮挡或布局回归。

## 证明边界

五个覆盖组保留此前领域输入并保守纳入共享应用、测试、工具和依赖；仅刷新已有 aligned 的引用，
unknown/diverged 保持原样。浏览器使用隔离 Mock，不证明真实网关、模型检索质量、真实 SSE 故障、
原生/实体设备或生产 SLO。没有改上层产品语义、API、SDK、组件库、主题或正常 provider 配置。
