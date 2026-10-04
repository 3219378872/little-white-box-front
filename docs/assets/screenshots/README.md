# README 界面截图

这些图片用于前端与根仓 README 的界面展示，2026-10-04 在前端提交
`4d8138c6eacd4fd88fda49c8748707541a6d9124` 上重新拍摄，替换 2026-09-06 的旧图。旧图早于
2026-09-26 的界面重构，也没有广告与审核界面；改造前后对比见
[界面重构证据](../../knowledge/evidence/EVD-ui-redesign-2026-09-26.md)。图片未经裁剪、重绘或内容替换。

| 图片 | 来源与主题 | 页面 | 尺寸 |
| --- | --- | --- | --- |
| [桌面内容流](mock-desktop-feed.png) | Mock，亮色 | `/feed`，含侧栏「商业」入口 | 1440 × 1000 |
| [推荐流广告](mock-mobile-feed-ad.png) | Mock，亮色 | `/feed` 下滑至第一个广告槽位 | 390 × 844 |
| [移动端搜索](mock-mobile-search-dark.png) | Mock，暗色 | `/search`，查询「手机」 | 390 × 844 |
| [Agent 澄清](mock-mobile-clarification.png) | Mock，亮色 | `/messages/assistant`，比较类提问触发结构化澄清 | 390 × 844 |
| [广告主控制台](mock-mobile-ads.png) | Mock，亮色 | `/ads` | 390 × 844 |
| [审核工作台](mock-mobile-review.png) | Mock，亮色 | `/review` | 390 × 844 |
| [回扫审核任务](mock-mobile-review-task.png) | Mock，亮色 | `/review/tasks/9006`，回扫暂停后的人审任务 | 390 × 844 |
| [帖子详情](real-mobile-post.png) | 真实本地联调，亮色，开发测试数据 | `/post/1001`，以测试账号 `admin` 登录 | 390 × 844 |

采集方式：

- Mock：`make build-web` 构建 `lib/main_mock.dart` release 包，以根仓 `deploy/dev/serve_release.py`
  本地伺服；Playwright Chromium，`device_scale_factor=1`，`locale=zh-CN`，暗色图使用
  `color_scheme=dark`。Mock 初始用户同时是广告主与审核员，数据均为仓库内演示数据。
- 真实联调：根仓 `9908d0d`（后端 `58f7d09`、前端 `4d8138c`）执行 `just up` 后的 `:3002` 同源入口，
  `/api/v1/health/ready` 为 ready；同样以 Playwright 拍摄。帖子 1001 来自后端 `eval/corpus.json`
  开发语料，不是用户数据。

真实联调和 Mock 是两类来源，不从 Mock 截图推断真实接口、模型或审核结果；这些截图只用于 README
展示，不是正式证据，也不升级任何条款的验收状态或证明浏览器、设备与生产验收。

前端 README 使用同仓相对路径；根仓使用固定前端提交的 raw 图片地址复用同一份资产。更新截图时
应同步来源、日期和根仓引用，不把旧图静默解释成新版本画面。
