---
id: EVD-audit-remediation-client-2026-08-31
layer: evidence
title: 客户端会话隔离与 Assistant 写入并发整改 2026-08-31
status: active
result: partial
owner: agent
upstream:
  - IMP-client-platform
  - IMP-community-client
  - IMP-messaging-client
  - IMP-assistant-client
covers:
  - FX-002
  - FX-010
  - FX-020
  - FX-040
  - FX-041
  - FX-050
  - FX-081
  - FX-082
  - FX-085
  - FQ-002
  - FQ-003
  - FQ-006
  - FQ-007
  - FQ-008
scope:
  - static
  - unit
  - integration
  - e2e
  - browser
commands:
  - make analyze
  - make test
  - make test-coverage
  - flutter test test/features/assistant/data/assistant_repository_test.dart
observed_commit: 97dc5909f797b8a498b3011cdb0bc482c85afa52
updated_at: 2026-08-31
---

# 客户端会话隔离与 Assistant 写入并发整改 2026-08-31

## 范围

在 `task/audit-remediation` 工作树修复跨账号会话竞态与缓存污染：持久令牌加入 session revision，
refresh/401/multipart/SSE 全部按请求快照条件替换或删除；认证状态变更串行发布，公开与受保护 provider
按 session identity 重建。Feed、Comment、Interaction、Post detail、Profile、User posts、Message 与
Assistant 新增账号 A 请求迟到于账号 B 的回归覆盖。

同步同级后端实现提交
`f21b68795233b34ee07ffa5c574bb8f06add9ac6` 的 `gateway.api`，生成 Watch `expectedVersion`、更新响应
task/version 与 Assistant run `streamId` 契约。Memory 写入按完整命令指纹复用 requestId，并修复
changeId 在刷新与 undo 失败后的可恢复性；Watch 更新/删除采用 version CAS，冲突后刷新权威列表。
真实浏览器随后暴露 Memory provider 在对话框和错误提示造成的短暂无监听窗口中被 auto-dispose，导致
失败命令 requestId 丢失；提交 `97dc5909f797b8a498b3011cdb0bc482c85afa52` 将它改为当前认证 session
内常驻，并继续以 session identity 隔离换号和登出。

## 验证

在前端 `task/audit-remediation` 工作树实际执行：

实现提交 `fd31aa39ce428e2dbc5bc4af395897c5cf6b04f8` 已 rebase 到前端 `main`
`63966e26b9a97980abe4a63c7f55dd77423432b3`，冲突解决保留主线的 grapheme 分块、`streamId` 与
reset 状态机，并叠加本次 session fencing、Watch CAS 与 Memory 幂等改动。rebase 后重新执行：

```text
make analyze
# No issues found

make test
# 398 tests passed

make test-coverage
# 398 Flutter tests + 4 Python tests passed
# total line coverage: 6356/7995 lines (79.5%), threshold 70%

flutter test test/features/assistant/data/assistant_repository_test.dart
# 12 tests passed（含补充的自定义 SSE token 与持久会话隔离）

flutter test test/features/assistant/application/memory_notifier_test.dart
# 6 tests passed（含暂时无人监听仍复用 requestId、换号后更换 requestId）

python3 tools/test_sync_gateway_sdk.py
# 3 tests passed

make knowledge-check
# OK (38 formal documents, 48 requirements, 80 local links)
```

`vendor/sdk_source/data/gateway.dart` 与 `lib/sdk/data/gateway.dart` 经逐字比较一致，`git diff --check`
通过。聚焦测试还覆盖 refresh single-flight、旧 refresh/401 对新账号无效、跨账号迟到读取、Message
load/read/send generation、Memory requestId/undo 与 Watch `409/2007` 收敛。

## 真实同源 release 浏览器

在根编排提交 `0abd3f25cf4edcfa5da3ff0ca8999bea0f81694c`、后端
`4a5e6deb2b6757844043f2882f20e79dfb34bc9b` 与前端 observed commit 上，先 `just app-down`，再以
`FORCE_FRONT_BUILD=1 just app-up` 重建同源码应用和 Flutter Web release 包；`just status` 显示 20 个
应用进程存活，中间件健康，`:3002` 页面 200、API 404，`:8888` 404，`:3003` 与 `:9136` 均为 200。

Playwright 1.62.1 与本机 Chromium 实际观察：

- 桌面 `1440x900` 在同一浏览器 session 从 `admin` 退出并登录
  `e2ebrowsermth9jya1`，个人页显示新账号且不保留旧身份；移动 `390x844` 匿名首屏正常。两个视口
  横向溢出均为 0，HTTP 4xx/5xx、requestfailed、page error 与 console error 均为 0。
- 移动 Memory 首次 POST 被浏览器确定性注入 `503`，第二次同内容 POST 返回 `200`，两次 requestId
  相同；成功后 UI 显示条目与「撤销」，权威 GET 可见条目；undo 返回 `200` 后 UI 与权威 GET 均不再
  含该条目。预期注入对应一条 console 记录，除此之外上述错误计数均为 0。
- 移动 Watch 创建任务为 v1，外部并发更新到 v2 后，页面陈旧更新明确返回 `409/2007` 并刷新为权威
  停用态；随后页面以新版本启用为 v3、删除返回 `200`，权威 GET 不再包含任务。
- Memory 与 Watch 的本轮浏览器探针均清理到 0；平台没有测试用户删除接口，浏览器测试账号保留。
- CanvasKit 共观察到 4 个请求，全部为同源 `/canvaskit/`；HTML 与 `main.dart.js` 响应为
  `Cache-Control: no-cache`，CanvasKit WASM 为 `max-age=3600`。三者 CSP 均含
  `worker-src 'self' blob:`、`frame-ancestors 'none'` 与 `object-src 'none'`。

根仓 Watch helper 同步 `expectedVersion` 后，真实栈聚焦 CRUD/冲突用例 `1 passed`，最终全量黑盒
`116 passed, 1 skipped in 247.89s`。该黑盒结果证明当前同源 API 栈，不代替下述生产边界。

## 未证明范围

- 本页覆盖的真实浏览器路径仍不包含 Assistant SSE 断流/重连和 `response_reset` 消费；根仓 pytest
  SSE 客户端不能代替 Flutter 浏览器或真机消费端。
- 未覆盖真机图片选择上传、外部 live provider、production profile、真实生产迁移或生产流量。
- 因上述范围及客户端私信视频/语音契约缺口，本页保持 `partial`，不扩大为整体发布就绪结论。
