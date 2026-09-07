# README 界面截图

这些图片用于前端与根仓 README 的界面展示，复用 2026-09-06 上一轮浏览器记录，原图未经裁剪、重绘
或内容替换。本次仅将选定原图持久化到仓库，没有重新拍摄，也不升级正式知识中的验收状态。

| 图片 | 来源与主题 | 原始文件 | 尺寸 |
| --- | --- | --- | --- |
| [桌面内容流](mock-desktop-feed.png) | Mock，亮色 | `web-navigation-final/desktop-light-feed.png` | 1440 × 1000 |
| [移动端搜索](mock-mobile-search-dark.png) | Mock，暗色 | `web-navigation-final/mobile-dark-search-results.png` | 390 × 844 |
| [Agent 澄清](mock-mobile-clarification.png) | Mock，亮色 | `assistant-browser-final/mobile-light-questions.png` | 390 × 844 |
| [帖子详情](real-mobile-post.png) | 真实本地联调，亮色，开发测试数据 | `real-browser/mobile-light-post.png` | 390 × 844 |

原始归档目录为 `/tmp/xbh-heybox-migration-20260906.4EhL6I`，上述路径均相对该目录。
该临时目录可能被清理；README 只引用本目录已入库的图片，不依赖 `/tmp` 存续。

Mock 的观察提交为 `9b3fba2004ad39275963ac512df3ebe6caa65c2a`，采集环境与边界见
[当轮视觉记录](../../knowledge/evidence/EVD-heybox-presentation-2026-09-06.md)。真实联调截图来自当轮
`:3002` 本地栈，独立运行记录见
[根仓现场笔记](https://github.com/3219378872/little-white-box/blob/f320a8515b82d00549f5d1c5584187234a3c4880/NOTES.md)。
真实联调和 Mock 是两类来源，不从 Mock 截图推断真实接口或模型结果，也不将历史截图当成当前 HEAD
的浏览器、设备或生产验收证明。

前端 README 使用同仓相对路径；根仓使用固定前端提交的 raw 图片地址复用同一份资产。更新截图时
应同步来源、日期和根仓引用，不把旧图静默解释成新版本画面。
