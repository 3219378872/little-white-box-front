---
id: EVD-media-uploads-2026-09-27
layer: evidence
title: 视频与音频私信上传交付验证
status: active
result: passed
owner: agent
scope:
- static
- unit
- browser
commands:
- make format-check analyze tools-test KNOWLEDGE_PYTHON=/home/dev/projects/little/little-white-box-front/.venv-knowledge/bin/python
- flutter test --no-pub --coverage --reporter expanded
- python3 tools/lcov_summary.py coverage/lcov.info --min 70
- PATH=/tmp/little-quality-tools-nsA9h9/bin:$PATH make sdk-check BACKEND_API=/home/dev/projects/little/little-white-box-content-community/app/gateway/gateway.api
- flutter build web --no-pub --release -t lib/main.dart
- flutter build apk --no-pub --debug --target-platform android-x64
- cd /home/dev/projects/little && /tmp/little-media-tools/bin/python deploy/dev/e2e/media_browser.py
  --output /tmp/little-media-browser-contrast
artifacts:
- docs/knowledge/evidence/assets/media-uploads-2026-09-27/media-1440-light.png
- docs/knowledge/evidence/assets/media-uploads-2026-09-27/media-320-light.png
- docs/knowledge/evidence/assets/media-uploads-2026-09-27/media-390-dark.png
- docs/knowledge/evidence/assets/media-uploads-2026-09-27/receiver-history.png
- docs/knowledge/evidence/assets/media-uploads-2026-09-27/report.json
- docs/knowledge/evidence/assets/media-uploads-2026-09-27/validation-summary.json
observed_commit: 71ac5148862414511ef6118882737dc369f5b8ae
updated_at: 2026-10-06
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
  - android
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
  - android
- requirements:
  - FX-040
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
  - android
- requirements:
  - FX-050
  - FX-051
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
  - android
- requirements:
  - FQ-004
  paths:
  - lib/core/theme
  - lib/core/widgets
  - lib/core/router/app_router.dart
  - test/helpers/forui_test_builder.dart
  - tools/heybox_visual_check.mjs
  - tools/heybox_android_check.py
  - tools/redesign_compare_capture.mjs
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

# 视频与音频私信上传交付验证

> 2026-10-06：Watch 退役，`FX-082`、`FX-083`、`FX-086` 已从规格删除，本页覆盖组随之移除这些条款；原观察结果不变。

观察前端提交 `71ac514`，对照后端 `8c7a639` 的公开 Gateway 契约。实现映射见
[IMP-messaging-client](../implementation/IMP-messaging-client.md)，其余覆盖条款回链各自 IMP。
测试与构建在前端 task 工作树执行；同提交 Web release 产物部署到根联调栈后，在真实 `:3002` 网关验证。

| 检查 | 结果 |
| --- | --- |
| 格式与静态分析 | 218 个文件格式不变；分析零问题 |
| 单元与 Widget 测试 | 626 passed，8746/10420 行（83.9%）覆盖率 |
| 维护工具 | 52 passed |
| Gateway SDK | vendor/sdk_source 与 lib/sdk 均与生成源一致 |
| 构建 | Web release、Android x64 debug 通过 |
| 真实浏览器 | 320 亮色、390 暗色、1440 亮色三个发送场景；接收方历史通过 |

FX-040 已补齐视频、音频上传与发送。每个浏览器场景选择并上传图片、视频、音频，验证消息发送、刷新后
历史恢复、视频和音频链接打开及公开资源读取；接收方可见相同媒体历史。无页面/控制台资源错误及横向溢出。
截图、结构化报告和验证摘要保存在本页 assets。末次样式修复使用 secondary 按钮，亮暗色截图已人工查看。

回归测试覆盖稳定上传幂等键、上传成功后发送失败的复用、鉴权刷新重新打开文件流、全链路截止时间中止、
离开页面/切换会话/取消后的迟到结果隔离，以及发送中的互斥操作与精确 int64 ID。后端负责校验媒体归属、
类型和完成状态，消息 URL 使用权威媒体元数据；两端公开 SDK 同步生成。

覆盖组保留原完整输入并补充 Android 构建输入；共享依赖改变后，以本轮全量单元与静态检查刷新已有 aligned
行的代码证据。旧重构的七场景前后对比保留为历史，本页浏览器范围仅为私信，不声称重跑那些对比。

音频入口是选择已有文件，不提供录音；视频/音频经系统 URL 打开，不提供内嵌播放器或转码保证。
Android 仅构建通过：adb 无可用设备，KVM 无权限；未运行 Android/iOS 设备、真人辅助技术、生产或容量验证。
既有 unknown/diverged 的其他条款及其 gap 保留。原始日志保留于任务临时目录，持久摘要见 artifacts。
