---
id: EVD-code-quality-hardening-2026-09-05
layer: evidence
title: 客户端异步生命周期与状态边界加固 2026-09-05
status: active
result: partial
owner: agent
upstream:
  - IMP-client-platform
  - IMP-community-client
  - IMP-assistant-client
covers:
  - FX-002
  - FX-030
  - FX-032
  - FX-050
  - FX-053
  - FX-055
  - FX-058
  - FX-059
  - FX-081
  - FX-082
  - FX-089
  - FX-090
  - FX-091
  - FX-092
  - FX-093
  - FQ-002
  - FQ-003
  - FQ-006
  - FQ-007
  - FQ-008
scope:
  - static
  - unit
commands:
  - make analyze
  - make test
  - make test-coverage
  - make knowledge-check
observed_commit: 74c96f6e487df0e8c08a1154c4c2e9b3ebbcbb1d
updated_at: 2026-09-05
---

# 客户端异步生命周期与状态边界加固 2026-09-05

## 范围与环境

本证据观察前端提交 `74c96f6e487df0e8c08a1154c4c2e9b3ebbcbb1d`，并以同级后端
`e76a447c6ad2213a25a8581b69f2274e79125d69` 的 `app/gateway/gateway.api` 重新生成 SDK。
范围包括 Assistant run/history/SSE 状态收敛、Consent single-flight、Memory/Watch 读取竞态与
错误态、认证和对话框生命周期、帖子提交快照、图片选择、关注 single-flight、时间格式化及 Web int64
生成类型。公开 API、数据库 schema 和路由契约均未修改。

## 命令与结果

在前端 `task/code-quality-front` 工作树实际执行：

```text
dart format --output=none --set-exit-if-changed <本次变更的 41 个 Dart 文件>
# Formatted 41 files (0 changed)

make analyze
# No issues found

flutter test test/features/assistant/application/assistant_notifier_test.dart \
  test/features/assistant/presentation/assistant_page_test.dart \
  test/features/assistant/presentation/watch_page_test.dart
# 71 tests passed

make test
# 468 tests passed

make test-coverage
# 468 Flutter tests + 7 Python tests passed
# total: 6939/8436 lines (82.3%), threshold 70%

python3 tools/sync_gateway_sdk.py
python3 tools/sync_gateway_sdk.py --api \
  /home/dev/projects/little/little-white-box-content-community/app/gateway/gateway.api
# 主检出自动发现与显式路径均生成成功

cmp vendor/sdk_source/api/gateway.dart lib/sdk/api/gateway.dart
cmp vendor/sdk_source/data/gateway.dart lib/sdk/data/gateway.dart
git diff --check
# 均通过

make build-web
# Flutter Web release 构建成功
```

全仓 formatter 检查另发现 33 个未被本任务修改的历史 Dart 文件会被当前 SDK 重新格式化；为保持提交
边界，本轮只验证并格式化实际变更文件，没有夹带全仓格式噪声。

## 条款证据

- `FX-050/058/089～093`、`FQ-006`：notifier 测试覆盖首屏读取与发送互斥、清历史失败恢复、POST 与
  history/SSE 竞态、同 run 单气泡收敛、queued 在 compact/attachment 保留并在可证明消费后清除、
  `beforeId`/`afterId` 分页及 Watch 增量消息。两次 SSE 失败后 active run 与 cursor 保留，同 run
  thread 刷新或显式按钮从最后 `afterSeq` 续订。
- `FX-059/090`：旧 `streamId` 的迟到 token 在事件合法性 fence 前不能清除断流错误；回归测试同时
  断言 `connectionError`、`STREAM_DISCONNECTED` 与 `degraded` 保持，合法当前 stream 事件到达后才
  呈现恢复。未知事件不改变状态。
- `FX-053`：pending 的已授权 Consent 首次读取被发送流程复用，只产生一次 GET，不弹重复授权框；
  页面发送 fence 防止双击并发授权与重复 POST。
- `FX-081/082`：Memory/Watch 以 generation 丢弃迟到列表响应；不同 Memory 命令分别保留稳定 requestId；
  换号会关闭旧身份对话框。空列表失败显示 ErrorView，Watch 非空列表错误保留任务并提供内联重试。
- `FX-002/030/032/055`：登录、注册、附件、帖子详情和对话框回调在 route/session/dispose 后不再写入
  旧页面；帖子发布冻结点击时命令，选图返回后验证 mounted，发送完成不覆盖等待期间的新草稿。
- `FQ-002/003`：SDK 生成将实体 ID 与 ID 列表保留为 Web 精确的 `Object`，默认路径兼容主检出与嵌套
  worktree；生成来源和应用副本逐字一致，PUT/PATCH/DELETE 修补仍由同步脚本统一执行。
- `FQ-007/008`：新增 notifier、Widget、SDK 路径和格式器测试；命令结果及未覆盖边界记录于本页，并由
  `make knowledge-check` 验证实现—证据双向引用。

## 未证明范围

- 本页是本地静态分析、单元/Widget、生成一致性和 Mock Web 构建证据，不等同真实同源网关、浏览器
  SSE 断流/重连、真机图片选择、外部 live provider、production profile、迁移或生产流量验证。
- 当前帖子更新契约不能无歧义表达既有图片 URL 与 mediaId 的对应关系或“删除全部图片”；本轮未猜测
  positional mapping，也未改变公开 API。Watch 快速重复写会由服务端 version CAS 防止数据损坏，
  客户端尚未增加逐任务 busy fence。
- Consent GET 失败沿用既有未授权表现，尚未建模为独立的可恢复读取错误态。私信视频/语音上传契约缺口
  仍存在；当前结论分别登记在 Assistant 与私信 IMP，本证据保持 `active/partial`。
