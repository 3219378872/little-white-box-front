---
title: 小白盒前端知识总路由
status: active
owner: human
updated_at: 2026-09-06
---

# 五层知识总路由

本仓库的正式知识只沿下面的链路传递：

```text
意图层 -> 规格层 -> 设计层 -> 实现层 <-> 证据层
```

意图定义产品价值、能力、优先级和非目标；规格定义工程约束、质量指标与验收条件，不规定内部实现。
框架、组件库、协议字段、内部状态结构及实现算法归设计；外部兼容承诺和安全边界仍受规格约束。
上游回答“为什么、必须保证什么”，下游回答“如何做、当前实际是什么”。历史材料只用于追溯，不能作为
当前规则。

## 层级与当前入口

| 层级 | 回答的问题 | 语义所有者 | 当前入口 |
| --- | --- | --- | --- |
| 意图 | 为谁解决什么问题，边界是什么 | human | [前端产品意图](intent/INT-content-community-client.md) |
| 规格 | 必须满足哪些工程约束、指标和验收条件 | human | [体验规格](spec/SPEC-client-experience.md)、[工程规格](spec/SPEC-client-engineering.md) |
| 设计 | 组件如何协作、为何这样取舍 | agent | [Flutter 客户端设计](design/DES-flutter-client.md)、[Assistant 问答与卡片](design/DES-assistant-research-client.md) |
| 实现 | 当前代码如何承载设计、已知偏离是什么 | agent | [实现映射](implementation/IMP-flutter-client.md)、[Forui 实现指南](implementation/IMP-forui-ui.md) |
| 证据 | 哪个版本以什么命令或观察得到什么结论 | agent | [当前基线证据](evidence/EVD-client-baseline-2026-08-13.md) |

旧的 MVP 计划、仓库迁移记录和后端联调快照位于[归档索引](archive/README.md)。归档内容不参与正式
上游引用。

当前 `INT-content-community-client`、`SPEC-client-experience` 和 `SPEC-client-engineering` 已于
2026-08-13 获得人类明确批准。`DES-flutter-client` 仍为 `baseline`，当前整体实现仍为 `diverged`；
批准上游语义不等于接受设计或完成代码修复。

2026-09-06 按人类授权增加 FQ-009 全界面视觉迁移，入口为
[Heybox Android 设计](design/DES-heybox-presentation.md)、
[视觉实现映射](implementation/IMP-heybox-presentation.md)与
[本轮验收](evidence/EVD-heybox-presentation-2026-09-06.md)。

## 两种权威

- **语义权威**：只有状态为 `approved` 的意图和规格，以及引用它们的 `accepted` 设计，才约束未来
  变更。`baseline` 是从已合并代码、既有文档和跨仓契约整理出的过渡基线，不等于人类批准。
- **事实权威**：源码、配置、依赖锁、接口生成物和可复现测试高于实现说明。代码与设计不一致时，
  实现必须标记为 `diverged`，不得通过反向修改意图或规格掩盖差异。

`owner: human` 表示意图和规格的最终语义决定权属于人类，不表示文件只能由人类编辑。当前对话中的
明确自然语言要求可以授权 agent 整理或修改这些文件；没有明确批准时不得把 `baseline` 或 `draft`
提升为 `approved`。

## 状态约定

| 层级 | 允许状态 | 含义 |
| --- | --- | --- |
| 意图、规格 | `draft`、`baseline`、`approved`、`deprecated` | 提案、过渡基线、人类批准、停用 |
| 设计 | `draft`、`baseline`、`accepted`、`deprecated` | 草案、现状设计、已接受设计、停用 |
| 实现 | `aligned`、`diverged`、`unknown`、`deprecated` | 对齐、已知偏离、未核验、停用 |
| 证据 | `verified`、`partial`、`failed`、`superseded` | 已验证、部分验证、失败记录、被替代 |

## 加载与修改顺序

1. 从本页找到任务相关的意图和规格，只读取需要的主题。
2. 读取引用这些规格的设计，再定位实现页、源码和最近证据。
3. 修改行为前按规格条款 ID 建立追踪；上游缺失或冲突时先以 `draft` 记录并请求人类决定，不从代码
   猜出正式要求。
4. 修改代码后同步实现映射；运行验证后新增或更新带日期证据，并保持实现与证据双向引用。
5. 历史计划保持原样归档。要恢复其中的决定，必须重新进入意图、规格或设计层并获得相应状态。

## 文档契约

- 正式文档 ID 使用 `INT-*`、`SPEC-*`、`DES-*`、`IMP-*`、`EVD-*`。
- 正式页面 frontmatter 必须包含 `id`、`layer`、`title`、`status`、`owner`、`upstream` 和
  `updated_at`。
- 规格只能引用意图，设计只能引用规格，实现只能引用设计，证据只能引用实现。
- 设计和实现用 `tracks` 引用规格条款；证据用 `covers` 记录实际核验到的条款。
- 实现用 `evidence` 引用证据，证据的 `upstream` 必须反向引用该实现，形成可机器校验的双向关系。
- 正式知识以外的工作笔记不得被自动吸收；确有长期价值时，按所属层重写后再纳入。

模板位于 [templates](templates/README.md)。结构、引用、条款覆盖和本地链接使用以下命令检查：

```bash
make knowledge-check
```

## 跨仓协调边界

后端仓库的 `INT-content-community-backend`、`SPEC-community-core`、`SPEC-content-discovery`、
`SPEC-assistant-agent`、`SPEC-agent-memory`、`SPEC-agent-watch` 和 `SPEC-feedback-reliability`
是前端接口语义的重要来源。`SPEC-grounded-assistant` 与 `SPEC-assistant-agent-mode` 已由后端
retired/deprecated，不再作为当前契约。本仓库不复制它们作为自身已批准知识；每次涉及契约的变更
都要在后端仓库重新核对当前版本，并在证据层记录所观察的提交。
