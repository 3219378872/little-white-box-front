---
id: IMP-heybox-presentation
layer: implementation
title: Heybox 视觉实现映射
status: aligned
owner: agent
upstream:
  - DES-heybox-presentation
tracks:
  - FQ-004
  - FQ-005
  - FQ-009
  - FX-030
  - FX-031
  - FX-032
  - FX-050
evidence:
  - EVD-heybox-presentation-2026-09-06
updated_at: 2026-09-06
---

# Heybox 视觉实现映射

本轮仅变更前端展示与对应测试。全仓其他已登记的服务端/媒体能力缺口保持原状，不因视觉迁移关闭。

| 所有者 | 实现 |
| --- | --- |
| 共享主题 | `lib/core/theme/app_theme.dart`：亮暗色板、字号、Tab、导航、字段、标签、无阴影 |
| 共享控件 | `app_icon_button.dart`、`app_tag_badge.dart`、`skeleton_loader.dart`：命名工具、长标签、禁用动画 |
| 信息流 | `feed_page.dart`、`post_card.dart`、`post_media_preview.dart`：单列、无外卡框、多图组合，保留曝光/点击/赞 |
| 路由壳 | `app_router.dart`：阅读宽度、五项导航、Android 安全区、按当前 URI 隔离二级页底栏，覆盖 push/pop |
| 详情评论 | `post_detail_page.dart`、`comment_input.dart`、`comment_item.dart`：分区入口、固定互动、回复预览、登录返回后草稿保留 |
| 搜索/资料 | 各自 presentation：紧凑搜索结果、身份区、统计、快捷入口、资料深链返回 |
| 写作/认证 | `post_editor_page.dart`、`image_picker_grid.dart`、auth presentation：连续书写区、素材、字段和登录返回 |
| 私信/Agent | message 与 assistant presentation：线程返回、窄屏输入、Agent 更多菜单、管理列表 |
| 自动验收 | `test/core/theme/heybox_theme_test.dart`、现有 Widget/状态机测试、Web 与 Android 实拍脚本 |

Widget 公共壳现在选择实际 `AppTheme` 的亮暗主题，不再使用独立 neutral 默认主题。浏览器脚本生成
桌面/移动亮暗与 320px 窄屏的 120 张页面/交互截图，保存语义、网络失败、浏览器异常和非空像素统计。
`tools/heybox_android_check.py` 在独立模拟器采集本项目 Mock APK 的亮暗共 28 张图，断言二级页面
不保留主导航，并在结束时恢复系统亮色。Android 构建保留 Flutter 自动迁移的两项 Gradle
兼容属性 `android.builtInKotlin=false`、`android.newDsl=false`，不升级依赖或构建插件。
使用方式及实际结果见 [本轮证据](../evidence/EVD-heybox-presentation-2026-09-06.md)。
