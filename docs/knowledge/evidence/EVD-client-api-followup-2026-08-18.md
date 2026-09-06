---
id: EVD-client-api-followup-2026-08-18
layer: evidence
title: 前端跟进后端契约与断点版式 2026-08-18
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-001
  - FX-002
  - FX-010
  - FX-020
  - FX-021
  - FX-022
  - FX-030
  - FX-031
  - FX-032
  - FX-040
  - FX-041
  - FX-050
  - FX-051
  - FX-060
  - FX-061
  - FX-062
  - FX-070
  - FQ-001
  - FQ-002
  - FQ-003
  - FQ-004
  - FQ-005
  - FQ-006
  - FQ-007
  - FQ-008
scope:
  - static
  - unit
commands:
  - flutter test
  - make knowledge-check
observed_commit: c4b0b75797859be77bd1e92b8b7772369a3ffa3d
updated_at: 2026-08-18
---

# 前端跟进后端契约与断点版式 2026-08-18

## 范围与环境

本证据核验 goctl 提取的当前网关 Dart SDK、v2 写路径、搜索降级、行为所有权、个性化开关、
图片私信和手机/桌面断点版式。后端观察提交
`380a734f90f374fb884ac68edc4edd037e959670`。

工具环境：工作树内 `flutter pub get`、`dart analyze`、`flutter test`、`make knowledge-check`。

## 命令与结果

在 `.worktree/task-api-followup-responsive`：

```bash
python3 tools/sync_gateway_sdk.py --api ../little-white-box-content-community/app/gateway/gateway.api
dart analyze   # 无 error；仅生成物/既有 info
flutter test   # 124 tests passed
make knowledge-check
```

`goctl api dart --legacy` 因模板缺少 `pathToFuncName` 失败；实际使用默认生成器，再由同步脚本
把 PUT/DELETE 从 POST 改回正确动词。

## 条款证据

| 条款 | 直接证据 | 结论 |
| --- | --- | --- |
| `FX-022` | `search_models.dart`、搜索页降级横幅、Mock `degraded` | 部分降级可展示 |
| `FX-030` | `createPostV2`/`updatePostV2`/`deletePostV2`、幂等键、409 提示 | 写路径对齐 |
| `FX-032` | 编辑器 120/20000/10 与 10 MiB 校验 | 边界对齐 |
| `FX-040` | 文本 1000、图片 multipart + `mediaId`；视频/语音按钮禁用 | 图片闭环；音视频发送阻塞 |
| `FX-051` | 来源 `revision`，只打开 `post` | 来源边界收紧 |
| `FX-060` | `PostCard` 不再 trackLike；Mock 拒绝权威动作 | 所有权对齐 |
| `FQ-002` | `tools/sync_gateway_sdk.py`、`vendor/sdk_source` 与 `lib/sdk` | 生成同步可重复 |
| `FQ-005` | 桌面双列 Feed、私信分栏、移动端资料页 Assistant | 断点版式已改 |

## 未证明范围

- 未跑真实网关（CORS、鉴权、SSE 代理、生产推荐）。
- 视频/语音发送不能在当前 HTTP 契约上证明。
- 浏览器端到端未在本证据中记录。

## 历史提交映射

frontmatter 原记录 `f97bb47eb43ef9a3eba0e1c2b72407deef668880`；主线重放后的等价提交为 `c4b0b75797859be77bd1e92b8b7772369a3ffa3d`。
迁移时以 `git range-diff` 核对，差异仅为提交内自引用 SHA/知识说明。
