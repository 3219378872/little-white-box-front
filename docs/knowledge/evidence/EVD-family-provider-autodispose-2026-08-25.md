---
id: EVD-family-provider-autodispose-2026-08-25
layer: evidence
title: family provider 随监听生命周期释放 2026-08-25
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FQ-006
  - FX-031
scope:
  - static
  - unit
commands:
  - make analyze
  - make test
  - make test-coverage
observed_commit: 5d298c14ce0abfb713358b8e7cb283d1c7732954
updated_at: 2026-08-25
---

# family provider 随监听生命周期释放 2026-08-25

## 范围与环境

此前全库零 `autoDispose`：7 个 family provider（帖子详情、评论、互动、用户帖子列表、私信会话、
推荐/关注流、他人资料）按 id 永久驻留，Web 长会话下每访问一个帖子/用户/会话固化一份状态，
且他人资料页重进不重新拉取。改为 `autoDispose.family` 后状态随最后一个监听者移除而释放，
重进即重建并刷新；异步在途请求由 StateNotifier `mounted` 守卫拦截 dispose 后写状态
（feed/user_posts/message_thread 的 generation 判据合并 `!mounted`，interaction 回滚路径补守卫）。

## 命令与结果

在前端 `task-family-provider-autodispose` 工作树：

```text
make analyze        # No issues found!
make test           # +276: All tests passed!
make test-coverage  # total: 4808/6497 lines (74.0%) >= COVERAGE_MIN=70, exit 0
```

既有 276 个测试全部通过，未发现依赖"跨页常驻缓存"的用例，说明转换无行为回归。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| FQ-006 | 异步状态生命周期收紧：dispose 后在途响应不再写状态（`mounted` 守卫），
generation 抑制语义保持不变；失败重试路径无权威写入重复风险。 |
| FX-031 | 用户资料相关 provider（资料、帖子列表）随页面离开释放，重进触发新鲜拉取，
不再展示陈旧缓存。 |
