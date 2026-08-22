---
id: EVD-assistant-evidence-strip-2026-08-22
layer: evidence
title: Assistant 证据行与全角标记隐藏 2026-08-22
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-051
updated_at: 2026-08-22
observed_commit: fead883fa0db37fdcf7ee5c1833b7f53800b5bed
---

# Assistant 证据行与全角标记隐藏 2026-08-22

## 范围与环境

延续 EVD-assistant-source-display-2026-08-22：前端展示层进一步隐藏后端为 `ASST-010` 追加到回答
文本的证据块（`Community sources` 标题行、`SOURCE [post:id]` 行、`COMMUNITY_CONTENT_JSON=` 行）
以及模型自生引用被中性化的全角 `［post:id］` 标记，并修正剥离后的首尾空行。跳转按钮仍由结构化
source 事件渲染，不受影响。纯展示层改动；后端契约未动（ASST-010 要求引用存在于回答文本，
ASST-012 要求服务端验证的半角引用由服务端追加）。工作树 `.worktree/task-assistant-evidence-strip`。

对照后端观察：工作区 `little-white-box-content-community` `app/assistant/rpc/internal/logic/chat_logic.go`
——`appendSourceEvidence`（正常路径追加）与 `sendEvidenceDegraded`（LLM 不可用时透出工具原文）
都会把上述结构行作为 token 发送；两条路径由同一组正则覆盖。规格核对：
`SPEC-grounded-assistant.md` ASST-010/012 为 approved，故不在后端删除该块。

## 命令与结果

```bash
flutter analyze
# 无 error（20 条存量 info）
flutter test
# 171 个测试全部通过；assistant_page_test 断言证据块三行、半角与全角标记均不出现在正文，
# 且 post:7 / post:9 按钮标签仍在
make knowledge-check
# knowledge-check: OK (19 formal documents, 25 requirements, 57 local links)
```

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-051` | 可点击来源仍只来自已验证帖子的 source 事件并跳转 `/post/<id>`；回答文本中的机器追加证据行与中性化标记仅是展示残留，隐藏它们不减少可验证来源信息 |

## 未证明范围

- 未连接真实网关做流式人工核对；流式中间帧可能短暂出现残缺证据行，完成帧收敛为干净文本。
- 剥离按当前后端固定格式匹配（行首 `SOURCE` / `COMMUNITY_CONTENT_JSON=` / `Community sources`）；
  后端若改措辞需同步调整。
