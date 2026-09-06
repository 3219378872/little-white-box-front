---
id: EVD-assistant-agent-runtime-2026-08-27
layer: evidence
title: Assistant 记忆、Watch 与卡片表面 2026-08-27
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-059
  - FX-080
  - FX-081
  - FX-082
  - FX-083
  - FX-084
  - FX-085
  - FX-086
  - FX-087
scope:
  - static
  - unit
commands:
  - make analyze
  - make test
  - make knowledge-check
observed_commit: 79b90ef06346c6a52eb47bc25ac253583282eaba
updated_at: 2026-08-29
---

# Assistant 记忆、Watch 与卡片表面 2026-08-27

本证据已被 [EVD-assistant-hermes-2026-08-29](EVD-assistant-hermes-2026-08-29.md) 替代。原条款
中的 Profile/Interest/Task 分层记忆、Watch 命中收件箱以及 SSE `card`/`actions`/`watch_hit`
已从规格中删除；保留本页仅作历史观察，不再证明当前 FX-059、FX-080～087 语义。

## 范围与环境

在既有 `task/agent-runtime-client` 工作树完成 PR10：记忆页、Watch 页与命中收件箱、
SSE `card`/`actions`/`watch_hit` 表面、consent 版本升级只读提示、帖子详情盯梢芯片，
以及 Mock 记忆/Watch/反馈契约。未知 SSE 类型按跳过处理，不作为错误终止。

本轮不包含通知中心、自动评论或私信投递。

## 命令与结果

在前端 `task/agent-runtime-client` 工作树：

```text
make analyze          # No issues found!
make test             # All tests passed!
make knowledge-check  # knowledge check passed
```

关键自动化观察：

- repository 对未知 SSE `type` 继续消费后续 token/done，不抛终止错误。
- notifier 忽略 `unknown` 事件，同时应用 card/actions/watch_hit。
- 记忆页 empty / ErrorView / 列表；过期授权只读提示。
- Watch 页任务与命中、标已读。
- 助手气泡渲染推荐卡片、打开帖子/盯作者动作、「不喜欢」反馈。
- 帖子详情已登录时渲染「盯作者」「盯本帖修订」并创建对应 Watch。
- Mock JWT 路由覆盖 memory/watch/hits/feedback；未知 Watch 条件 400。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| FX-059 | `AssistantRepository.chat` 跳过 `AssistantEventType.unknown`；`assistant_repository_test` 与 notifier/widget 测试断言流不中断。 |
| FX-080 | `AgentConsentState.needsUpgrade`/`canUseMemoryWatch`；记忆/Watch 页过期授权只读 FAlert；同意后 `grant()` POST 升级。 |
| FX-081 | `/assistant/memory` 列出 profile/interest/task，区分已确认；改值/分值、删除、`suppressed`；失败 ErrorView。标识走 `jsonInt64Id`。 |
| FX-082 | `/assistant/watch` 列出/创建/启停/删除；条件仅四种；未知类型客户端与 Mock 均拒绝。 |
| FX-083 | Watch 命中收件箱列出、标已读、已验证 postId 打开帖子；不写入私信。 |
| FX-084 | `AssistantStructuredCard` 只从 payload 取 `verifiedPayloadId`；推荐卡片渲染标题/摘要。 |
| FX-085 | `actions` 渲染独立按钮；失败 toast 不阻塞后续事件。 |
| FX-086 | 帖子详情「盯作者」「盯本帖修订」；未授权/待升级引导 `/assistant`。 |
| FX-087 | 推荐卡片「不喜欢/不感兴趣」调用 `submitRecommendFeedback`；失败不回写成功态。 |

实现映射见 [IMP-flutter-client](../implementation/IMP-flutter-client.md)。

## 待补证据

真实网关联调（consent 版本升级、记忆/Watch 写路径、card/actions/watch_hit SSE）
待根仓联调环境跑通后补充，升级为 verified。

## 历史提交映射

frontmatter 原记录 `2a2beaac9f70bb8f5ff23d2b34357d90c67f29e5`；主线重放后的等价提交为 `79b90ef06346c6a52eb47bc25ac253583282eaba`。
迁移时以 `git range-diff` 核对，差异仅为提交内自引用 SHA/知识说明。
