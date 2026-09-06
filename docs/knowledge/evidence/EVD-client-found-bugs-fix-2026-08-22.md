---
id: EVD-client-found-bugs-fix-2026-08-22
layer: evidence
title: 测试暴露缺陷修复 2026-08-22
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-001
  - FX-002
  - FX-010
  - FX-031
scope:
  - static
  - unit
commands:
  - make test
  - make analyze
  - make knowledge-check
observed_commit: b8ffc8aee4e707e133a0ad2ca990abf1d6e39710
updated_at: 2026-08-22
---

# 测试暴露缺陷修复 2026-08-22

## 范围与环境

覆盖率补齐任务的 Widget 测试暴露两个真实缺陷，本证据记录其修复与回归验证：

1. 编辑资料页在身份恢复完成前进入时同步读到 null userId 直接返回，页面永久停留在进度圈；
   资料读取失败也只弹 toast，同样卡死（违反 `FX-002` 受保护入口语义与 `FX-010` 身份恢复时序）。
2. 帖子详情页评论读取失败被静默吞掉，空列表渲染成「还没有评论」，把失败伪装成空结果
   （直接违反 `FX-001`）。

## 命令与结果

在前端 `task/fix-found-bugs` 工作树：

```text
flutter analyze lib/features/profile/presentation/edit_profile_page.dart lib/features/post/presentation/post_detail_page.dart
make test
make analyze
make knowledge-check
```

- 定向 analyze 无 issue；`make analyze` 维持存量基线 20 条（全部为 SDK 存量风格提示，无新增）。
- `make test` 退出码 0：247 个测试通过，其中新增 3 个回归用例：
  - 编辑页冷启动深链（初始路由即编辑页、不预热 auth）等待身份恢复后自动加载并预填；
  - 编辑页资料读取失败呈现 ErrorView，重试成功后预填表单；
  - 详情页评论加载失败显示「评论加载失败」可重试错误态且不再出现「还没有评论」，重试成功后评论上屏。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-001` | 评论首屏与分页失败均置 `_commentsError`：空列表场景渲染 `ErrorView('评论加载失败')`，已有条目场景在列表尾部提供「评论加载失败，重试」；两者都不再渲染「还没有评论」 |
| `FX-002` | 编辑资料页 build 改为 watch `authNotifierProvider`，未就绪时保持加载态，不误判匿名、不跳转也不卡死 |
| `FX-010` | `_loadProfile` 读到未就绪身份时复位触发标记，由 build 的 watch 在恢复完成后自动重排再加载；深链冷启动回归用例证明可自愈 |
| `FX-031` | 评论失败重试会复位分页游标（page=1）后整体重拉；排序切换同时清理错误态 |

## 未证明范围

未在真实网关浏览器中人工复演冷启动深链与断网场景；评论尾部部分分页失败的滚动重试仅有代码路径，
无独立 Widget 用例。
