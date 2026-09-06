---
title: 小白盒前端知识总路由
status: active
owner: human
updated_at: 2026-09-06
---

# 五层知识总路由

正式知识只沿以下链路传递：

```text
意图 -> 规格 -> 设计 -> 实现 <-> 证据
```

意图和规格回答“为什么、必须保证什么”，设计回答“如何协作”，实现回答“当前代码实际如何”，证据
回答“在哪个版本、以什么方法得到什么结果”。归档和旧稳定 ID 指针只用于追溯，不参与当前条款覆盖。

## 当前入口

| 层级 | 页面 |
| --- | --- |
| 意图 | [内容社区客户端](intent/INT-content-community-client.md) |
| 规格 | [体验与接口](spec/SPEC-client-experience.md)、[工程](spec/SPEC-client-engineering.md) |
| 设计 | [平台](design/DES-client-platform.md)、[社区](design/DES-community-client.md)、[私信](design/DES-messaging-client.md)、[Assistant](design/DES-assistant-client.md)、[展示](design/DES-presentation-client.md) |
| 实现 | [平台](implementation/IMP-client-platform.md)、[社区](implementation/IMP-community-client.md)、[私信](implementation/IMP-messaging-client.md)、[Assistant](implementation/IMP-assistant-client.md)、[展示](implementation/IMP-presentation-client.md) |
| 证据 | [证据索引](evidence/README.md) |

`INT-content-community-client`、`SPEC-client-experience` 与 `SPEC-client-engineering` 已获人类批准。五个
当前 DES 按责任边界承接全部 54 条 approved requirement；其 `role: baseline` 表示内容由现状和已批准
契约投影，不是 lifecycle。每条条款的当前实现结论只看对应 IMP 的唯一权威矩阵和 EVD，不从概述推断。

## 权威与状态

源码、配置、依赖锁、生成契约和可复现观察是当前事实。代码与设计不一致时写 `diverged`；尚无足够
当前证据时写 `unknown`，不得用历史 passed、Mock 或结构检查把它提升为 `aligned`。

| 层级 | lifecycle/status | 补充字段 |
| --- | --- | --- |
| 意图、规格 | `draft`、`approved`、`retired` | 语义 owner 必须为 human |
| 设计 | `draft`、`active`、`blocked`、`superseded` | 可选 `role: baseline` |
| 实现 | `unknown`、`aligned`、`diverged`、`retired` | 当前页必须逐条声明权威矩阵 |
| 证据 | `active`、`superseded` | `result: passed/partial/failed/blocked` 与 `scope` 分开记录 |

`active/passed` 只表示该 EVD 在声明范围、命令和观察提交上通过。它不能证明未列范围，也不能在观察提交
被后续代码变更覆盖后继续充当当前证据。validator 会针对 EVD 的每个上游 IMP 执行等价于
`git diff <observed_commit>..HEAD -- <code_paths>` 的检查；`code_paths` 取自该观察提交上对应 IMP 当时的
声明，并覆盖这些路径下工作树、暂存区和未跟踪文件。若迁移前的观察提交还没有该 IMP，才回退当前声明。
任一路径发生变化都会使该证据失效，单独更新 IMP/EVD 知识页则不会误报。仅临时 `/tmp` 产物不能支撑
active passed 的视觉或运行结论。

## 文档契约

- 正式页文件名必须等于 `INT-*`、`SPEC-*`、`DES-*`、`IMP-*` 或 `EVD-*` ID，并包含
  `id/layer/title/status/owner/upstream/updated_at`；`title` 必须是非空白文本。
- 规格只引用意图，设计只引用规格，实现只引用设计，证据只引用实现。DES/IMP 的 `tracks` 和 EVD 的
  `covers` 只能使用本仓 `FX-NNN`/`FQ-NNN`。
- `upstream`、`tracks`、`code_paths`、`evidence`、`covers`、`scope`、`commands`，以及存在时的
  `external_upstream`，其列表项都必须是非空白文本且不得重复。
- 非 retired IMP 必须声明存在的 `code_paths`、完整 `evidence` 反向列表，并且恰好包含一个表头为
  `requirement | design | state | evidence or gap`、紧跟合法 Markdown 分隔行的逐条权威矩阵。只有该表
  后连续的表格数据行具有权威性；正文其他位置形似权威行的内容不参与解析。`aligned` 至少引用一个
  active passed EVD；`unknown/diverged` 写 `gap:`。
- EVD 必须声明非空 `scope`、`commands`、完整 40 位且为当前 HEAD 祖先的 `observed_commit`。提交信息
  不能放在 IMP；结构测试通过不能代替功能证据。
- 每个层级 README 必须恰好一次列出该层所有正式页。模板位于 [templates](templates/README.md)，历史
  材料位于[归档](archive/README.md)。

规格条款只从 frontmatter 之后可见 Markdown 的正式定义解析：`-`/`*` 列表项必须使用反引号条款 ID、
冒号和非空定义；表格的第一列表头必须归一化为 `requirement`、`条款` 或 `id`，紧跟列数一致的合法
separator，只有之后连续且列数一致的数据行可定义条款。表格可省略外侧 pipe，转义的 `\|` 不作为
列分隔。普通正文引用、孤立表格行和其他表格不建立条款所有权。IMP 权威矩阵和层级 README 索引同样
只解析可见内容。checker 先隔离 fenced code block，再识别 fence 外、匹配 inline backtick code span
之外的 HTML comment。fence 可位于 blockquote、列表 marker 同行或列表续行；其容器由 quote 深度和按
tab stop 4 计算的列表内容缩进约束，未闭合 fence 在退出 quote、退回列表内容缩进之外或进入同级/外层
列表项时结束。跨行 code span 只由长度完全相同的 backtick run 闭合，并且不能越过空行、ATX/Setext
标题或 fenced code block 起始；列表项内的 span 也不能跨越嵌套、同级或外层列表项。未闭合的 opener
按字面量处理；info string 含 backtick 的非法 fence-shaped 行也不能发起跨行匹配。未闭合的 `<!--`
隐藏到文件末尾，而 code span 或 fence 内的注释标记只作为字面量。被上述区域隐藏的示例、草稿或链接
不参与条款归属、权威状态和索引计数。

## 跨仓边界

后端契约不复制成本仓 approved 语义。需要精确追溯时使用非空 block list：

```yaml
external_upstream:
  - little-white-box-content-community@<40sha>:SPEC-community-core
  - little-white-box-content-community@<40sha>:CORE-013
```

目标可为正式文档 ID 或后端 requirement ID；提交必须是根仓当前后端 gitlink 的祖先或自身，且目标在该
提交唯一存在。前端 SDK 检查必须显式使用已核验 gitlink 对应的 `gateway.api`。旧的 retired 后端规格
只可用于历史解释，不作为当前契约。

## 加载与验证

先从本页找到条款所属领域，只读取相关 SPEC、DES、IMP 和最新 EVD。修改行为前定位条款；完成后先提交
实现，再在该提交实际运行声明命令，最后以跟进 EVD 提交记录结果，避免证据自指。

```bash
make knowledge-test
make knowledge-check
make sdk-check BACKEND_API=/absolute/path/to/verified/gateway.api
make check BACKEND_API=/absolute/path/to/verified/gateway.api
```
