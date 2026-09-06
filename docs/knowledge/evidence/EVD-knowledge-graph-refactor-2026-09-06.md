---
id: EVD-knowledge-graph-refactor-2026-09-06
layer: evidence
title: 客户端知识图谱重构验证 2026-09-06
status: active
result: passed
owner: agent
upstream:
  - IMP-client-platform
  - IMP-community-client
  - IMP-messaging-client
  - IMP-assistant-client
  - IMP-presentation-client
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
  - FX-041
  - FX-050
  - FX-051
  - FX-060
  - FX-061
  - FX-062
  - FX-070
  - FX-086
  - FX-091
  - FX-092
  - FQ-001
  - FQ-002
  - FQ-003
  - FQ-004
  - FQ-006
  - FQ-008
scope:
  - static
  - unit
  - integration
commands:
  - make analyze
  - make test
  - make test-coverage
  - make check BACKEND_API=/home/dev/projects/little/little-white-box-content-community/app/gateway/gateway.api
  - ruff check tools/knowledge_base.py tools/test_knowledge_base.py
  - make knowledge-check
  - git diff --check
observed_commit: 3b2158f1eb3f4debc4e3757f9e6ca54657c9b95d
updated_at: 2026-09-06
---

# 客户端知识图谱重构验证

## 范围与环境

本证据观察前端提交 `3b2158f1eb3f4debc4e3757f9e6ca54657c9b95d`。SDK 漂移检查显式使用后端
提交 `f706309f860621e7d9079333cf33e81557253b73` 工作树中的 `app/gateway/gateway.api`，没有依赖
未核验的相邻仓自动发现。执行环境为 Flutter 3.44.7、Dart 3.12.2。

本页只证明当前源码上的静态分析、单元/Widget 测试、Mock transport 集成以及生成契约漂移检查。它
不包含浏览器、实体设备、真实网关、真实 provider 或生产观察。

## 命令与结果

| 命令 | 结果 |
| --- | --- |
| `make analyze` | exit 0，`No issues found` |
| `make test` | exit 0，496 项 Flutter 测试全部通过 |
| `make test-coverage` | exit 0，496 项 Flutter 测试与 51 项工具测试（含 40 项 knowledge fixtures）通过；7786/9546 行，81.6%，高于 70% 门槛 |
| `make check BACKEND_API=.../app/gateway/gateway.api` | exit 0；静态分析、496 项 Flutter 测试、51 项工具测试（含 40 项 knowledge fixtures）、知识图谱和 SDK 非写入重生成比较全部通过 |
| `ruff check tools/knowledge_base.py tools/test_knowledge_base.py` | exit 0，`All checks passed` |
| `make knowledge-check` | exit 0，58 份正式文档、54 条 approved 条款、114 个本地链接通过闭环校验 |
| `git diff --check` | exit 0，无空白错误 |

组合门禁中的知识校验报告 58 份正式文档、54 条 approved 条款、114 个本地链接，迁移状态为
25 aligned、1 diverged、28 unknown；SDK 检查报告 `generated SDK is current`。

## 条款证据

| 领域 | 条款 | 当前证据 |
| --- | --- | --- |
| 平台 | `FX-001`、`FX-002`、`FX-010`、`FX-070`、`FQ-001`、`FQ-002`、`FQ-003`、`FQ-006`、`FQ-008` | analyzer、身份/路由/transport/精确 ID/异步状态测试、知识 checker fixtures 与指定 API 的 SDK 重生成比较通过 |
| 社区 | `FX-020`～`FX-022`、`FX-030`～`FX-032`、`FX-060`～`FX-062` | 推荐/关注/搜索、写入/详情/评论/资料以及行为队列的 repository、notifier 和 Widget 回归通过 |
| 私信 | `FX-041` | 会话、线程、已读/未读收敛测试通过；新增 Snowflake receiver/media JSON number 回归通过 |
| Assistant | `FX-050`、`FX-051`、`FX-086`、`FX-091`、`FX-092` | 虚拟线程入口、结构化来源、禁止 self-watch、Stop 迟到输出隔离及单会话/清历史回归通过 |
| 展示 | `FQ-004` | 共享主题、响应式导航、tooltip/语义、窄屏溢出和 reduced-motion Widget 测试及 analyzer 通过 |

## 未证明范围

- `FX-040` 仍缺后端视频/语音上传契约，保持 `diverged`。
- `FQ-007` 同时要求真实接口和浏览器验证；本页只有 static/unit/integration 范围，保持 `unknown`。
- Assistant 的其余真实授权、SSE、Memory、Watch、研究和来源闭环仍需浏览器、真实网关或 provider
  证据，保持 `unknown`。
- `FQ-005` 与 `FQ-009` 没有实体设备/iOS 和持久化视觉验收包；Heybox 的 `/tmp` 产物仍只支持
  `active/partial` 结论。
- 本地覆盖率和 Mock 测试不能推出线上可靠性、安全性、真实模型质量或生产就绪。
