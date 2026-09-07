---
id: EVD-knowledge-slim-2026-09-07
layer: evidence
title: 客户端知识结构精简验证 2026-09-07
status: active
owner: agent
updated_at: 2026-09-07
observed_commit: 0b2aa8e2827df795cfff2ba92b321e39ec6227de
result: passed
scope:
  - static
  - unit
  - integration
commands:
  - make check BACKEND_API=/home/dev/projects/little/little-white-box-content-community/app/gateway/gateway.api
  - make test-coverage
  - ruff check tools/knowledge_base.py tools/test_knowledge_base.py
  - git diff --check
coverage:
  - requirements:
      - FX-001
      - FX-002
      - FX-010
      - FX-070
      - FQ-001
      - FQ-002
      - FQ-003
      - FQ-006
      - FQ-008
    paths:
      - lib/app.dart
      - lib/core/api
      - lib/core/auth
      - lib/core/router
      - lib/mock
      - lib/sdk
      - vendor/sdk_source
      - tools
      - Makefile
      - pubspec.yaml
      - pubspec.lock
      - analysis_options.yaml
      - test
---

# 客户端知识结构精简验证

本页观察已完成 rebase 的提交 `0b2aa8e2827df795cfff2ba92b321e39ec6227de`，所有声明命令均在该提交
执行后以独立证据提交记录。修改限于知识文档、元数据、索引与校验工具，没有变更 Flutter 业务实现或 SDK。

SDK gate 显式使用后端提交 `58735970348ee2258a45058e8f85c21eb0fb4963` 的 Gateway API；读取前核对
工作文件 blob 为 `f190fb6b951861459a31b17854268e64362cb22d`，与后端本轮工具提交中的 API 一致。

## 实际结果

| 门禁 | 结果 |
| --- | --- |
| `make check BACKEND_API=...` | exit 0；analyzer 无问题，496 项 Flutter 测试通过，51 项工具测试通过，两份 Gateway SDK 精确重生成比较无漂移 |
| `make test-coverage` | exit 0；496 项 Flutter 测试和 51 项工具测试通过，7786/9546 行，81.6%，超过 70% 门槛 |
| `ruff check ...` | exit 0，All checks passed |
| `git diff --check` | exit 0 |

40 项知识回归覆盖安全 YAML、CommonMark 定义、唯一 IMP owner、多设计承接、机械索引、固定提交导出、
组间隔离、共享输入失效、缩小路径、相关条款变化、暂存/工作树/未跟踪变化和未知历史输入。其余 11 项工具
测试继续覆盖生成与维护工具。应用测试覆盖身份、路由、transport、Mock 网关集成及异步状态转换。

本次只重验因工具输入变化而过期的平台组。被验证提交中的 9 条平台行先明确登记待重验，本证据通过后
恢复其原有 aligned；其他组继续依据各自证据判断有效性。迁移前后批准条款定义、INT/SPEC 文件、责任归属
和主设计均保持不变，未提升原有 unknown/diverged。

## 未覆盖边界

本地 analyzer、单元/Widget、Mock 集成和生成物比较不构成浏览器、设备、真实接口、provider 或生产验证。
`FQ-007` 的真实接口与浏览器门禁保持 unknown，私信视频/语音等既有 gap 不变。旧 EVD 保留历史结果，
不会因新平台组通过而扩展其 scope 或重写其当时结论。
