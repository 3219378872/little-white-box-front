---
id: IMP-flutter-client
layer: implementation
title: Flutter 客户端实现迁移指针
status: retired
owner: agent
upstream:
  - DES-flutter-client
tracks: []
code_paths: []
evidence:
  - EVD-assistant-agent-mode-2026-08-26
  - EVD-assistant-agent-runtime-2026-08-27
  - EVD-assistant-evidence-strip-2026-08-22
  - EVD-assistant-hermes-2026-08-29
  - EVD-assistant-isolation-2026-08-30
  - EVD-assistant-md-render-2026-08-22
  - EVD-assistant-reset-snapshot-2026-08-31
  - EVD-assistant-single-session-2026-08-30
  - EVD-assistant-source-display-2026-08-22
  - EVD-assistant-stream-render-2026-08-31
  - EVD-assistant-stream-reset-2026-08-30
  - EVD-assistant-strict-reset-2026-09-01
  - EVD-audit-fixes-2026-08-28
  - EVD-auth-refresh-2026-08-21
  - EVD-auth-session-reset-2026-08-25
  - EVD-client-api-followup-2026-08-18
  - EVD-client-baseline-2026-08-13
  - EVD-client-found-bugs-fix-2026-08-22
  - EVD-client-login-home-redirect-2026-08-20
  - EVD-client-relative-api-2026-08-18
  - EVD-client-ui-align-2026-08-20
  - EVD-comment-replies-2026-08-22
  - EVD-exposure-event-driven-2026-08-25
  - EVD-family-provider-autodispose-2026-08-25
  - EVD-favorites-reload-2026-08-20
  - EVD-feed-pagination-ux-2026-08-20
  - EVD-mock-gateway-align-2026-08-20
  - EVD-non-agent-bugs-2026-08-27
  - EVD-paginated-load-more-error-2026-08-25
  - EVD-posts-reload-2026-08-20
  - EVD-search-post-author-2026-08-20
  - EVD-watch-cannot-self-2026-09-06
  - EVD-web-json-int64-2026-08-20
updated_at: 2026-09-06
---

# Flutter 客户端实现迁移指针

原单体实现映射已拆分为：

- [客户端平台](IMP-client-platform.md)
- [社区发现与内容](IMP-community-client.md)
- [一对一私信](IMP-messaging-client.md)
- [Assistant](IMP-assistant-client.md)
- [展示系统](IMP-presentation-client.md)

本页不再声明当前代码或条款所有权；`evidence` 仅保留回挂此稳定 ID 的 superseded 历史记录。
