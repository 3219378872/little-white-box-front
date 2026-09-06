# 实现层

实现层把当前设计逐条映射到源码和证据。每条 approved requirement 在所有非 retired IMP 中必须恰好
出现一行权威矩阵；`aligned` 需要当前 `active/passed` 证据，`unknown` 或 `diverged` 必须写明确 gap。
提交观察只属于 EVD，不进入 IMP frontmatter。

当前实现：

- [IMP-client-platform](IMP-client-platform.md)：应用壳、身份、传输、SDK 与通用状态。
- [IMP-community-client](IMP-community-client.md)：发现、内容、互动与行为队列。
- [IMP-messaging-client](IMP-messaging-client.md)：一对一私信。
- [IMP-assistant-client](IMP-assistant-client.md)：Assistant、Memory、Watch 与研究交互。
- [IMP-presentation-client](IMP-presentation-client.md)：主题、共享控件与全页面展示。

历史稳定 ID 指针：

- [IMP-flutter-client](IMP-flutter-client.md)
- [IMP-forui-ui](IMP-forui-ui.md)
- [IMP-heybox-presentation](IMP-heybox-presentation.md)
