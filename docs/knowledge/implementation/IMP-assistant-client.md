---
id: IMP-assistant-client
layer: implementation
title: Assistant 虚拟线程与研究交互实现映射
status: unknown
owner: agent
upstream:
  - DES-assistant-client
tracks:
  - FX-050
  - FX-051
  - FX-052
  - FX-053
  - FX-054
  - FX-055
  - FX-056
  - FX-057
  - FX-058
  - FX-059
  - FX-080
  - FX-081
  - FX-082
  - FX-083
  - FX-084
  - FX-085
  - FX-086
  - FX-087
  - FX-088
  - FX-089
  - FX-090
  - FX-091
  - FX-092
  - FX-093
  - FX-094
  - FX-095
  - FX-096
  - FX-097
  - FX-098
  - FX-099
code_paths:
  - lib/features/assistant
  - test/features/assistant
evidence:
  - EVD-knowledge-graph-refactor-2026-09-06
  - EVD-assistant-research-2026-09-05
  - EVD-audit-remediation-client-2026-08-31
  - EVD-code-quality-hardening-2026-09-05
  - EVD-heybox-presentation-2026-09-06
updated_at: 2026-09-06
---

# Assistant 虚拟线程与研究交互实现映射

REST/SSE 模型、repository、线程与 Memory/Watch 状态机、展示组件和对应测试均位于
`lib/features/assistant` 与 `test/features/assistant`。旧 EVD 说明实现演进，但只有仍为 `active` 的记录
表示当前未关闭边界；历史 passed 记录不能支撑本表的当前对齐结论。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-050 | DES-assistant-client | aligned | EVD-knowledge-graph-refactor-2026-09-06 |
| FX-051 | DES-assistant-client | aligned | EVD-knowledge-graph-refactor-2026-09-06 |
| FX-052 | DES-assistant-client | unknown | gap: no current browser evidence for equivalent mobile and desktop entry hierarchy |
| FX-053 | DES-assistant-client | unknown | gap: no current real-gateway first-task consent round trip |
| FX-054 | DES-assistant-client | unknown | gap: no current real-gateway authorization rejection and retry round trip |
| FX-055 | DES-assistant-client | unknown | gap: device image selection and real media upload are not currently verified |
| FX-056 | DES-assistant-client | unknown | gap: real tool progress and high-risk confirmation loop are not currently verified |
| FX-057 | DES-assistant-client | unknown | gap: real confirm rejection, expiry, conflict, and failure loop are not currently verified |
| FX-058 | DES-assistant-client | unknown | gap: redirect, steer, queue limit, and Stop are not verified under real concurrent runs |
| FX-059 | DES-assistant-client | unknown | gap: Flutter browser SSE disconnect and unknown-event recovery are not currently verified |
| FX-080 | DES-assistant-client | unknown | gap: consent-version upgrade is not currently verified against a real gateway |
| FX-081 | DES-assistant-client | unknown | gap: current real Memory CRUD, capacity, failure, and undo coverage is partial |
| FX-082 | DES-assistant-client | unknown | gap: current real Watch CRUD and version-conflict coverage is partial |
| FX-083 | DES-assistant-client | unknown | gap: scheduled Watch delivery into the thread and unread convergence lack current end-to-end evidence |
| FX-084 | DES-assistant-client | unknown | gap: source mutation and invalidation payload presentation lacks current end-to-end evidence |
| FX-085 | DES-assistant-client | unknown | gap: memory_changed unread exclusion and real undo failure recovery lack current end-to-end evidence |
| FX-086 | DES-assistant-client | aligned | EVD-knowledge-graph-refactor-2026-09-06 |
| FX-087 | DES-assistant-client | unknown | gap: recommendation-source feedback lacks current real-gateway evidence |
| FX-088 | DES-assistant-client | unknown | gap: 30-second thread polling and combined unread lack current timed integration evidence |
| FX-089 | DES-assistant-client | unknown | gap: all asynchronous acceptance dispositions lack current real-gateway evidence |
| FX-090 | DES-assistant-client | unknown | gap: Flutter browser replay, disconnect, and response_reset recovery remain partially verified |
| FX-091 | DES-assistant-client | aligned | EVD-knowledge-graph-refactor-2026-09-06 |
| FX-092 | DES-assistant-client | aligned | EVD-knowledge-graph-refactor-2026-09-06 |
| FX-093 | DES-assistant-client | unknown | gap: thread read failure and Watch/Memory unread rules lack current real-gateway evidence |
| FX-094 | DES-assistant-client | unknown | gap: current browser animation, history prefix, reset, and disableAnimations evidence is partial |
| FX-095 | DES-assistant-client | unknown | gap: real-provider browser clarification workflow has not passed end to end |
| FX-096 | DES-assistant-client | unknown | gap: real-provider pending-question recovery and explicit continuation have not passed end to end |
| FX-097 | DES-assistant-client | unknown | gap: real source excerpt cards and unavailable-source handling have not passed end to end |
| FX-098 | DES-assistant-client | unknown | gap: a real long research run timed out before publishing a validated answer |
| FX-099 | DES-assistant-client | unknown | gap: real-provider browser citation navigation and invalidation handling have not passed end to end |
