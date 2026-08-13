---
id: EVD-client-baseline-2026-08-13
layer: evidence
title: Flutter 客户端基线证据 2026-08-13
status: verified
owner: agent
upstream:
  - IMP-flutter-client
  - IMP-forui-ui
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
  - FX-040
  - FX-041
  - FX-050
  - FX-051
  - FX-060
  - FX-061
  - FX-062
  - FX-070
  - FQ-001
  - FQ-002
  - FQ-003
  - FQ-004
  - FQ-005
  - FQ-006
  - FQ-007
  - FQ-008
updated_at: 2026-08-13
observed_commit: edf598f291c889c3ec3bbdc597ab3acff6a0c9fd
---

# Flutter 客户端基线证据 2026-08-13

## 范围与环境

本证据核验知识迁移结构、当前主分支源码映射和本地自动化测试。运行时代码基准为
`edf598f291c889c3ec3bbdc597ab3acff6a0c9fd`，知识整理是其上的未提交文档/工具变更。

跨仓契约核对使用同级后端仓库提交 `921549313e9a085c2d12ff7f21bfc9f692bd0940` 中的已批准
`INT-content-community-backend`、`SPEC-community-core`、`SPEC-content-discovery`、
`SPEC-grounded-assistant` 和 `SPEC-feedback-reliability`。

工具环境：

- Flutter 3.44.7 stable，framework revision `84fc5cbb22`
- Dart 3.12.2
- `pubspec.lock`：Forui 0.24.2、Riverpod 2.6.1、GoRouter 14.8.1、http 1.6.0

## 条款证据

| 条款 | 直接证据 | 结论 |
| --- | --- | --- |
| `FX-001`～`FX-010` | `lib/core/router/app_router.dart`、`auth_notifier.dart`、`api_adapter.dart`；router/auth/API tests | 公开/保护路由与认证恢复存在；业务码清理边界有测试 |
| `FX-020`～`FX-021` | `feed_repository.dart`、`feed_notifier.dart`；feed repository/notifier/Widget tests | 两类游标、归因字段、分页去重和匿名关注引导存在 |
| `FX-022` | `search_models.dart`、`search_repository.dart`、search tests | 基本搜索状态存在；未建模部分降级字段，见 `DIV-004` |
| `FX-030`～`FX-032` | `post_editor_page.dart`、`post_repository.dart`、生成的 gateway models、image picker | 草稿/发布和事务化 multipart 存在；revision/创建幂等和部分输入边界偏离，见 `DIV-002/003` |
| `FX-031` | post/comment/interaction/profile repositories、PostCard/profile tests | 详情、分页、互动回滚和用户帖子/收藏路径存在 |
| `FX-040`～`FX-041` | `message_notifiers.dart`、`message_repository.dart`、message tests | 幂等重试和已读独立失败存在；媒体能力/文本上限偏离，见 `DIV-005` |
| `FX-050` | Assistant repository/notifier/models 及对应 tests | SSE 解析、唯一终止、取消、断流和 2,000 字符边界有实现 |
| `FX-051` | `assistant_models.dart`、`assistant_page.dart` | 来源字段和类型边界不足，见 `DIV-006` |
| `FX-060` | `post_card.dart`、`behavior_tracker.dart`、tracking tests | 当前客户端提交 like/unlike，与后端事件所有权冲突，见 `DIV-001` |
| `FX-061`～`FX-062` | PostCard 可见性逻辑、tracker/queue/repository 及 behavior tests | 50%/1 秒曝光、去重、归因、持久队列、分批确认和退避存在 |
| `FX-070` | `main.dart`、`main_mock.dart`、`mock_http.dart`、`mock_router.dart`、Mock tests | transport 注入且 feature 同路径；真实网关未在本证据联调 |
| `FQ-001`～`FQ-006` | `lib/app.dart`、core/feature 目录、主题、路由和各 notifier | 分层、三类 transport、全局 Forui 装配、响应式壳和陈旧请求抑制存在 |
| `FQ-007` | `test/helpers/forui_test_builder.dart`、`test/` | 共享 Forui 测试壳和分层测试存在；命令结果见下节 |
| `FQ-008` | `docs/knowledge/`、`tools/knowledge_base.py`、Makefile | 五层目录、稳定 ID、条款覆盖和实现—证据双向校验已建立 |

## 偏离复核

以下结论来自源码直接检查，不由测试通过推断：

- `post_card.dart` 的点赞成功分支调用 `trackLike/trackUnlike`；后端批准规格只允许权威事务产生这些动作。
- `CreatePostReq` 无幂等键，帖子读取/更新/删除模型无 revision；PostEditor 的 100/10,000/5 限制与
  后端 120/20,000/10 边界不同。
- `SearchResults` 无 `degraded/unavailableTypes`。
- MessageThread 只构造默认文本消息且 UI 允许 4,000 字符。
- Assistant source 只有 type/id/title，且页面允许 `user` 类型，不含证据片段和内容版本。

## 命令与结果

| 命令 | 退出状态 | 结果 |
| --- | ---: | --- |
| `python3 -m py_compile tools/knowledge_base.py` | 0 | 校验脚本可编译 |
| `make knowledge-check` | 0 | 7 份正式文档、25 条规格、40 个本地链接通过；层间和双向引用完整 |
| `make analyze` | 2 | Flutter analyze 完成并发现 17 条既有 info；无 error、warning。info 来自生成 SDK 的 print/插值、两处 API 文档注释和 Mock 测试相对导入 |
| `make test` | 0 | 124 个测试全部通过 |
| `git diff --check` | 0 | 无空白错误 |

`make analyze` 的非零状态是已验证失败结果，不被测试通过覆盖；本次只整理知识和校验工具，没有修改
这些既有 Dart/生成代码问题。证据状态 `verified` 表示上述结果已实际取得，不表示所有规格均已对齐。

## 未证明范围

- 未连接真实 Gateway，不能证明 CORS、真实 token、v1/v2 契约、SSE 代理或服务端权限当前可用。
- 未启动浏览器进行桌面/移动端视觉与交互检查，不能用 Widget 测试替代真实渲染结论。
- 未验证后端行为消息进入 broker/outbox/分析/推荐特征的端到端闭环。
- 未验证搜索/推荐/Assistant 的线上质量、SLO、隐私保留或跨服务故障降级。
- 自动化通过不消除本页和实现层登记的 6 项契约偏离。
