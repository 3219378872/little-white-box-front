---
id: EVD-heybox-presentation-2026-09-06
layer: evidence
title: Heybox Android 视觉迁移验收
status: verified
owner: agent
upstream:
  - IMP-heybox-presentation
covers:
  - FQ-004
  - FQ-005
  - FQ-009
  - FX-030
  - FX-031
  - FX-032
  - FX-050
updated_at: 2026-09-06
---

# Heybox Android 视觉迁移验收

任务基线为前端 `998dd23`，参考 APK 1.3.394。环境 Flutter 3.44.7 / Dart 3.12.2 / Forui 0.24.2。
本次没有升级依赖、修改后端或生成 SDK。实施与证据互链于
[IMP-heybox-presentation](../implementation/IMP-heybox-presentation.md)。

## 参考与隔离

参考原版审计在 `/tmp/heybox-android-baseline-20260906.YwszWV`：30 张截图、26 份有效控件树，
含 6 张深色；未操作原版社区写入，私信界面未采样。参考账号内容与登录凭据不进入源码或报告附件。

迁移验收目录 `/tmp/xbh-heybox-migration-20260906.4EhL6I`。最终 Mock Web 全页面实拍完成 120 张，
覆盖 390x844、1440x1000 的亮暗以及 320x740 亮色。最终原生实拍共 28 张，运行本项目 APK，
不是把参考小黑盒截图当作实现证据。截图只证明 UI 和 Mock 路径，不证明真实接口或模型服务正确性。

## 最终结果

| 检查 | 结果与产物 |
| --- | --- |
| 静态分析 | `flutter analyze --no-pub`：No issues found，`analyze-final.log` |
| 自动测试 | `flutter test --no-pub --reporter expanded`：492 passed，`tests-navigation-final.log` |
| 知识链 | `make knowledge-check`：46 文档、54 条款、97 本地链接通过 |
| 变更格式 | 34 个新增/修改 Dart 文件 format dry-run 通过，`git diff --check` 通过 |
| Web release | 构建成功，`web-build-navigation-final.log`；包含最后的路由修复 |
| 跨视口浏览器 | Chromium 151.0.7922.34，120 图，0 pageerror、0 failed request，全部非空，无水平溢出；`web-navigation-final/report.json` |
| Agent 交互 | 桌面亮色、移动亮暗三组：问答提交、2 张来源卡、引用跳转、原文返回与历史去重通过；`assistant-browser-final/report.json` |
| Android release | Android x64 Mock APK 构建与安装成功；`android-build-navigation-final.log` |
| Android 实拍 | API 36 模拟器，1080x2400 / 420dpi；亮暗各 14 图，共 28 图；`android-navigation-final/report.json` |

浏览器覆盖 Feed、详情/评论/输入、搜索及结果、消息/私信输入、Agent/更多菜单、记忆与追踪及
编辑弹窗、编辑器及 120 字标题草稿、资料及编辑、密码/验证码登录和注册。新增实际从首页点击
详情再返回的路径。非空像素标准差最小值：Web 2021.54，Android 4148.15（ImageMagick Q16）。
人工检查了移动/桌面信息流、详情、窄屏评论输入/长标题、原生深色个人页/菜单/编辑键盘等实拍。

两项原生观察推动的修复：主内容加系统安全区，避免首页覆盖状态栏；路由壳使用 `state.uri.path`
而非会保留入栈前路径的 `matchedLocation`，保证详情/资料编辑等二级页隐藏主导航、返回后恢复。
两者均新增 Widget 回归，浏览器和 Android 脚本增加实际入栈与底栏断言。
全仓 format dry-run 另提示 30 个本轮未修改文件的既有格式差异，没有把无关重排并入本次迁移。

## 可复现命令

```bash
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
make knowledge-check
flutter build web --release --no-pub -t lib/main_mock.dart \
  --no-web-resources-cdn --dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/
PLAYWRIGHT_MODULE=/path/to/playwright/index.mjs \
  BROWSER_BASE_URL=http://127.0.0.1:43007 \
  BROWSER_OUTPUT_DIR=/tmp/xbh-heybox-browser node tools/heybox_visual_check.mjs
flutter build apk --release --no-pub --target-platform android-x64 -t lib/main_mock.dart
python tools/heybox_android_check.py --serial emulator-5566 \
  --output /tmp/xbh-heybox-android
PLAYWRIGHT_MODULE=/path/to/playwright/index.mjs \
  BROWSER_BASE_URL=http://127.0.0.1:43007 \
  BROWSER_OUTPUT_DIR=/tmp/xbh-assistant-browser node tools/assistant_browser_check.mjs
```

Android 脚本需要已安装 APK、`uiautomator2` 与 ImageMagick；Web 脚本需要 Playwright Chromium
与 ImageMagick。`preview-web/` 是独立于任务工作树的 Mock 静态产物，供本机 `:43007` 预览。

## 验证边界

本页 `verified` 只指上述本地视觉与既有 Mock 交互验证，不代表逐像素一致率、实体 Android 设备、
iOS 或真实模型服务验收。原版未采样的私信、Agent、记忆和追踪使用同一套视觉规则适配。
真实联调入口在任务开始时为 502；恢复与真实 API 检查属于整合后的独立运行时记录，不能从本页的
Mock 结果推导其通过。没有修改后端、SDK、数据层或原有输入限制。
