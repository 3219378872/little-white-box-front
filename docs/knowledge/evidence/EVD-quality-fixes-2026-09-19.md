---
id: EVD-quality-fixes-2026-09-19
layer: evidence
title: 前端质量审查八项修复与回归验证
status: active
result: passed
owner: agent
scope: [static, unit]
commands:
- make format-check analyze
- flutter test --no-pub --coverage --reporter expanded
- python3 tools/lcov_summary.py coverage/lcov.info --min 70
- make tools-test sdk-check KNOWLEDGE_PYTHON=/home/dev/projects/little/little-white-box-front/.venv-knowledge/bin/python BACKEND_API=/home/dev/projects/little/little-white-box-content-community/.worktree/task-frontend-quality-fixes/app/gateway/gateway.api
- flutter build web --no-pub --release -t lib/main.dart
artifacts:
- docs/knowledge/evidence/assets/quality-fixes-2026-09-19/validation-summary.json
observed_commit: f9dbc113f097bffb664e6b8add7f7c9be4b3e89a
updated_at: '2026-09-19'
coverage:
- requirements: [FX-001, FX-002, FX-010, FX-070, FQ-001, FQ-002, FQ-003, FQ-006, FQ-008]
  paths:
  - lib/app.dart
  - lib/main.dart
  - lib/main_mock.dart
  - lib/core/api
  - lib/core/auth
  - lib/core/router
  - lib/core/state
  - lib/mock
  - lib/sdk
  - vendor/sdk_source
  - tools
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - android/settings.gradle.kts
  - test
  - lib
  - web
- requirements: [FX-020, FX-021, FX-022, FX-030, FX-031, FX-032, FX-060, FX-061, FX-062]
  paths:
  - lib/features/feed
  - lib/features/search
  - lib/features/post
  - lib/features/comment
  - lib/features/profile
  - lib/features/behavior
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
- requirements: [FX-041]
  paths:
  - lib/features/message
  - test/features/message
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
- requirements: [FX-050, FX-051, FX-086, FX-091, FX-092]
  paths:
  - lib/features/assistant
  - test/features/assistant
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
- requirements: [FQ-004]
  paths:
  - lib/core/theme
  - lib/core/widgets
  - lib/core/router/app_router.dart
  - test/helpers/forui_test_builder.dart
  - tools/heybox_visual_check.mjs
  - tools/heybox_android_check.py
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
---

# 前端质量审查八项修复与回归验证

上述命令在实现提交 `f9dbc113f097bffb664e6b8add7f7c9be4b3e89a` 上执行，验证前后受跟踪工作树干净。
本证据和 IMP 引用在后续提交新增。工具链为 Flutter 3.47.2 / Dart 3.13.2；生成器为 goctl 1.10.1。

| 审查问题 | 修复与回归证据 |
| --- | --- |
| 编辑路由切换误写另一帖子 | `post_editor_route_test.dart` 验证新 ID/正文/revision、旧加载/保存的成功与失败，以及上传途中切换后不发出旧写入 |
| 发送完成清空新草稿 | 评论输入与私信 Widget 测试验证提交草稿正常清理、新草稿保留、失败命令重试不清空无关文本且复用幂等键 |
| 私信发送导致初始历史丢失 | notifier 测试验证历史与新消息按 ID 合并、保留 hasMore、仍标记已读，重复 ID 以服务端字段为准 |
| 关注状态每次进入重置 | 资料 Widget 测试验证重新进入、取消关注、错误回滚和账号切换；repository 拒绝缺失/非法关系，Mock 按访问者隔离 |
| 评论刷新失败重试错页 | 验证保留 1/20 条旧评论时均重试第一页，分页失败仍重试原下一页 |
| 楼中楼展开请求竞态 | 验证旧成功/错误既不能解除当前 loading，也不能覆盖重开后已返回的线程 |
| 缺字段成功体伪造空搜索/零未读 | 三类搜索缺结果列表及非法用户 total 均失败；明确 null 数组可用；非法未读汇总保留之前有效计数 |
| JSON 与 refresh 没有期限 | 五种 HTTP 方法、响应体停滞、迟到成功、共享刷新超时、令牌保留及重试均使用测试时钟验证 |

全部 Flutter 测试为 **576 passed**，较原 533 项净增 43 项；维护工具 **52 passed**。
格式检查 207 个 Dart 文件、零变化，analyze 无问题。手写行覆盖率为 **8069/9700 = 83.2%**，
排除范围仍仅为两个生成的 Gateway Dart 文件。真实入口 `lib/main.dart` 的 release Web 构建成功；
这不等同于浏览器运行验收。

SDK 检查针对后端 rebase 后实现提交 `0184c600d8a0fcfb8e7701464fa3e5ef330f7faf` 的 `gateway.api`，两份 SDK
在临时目录重生比较通过。公开用户资料新增布尔 `isFollowing`，内部 RPC 新增 viewer_id；后端读取与
数据库验证归后端 `EVD-20260919-profile-follow-state`。两端按先服务端后客户端顺序集成。
后端 rebase 保留 main 的并行修复，公开契约内容未再变化；针对合并后版本重新执行 SDK 重生成比较，
前端源码、测试与依赖仍与观察提交一致。

五个 coverage 组完整保留 `EVD-review-remediation-2026-09-08` 的 requirements 与 paths，更新原有
25 条 aligned 的证明，28 条 unknown 和 1 条 diverged 的条款状态及 gap 均不改写。旧证据结果保留。
本页只包含静态、单元、Widget、fake/Mock transport 和构建证据；没有运行浏览器、实体设备、真实
网关 E2E、真实短信/媒体服务、真实模型、容量或生产验证。15 秒期限结束客户端等待，不承诺取消已经
在服务端执行的写入；重试仍依赖原幂等键或 revision。私信视频/语音缺口仍登记为 FX-040 diverged。
