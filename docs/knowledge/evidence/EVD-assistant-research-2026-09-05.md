---
id: EVD-assistant-research-2026-09-05
layer: evidence
title: Assistant 问答与原文卡片工程验收
status: partial
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-051
  - FX-056
  - FX-059
  - FX-070
  - FX-084
  - FX-089
  - FX-090
  - FX-094
  - FX-095
  - FX-096
  - FX-097
  - FX-098
  - FX-099
  - FQ-002
  - FQ-004
  - FQ-005
  - FQ-006
  - FQ-007
  - FQ-008
updated_at: 2026-09-05
observed_commit: 9103df3
---

# Assistant 问答与原文卡片工程验收

## 环境与实际结果

- `make analyze`：通过，无分析问题。
- `make test`：407 项 Flutter 测试通过。
- `python3 -m unittest discover -s tools -p 'test_*.py'`：5 项通过；包含精确 ID、可选类型、媒体元数据
  构造兼容和生成头稳定性。
- `flutter build web --release -t lib/main_mock.dart --no-web-resources-cdn --dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/`：通过。
- `PLAYWRIGHT_MODULE=/home/dev/.local/lib/node_modules/playwright/index.mjs node tools/assistant_browser_check.mjs`：
  桌面亮色 1440×1000、移动亮色及暗色 390×844 均通过；每种视口完成真实控件输入、选择/提交、两张
  来源卡、引用定位、原文打开及应用内返回，pageerror 为零。
- 截图与机器结果在 `/tmp/xbh-research-browser/`；检查了正文与卡片边界、长标题、摘录折叠、亮暗配色，
  未发现溢出或重叠。浏览器导航使用现有 hash 路由和应用内 push/pop，不用 URL 是否改变替代导航证据。

## 条款覆盖

- 问答：不预选偏好，未知/跳过不造答案，失败保留选择及文本，重试复用命令标识，迟到响应不重开终态。
- 恢复：待答 EOF 不伪造生成失败，等待连接可恢复；历史与 SSE 按问题和消息身份合并，避免重复卡片。
- 来源：信息与服务端来源关联，卡片展开/原文打开可操作，失效来源不显示旧摘录，自由 Markdown 图片
  不加载，缩略图限定同源媒体；摘要保持实际取得内容，不是二次模型概括。
- 展示：检索型回答完整发布，普通对话保留流式揭示；完成后不残留“正在思考”，已答问题折叠为只读摘要。

## 未验证边界

浏览器运行的是 Mock transport，不能证明服务端权限、真实检索质量、生产代理或跨设备持久性。
真实栈与真实模型证据另行记录，开放式回答支持关系仍需人类冻结集。

已尝试 `flutter build linux --release -t lib/main_mock.dart`，因环境缺少 CMake 停止；原生外链与
物理移动设备尚未验收，不能以 Web 结果替代。整体实现仍为 diverged，证据状态保留 partial。
