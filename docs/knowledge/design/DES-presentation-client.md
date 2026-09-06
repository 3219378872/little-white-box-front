---
id: DES-presentation-client
layer: design
title: 客户端展示系统与视觉迁移设计
status: active
role: baseline
owner: agent
upstream:
  - SPEC-client-engineering
tracks:
  - FQ-004
  - FQ-005
  - FQ-009
updated_at: 2026-09-06
---

# 客户端展示系统与视觉迁移设计

## 设计系统边界

Forui 是新建与迁移界面的首选组件库，当前依赖版本以 `pubspec.lock` 为准（现为 0.24.2）。Material 可
继续承担应用壳、无等价 Forui 能力和未纳入任务的既有界面。`AppTheme` 是颜色、排版和控件样式的唯一
所有者；`lib/app.dart` 统一装配 Forui 本地化、`FTheme`、`FToaster` 和 `FTooltipGroup`。页面不得复制
主题或嵌套另一套全局 overlay。

组件选型先查 <https://forui.dev/docs/llms.txt>，需要完整 API 时再查
<https://forui.dev/docs/llms-full.txt>。在线文档可能领先锁定版本；冲突时以锁文件、当前可编译 API 和
对应版本升级说明为准。图标优先使用 `FLucideIcons`，工具按钮提供可访问名称和 tooltip。Widget 测试
复用 `test/helpers/forui_test_builder.dart`，不得为每个测试复制主题壳。

## 视觉基准

FQ-009 的参考是用户提供的 Heybox Android `com.max.xiaoheihe` 1.3.394 (1127)，APK SHA-256 为
`c6138fcd44d1343f8fe608ee983621490940e850ce54c674a9ee9972d7e4f5f7`。仅复刻排版、密度、层级和控件
语言，不纳入参考账号、凭据、私有内容或商业素材，也不新增小白盒没有的业务入口。

亮色主表面/主字为 `#FFFFFF`/`#14191E`，暗色为 `#101112`/`#E1E2E3`；次级表面和细分隔明确区别
于主表面。常用字号 12/14/16/18/20，字距为 0；图片圆角 4、标签 2、常规控件不超过 8，不用浮卡阴影。
输入使用低对比填充但保留聚焦/错误边界，正文编辑器保持连续书写面。

## 响应式与页面结构

| 范围 | 结构约束 |
| --- | --- |
| 导航 | 桌面五项侧栏，移动首页/搜索/发布/消息/我的；详情、编辑和线程隐藏底栏 |
| Feed | 单列通栏，桌面阅读宽 720；图片布局保持稳定几何，加载/失败不位移 |
| 详情评论 | 标题在作者前；正文/评论入口清楚；底部互动和输入不遮挡内容 |
| 搜索资料 | 紧凑搜索与类型 Tab；资料身份、统计、快捷入口和帖子/收藏层级稳定 |
| 写作认证 | 连续书写区、素材和标签；字段、错误、键盘和返回后的草稿均可恢复 |
| 私信 Agent | 会话与线程适配窄屏；只展示实际可发送能力；管理动作进入紧凑菜单/列表 |

亮暗主题及 touch/desktop variant 必须同时维护。导航图标继承外层 `IconTheme`，角标不改变入口盒子；
文本和标签在 320px 窄屏及长内容下不溢出或遮挡。语义名称、选中态、键盘、触摸目标、系统安全区和
`disableAnimations` 均属于展示验收，不以截图替代交互或服务端正确性。

## 不变边界

视觉工作不改变 repository、notifier、鉴权、幂等、revision、游标、SSE 或输入上限。没有参考样本的
私信、Agent、Memory 和 Watch 按同一设计系统适配，但不得声称经过原版逐像素比对。视觉证据至少区分
Web/原生、亮/暗、移动/桌面、自动化/人工检查和临时/持久产物。

| 条款 | 设计位置 |
| --- | --- |
| `FQ-004` | 设计系统、共享组件与辅助语义 |
| `FQ-005` | 响应式、主题、输入方式和平台证据边界 |
| `FQ-009` | 视觉基准、全页面结构和不变业务边界 |
