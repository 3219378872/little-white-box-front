---
id: EVD-exposure-event-driven-2026-08-25
layer: evidence
title: 曝光追踪事件化与 int64 编码白名单 2026-08-25
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-060
  - FQ-006
updated_at: 2026-08-25
observed_commit: 81834e5
---

# 曝光追踪事件化与 int64 编码白名单 2026-08-25

## 范围与环境

两项打磨：

1. `PostCard` 曝光追踪原为每卡一个 `Timer.periodic(100ms)` 的几何轮询（findRenderObject +
   localToGlobal），一屏几十卡即主线程每秒数百次布局读取。改用 `visibility_detector`
   （新依赖，经批准）事件回调：可见比例 ≥50% 持续 1s 上报曝光，离开可见区记录 dwell，
   去重键 `(requestId, postId)` 不变；Detector Key 绑定 post+requestId，
   复用场景下 key 变化触发全新回调。
2. `unquoteLargeJsonIntStrings` 原对一切 ≥16 位纯数字"值"去引号——帖子正文/评论里的长
   数字串（订单号等）会被改成 JSON number 发往网关 string 字段导致反序列化失败。改为仅当
   所属键名以 `Id`/`Ids` 结尾（数组元素继承所属键）才还原为 number；对象边界重置键上下文。

## 命令与结果

在前端 `task-front-polish` 工作树：

```text
make analyze        # No issues found!
make test           # +279: All tests passed!
make test-coverage  # total: 4802/6487 lines (74.0%) >= COVERAGE_MIN=70, exit 0
```

新增测试：自由文本长数字串保持引号、`postIds` 数组元素去引号而 `titles` 数组保留、嵌套对象
重置键上下文；既有曝光时序测试（50%/1s/dwell）在 Detector 下全部通过。测试全局通过
`test/flutter_test_config.dart` 把 Detector 回调节流归零，消除 pending Timer。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| FX-060 | 曝光/停留上报语义不变（阈值、时长、去重键一致），仅采集机制由轮询改为事件驱动。 |
| FQ-006 | 编码层不再有损改写自由文本；ID 字段保全语义收窄到命名约定内的键，降低误伤面。 |
