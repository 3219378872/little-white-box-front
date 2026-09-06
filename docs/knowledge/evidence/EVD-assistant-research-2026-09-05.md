---
id: EVD-assistant-research-2026-09-05
layer: evidence
title: Assistant 问答与原文卡片工程验收
status: active
result: partial
owner: agent
upstream:
  - IMP-client-platform
  - IMP-assistant-client
  - IMP-presentation-client
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
scope:
  - static
  - unit
  - integration
  - e2e
  - browser
  - live-provider
commands:
  - make analyze
  - make test
observed_commit: 7ab3de27c0ec7ff0c86bb16de2ec752d66f5c280
updated_at: 2026-09-05
---

# Assistant 问答与原文卡片工程验收

## 环境与实际结果

- `make analyze`：通过，无分析问题。
- `make test`：整合生命周期修复后 477 项 Flutter 测试通过。
- `python3 -m unittest discover -s tools -p 'test_*.py'`：8 项通过；包含精确 ID、可选类型、媒体元数据
  构造兼容、生成头稳定性和后端路径发现。
- `flutter build web --release -t lib/main_mock.dart --no-web-resources-cdn --dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/`：通过。
- `PLAYWRIGHT_MODULE=/home/dev/.local/lib/node_modules/playwright/index.mjs node tools/assistant_browser_check.mjs`：
  桌面亮色 1440×1000、移动亮色及暗色 390×844 均通过；每种视口完成真实控件输入、选择/提交、两张
  来源卡、引用定位、原文打开及应用内返回，pageerror 为零。
- 浏览器脚本已适配整合后的就绪边界：先等历史加载完成、发送按钮可用，再等 Flutter 语义输入框
  完成编辑焦点交接后输入；点击使用自动等待可操作状态的方式。之前移动端直接坐标点击可能发生在
  初始化期间，不能将该超时记为通过；修正等待后重新执行上述三个完整场景。
- 截图与机器结果在 `/tmp/xbh-research-browser/`；检查了正文与卡片边界、长标题、摘录折叠、亮暗配色，
  未发现溢出或重叠。浏览器导航使用现有 hash 路由和应用内 push/pop，不用 URL 是否改变替代导航证据。

## 跨端联调边界

观察后端 `66f4406`（代码 `0171e64`），前端 `7ab3de2`（代码 `0a31c95`）。正常 release 同源栈
在 `http://127.0.0.1:3002` 启动成功。人类指定的新 LLM 端点 `https://api.weblearning.fun/v1`
保留原模型 `glm-5.3-flash`、`responses` 和凭据；启动 canary 与真实消息/SSE 重连测试通过。
编排仓全量黑盒为 116 passed、5 skipped，另有严格 fixture 研究测试 4 passed、reset 测试
1 passed。fixture 已退出，运行进程已核对为正常 provider。

真实 protocol v2 长检索请求在 4 次搜索与 14 次读原文后，第 5 轮模型请求三次超时，以
`LLM_UNAVAILABLE` 终止，没有发布不完整答案。不能用基础调用、fixture 或 Mock 界面结果证明
真实模型的完整研究闭环已通过。

## 条款覆盖

- 问答：不预选偏好，未知/跳过不造答案，失败保留选择及文本，重试复用命令标识，迟到响应不重开终态。
- 恢复：待答 EOF 不伪造生成失败，等待连接可恢复；历史与 SSE 按问题和消息身份合并，避免重复卡片。
- 来源：信息与服务端来源关联，卡片展开/原文打开可操作，失效来源不显示旧摘录，自由 Markdown 图片
  不加载，缩略图限定同源媒体；摘要保持实际取得内容，不是二次模型概括。
- 展示：检索型回答完整发布，普通对话保留流式揭示；完成后不残留“正在思考”，已答问题折叠为只读摘要。

## 未验证边界

浏览器运行的是 Mock transport，不能证明服务端权限、真实检索质量、生产代理或跨设备持久性。
真实栈结果与真实模型失败已分别记录；没有真实模型浏览器全链路通过证据，开放式回答支持关系仍需
人类冻结集。

已尝试 `flutter build linux --release -t lib/main_mock.dart`，因环境缺少 CMake 停止；原生外链与
物理移动设备尚未验收，不能以 Web 结果替代。当前条款结论按领域 IMP 分别登记；本页保持
`active/partial`，不再用整体状态覆盖局部差异。
