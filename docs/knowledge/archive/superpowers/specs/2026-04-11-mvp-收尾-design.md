# MVP 收尾 · 设计文档

| 字段 | 值 |
|---|---|
| 日期 | 2026-04-11 |
| 类型 | 实现设计 |
| 状态 | 待审阅 |
| 相关文档 | [后端接口规格](../../backend/2026-04-11-后端待补接口.md)、[实现计划](../plans/2026-04-11-mvp-收尾-plan.md)（待生成） |

## 1. 背景与目标

小白盒内容社区前端（`xiaobaihe_app/`）已搭好完整骨架，但多处存在"未完成尾巴"：评论分页加载未激活、个人主页帖子列表仅占位、图片上传协议畸形、冷启动未恢复 userId。本次迭代目标是**修复这四项关键缺口，让 Mock 模式下主线功能端到端可走通**，为后续真实后端联调铺平道路。

本次**不做**：新增功能、性能优化、测试覆盖全面补齐、代码风格全项整改。

## 2. 决策记录

| # | 决策点 | 决定 | 理由 |
|---|---|---|---|
| D1 | 范围 | 只修 #1 评论分页、#2 用户帖子/收藏列表、#4 图片上传、#6 userId 恢复 | 用户选 A "最小可跑 MVP" 范围 |
| D2 | #2 的 SDK 阻塞处理 | X3：前端写到新契约上 + Mock 对齐 + 输出后端接口规格文档给后端同学实现 | 用户同时负责后端；前后端联调天然可控 |
| D3 | #6 userId 持久化 | Y2：解 JWT payload（`userId` 字段，用户保证有） | 无需后端改动、无需新增 KV 存储、零依赖 |
| D4 | #4 图片上传协议 | Z2：前端改 multipart 上传，绕过 SDK `uploadImage` 的 JSON 字节数组缺陷；并行上传、单张失败整单失败（事务化）、不前端压缩 | 标准协议 + 事务语义明确；压缩是后端责任 |
| D5 | 文档形态 | D1+L2：规格/计划/后端接口三份 + 实施过程追加到 plan 末尾 | Superpowers 默认做法，便于回溯 |
| D6 | `isFollowing` 初始状态 | 本次**不实现**，登记为已知缺口 | 依赖 `GetUserResp` 返回 `isFollowing` 字段；范围外 |
| D7 | 收藏列表可见性 | 用户级开关：数据库列名 `favorites_visibility`，JSON 字段名 `favoritesVisible`（bool），默认公开；本次只实现读侧尊重，写侧 UI 留到下次 iteration | 默认公开符合内容社区预期；写侧 UI 不挤占 MVP 收尾 scope |

## 3. 架构总览

保持现有五层分层不变（UI → StateNotifier/FutureProvider → Repository → `apiCall<T>` → SDK → 后端）。本次改动集中在 UI、Application、Data、Core 四层，**不修改 SDK 代码生成文件**。

### 3.1 文件改动清单

```
xiaobaihe_app/lib/
├── core/
│   ├── api/api_adapter.dart                      [修改] 新增 apiPostMultipart()
│   └── auth/jwt_decoder.dart                     [新增] 纯 Dart JWT payload 解码
├── features/
│   ├── auth/application/auth_notifier.dart       [修改] _init 使用 JWT 恢复 userId
│   ├── feed/presentation/widgets/post_card.dart  [不动] 被 UserPostList 复用
│   ├── post/
│   │   ├── data/post_repository.dart             [修改] 新增 uploadImageMultipart
│   │   └── presentation/
│   │       ├── post_detail_page.dart             [修改] 激活评论分页加载
│   │       └── post_editor_page.dart             [修改] 并行上传 + 事务化
│   └── profile/
│       ├── application/user_posts_notifier.dart  [新增] StateNotifier + Key + State
│       ├── data/user_repository.dart             [修改] 新增 fetchUserPosts/fetchUserFavorites
│       └── presentation/
│           ├── profile_page.dart                 [修改] 接入 UserPostList
│           └── widgets/user_post_list.dart       [新增] 分页帖子列表组件
├── mock/
│   ├── mock_data.dart                            [修改] 加 favoriteRelations；假 JWT 工具
│   └── mock_http.dart                            [修改] 新增 3 条路由 + multipart 识别 + 假 JWT 返回
└── sdk/                                          [完全不动] 代码生成产物
```

**总计**：3 个新文件，9 个修改文件。

### 3.2 不可变约束

- **不修改 `sdk/` 下任何文件**：它们是后端 go-zero `.api` 定义的代码生成产物，手改会被下次生成覆盖
- **Mock 与真实接口共用同一前端代码路径**：Mock 只通过拦截 HTTP 生效，前端不能出现 `if isMockMode` 之类的分支
- **新增代码不引入新的 pub 依赖**：`jwt_decoder` 用 Dart 标准库；multipart 用已在项目里的 `http` package

## 4. 组件设计

### 4.1 #1 评论分页加载

**问题**：`post_detail_page.dart:37` 的 `_hasMoreComments` 被赋值但无消费者。

**方案**：在 `_PostDetailPageState` 挂 `ScrollController`，触底时触发下一页加载。

**关键改动点**：
- 新增 `ScrollController _scrollCtrl` + `_onScroll()` 监听，距离底部 300px 触发
- `_loadComments()` 已有分页逻辑，无需大改
- **排序切换时补齐状态重置**：目前只重置 `_commentPage=1`，还要重置 `_hasMoreComments=true` 和 `_comments=[]`，否则上一轮的"到底"状态会卡死新一轮
- 列表末尾追加条件 footer：`hasMore==false` 且列表非空时显示"没有更多了"
- 删除 `unused_import '../../../core/api/api_adapter.dart'`

**加载更多失败处理**：`SnackBar('加载更多评论失败，点此重试')`，保留已加载的评论，不重置 `_commentPage`，允许手动重试。

### 4.2 #2 用户帖子/收藏列表

**问题**：`profile_page.dart` 的 Tab 使用 `_PostListPlaceholder` 硬编码空态；SDK 无按用户过滤的接口。

**方案**：
1. 前端写到新契约上（见后端接口规格文档的接口 1、接口 2）
2. 新建 `UserPostsNotifier` 管理列表状态（分页、下拉刷新、错误）
3. 新建 `UserPostList` 组件复用在三个入口：自己的帖子、自己的收藏、他人的帖子
4. `profile_page.dart` 删除 `_PostListPlaceholder`，接入 `UserPostList`

**`UserPostsKey`**：`(userId, type)` 二元组，`type ∈ {posts, favorites}`。正确实现 `==` 和 `hashCode` 供 `StateNotifierProvider.family` 缓存。

**`UserPostsState`**：
```
items: List<PostItem>
page: int
hasMore: bool
isLoading: bool      // 加载更多中
isRefreshing: bool   // 下拉刷新中
error: Object?       // 首次加载失败时展示 ErrorView
```

**`UserPostsNotifier` 方法**：
- `loadFirstPage()`：page=1 覆盖
- `loadNextPage()`：page++ append，`hasMore==false` 时直接 return
- `refresh()`：同 loadFirstPage 但标记 `isRefreshing=true`，失败时**保留旧数据**不清空

**`UserPostList` 组件**：
- 消费 `userPostsProvider(UserPostsKey)`
- `RefreshIndicator` 包装
- `ScrollController` 触底加载
- 每项复用现有 `PostCard` 组件
- 空态、错误态、加载态独立处理

**`_ProfileContent` 改动**：
- 自己的主页：TabBarView(我的帖子 / 我的收藏) → 每个 Tab 一个 `UserPostList`
- 他人主页：根据 `targetUser.favoritesVisible`（新字段，`bool`）决定是否显示收藏 Tab
  - `favoritesVisible == true` → TabBar 显示"帖子 / 收藏"两个 Tab（登录与否都这么显示，后端已通过 `favoritesVisible` 把是否可见告诉前端了）
  - `favoritesVisible == false` → 只显示帖子列表，**无 TabBar**（UI 更干净，不是"已设私密"空态）
- 删除 `_PostListPlaceholder` 以及两个 unused import

**字段命名约定**：后端数据库列名 `favorites_visibility`（数据库风格），对外 JSON 字段名 `favoritesVisible`（bool，true = 公开）。前端只看到 `favoritesVisible`。

**权限兜底**：即便前端 UI 层已经根据 `favoritesVisible` 隐藏了 Tab，Repository 层收到 403 也要优雅降级（显示 ErrorView 提示"无权查看"），作为防御性实现。正常路径下前端不会撞到 403，因为 UI 已按 `favoritesVisible` 裁剪过入口。

### 4.3 #4 图片上传 multipart

**问题**：当前 `_uploadLocalImages()` 用 JSON 字节数组传输（一张 2MB 图变 ~10MB JSON），且串行上传、无重试、无事务语义。

**方案**：绕过 SDK `uploadImage`，在 Repository 层用 multipart 协议。

**`core/api/api_adapter.dart` 新增函数**：
```dart
Future<T> apiPostMultipart<T>({
  required String path,
  required String fieldName,
  required String filename,
  required List<int> bytes,
  Map<String, String>? extraFields,
  required T Function(Map<String, dynamic>) decodeData,
})
```
实现要点：
- 走与 `apiPost` 相同的 baseUrl + Authorization 头处理
- **不手动设 Content-Type**（`MultipartRequest` 会自动带 boundary）
- 响应格式仍然是后端统一的 `{code, desc, data}`
- 超时 60 秒/张（multipart 大文件留余量）
- header 组装逻辑如果现状是 `apiPost` 内联的，先小重构抽成 `_buildHeaders(includeJson: bool)` 再调用

**`PostRepository.uploadImageMultipart`**：
```dart
Future<String> uploadImageMultipart({
  required List<int> bytes,
  required String filename,
}) => apiPostMultipart<String>(
  path: '/api/v1/media/image',
  fieldName: 'file',
  filename: filename,
  bytes: bytes,
  decodeData: (data) => data['url'] as String,
);
```

**`post_editor_page._uploadLocalImages` 重写为并行 + 事务化**：
```dart
Future<List<String>> _uploadLocalImages() async {
  // 1. Future.wait 并行触发所有上传
  // 2. 每张图独立 try/catch，记录成功的 URL 和失败的索引
  // 3. 任一张失败 → throw UploadTransactionException(failedIndex, reason)
  // 4. 全部成功 → 返回 URL 列表
}
```

**事务化失败的 UI 语义**：
- 弹 `Dialog` 明确提示「第 N 张图片上传失败：<原因>」
- **发布被阻止**，`createNewPost` 不调用
- **草稿保留**：`_titleCtrl / _contentCtrl / _tags / _localImages` 全部原样保留
- 已成功上传的图片 URL **不写回** `_networkImages`，重试时所有图都重新上传（真正事务语义）
- `_isLoading=false`，按钮恢复可点

**并发上限**：一次最多 9 张图（`image_picker_grid` 已限制，无需额外加）。

### 4.4 #6 userId 恢复

**问题**：`auth_notifier._init` 只恢复 token，不恢复 userId，已登录用户打开 /profile 被当未登录。

**方案**：解析 `accessToken` 的 JWT payload 提取 `userId`。

**`core/auth/jwt_decoder.dart`（新文件，约 30 行）**：
```dart
Map<String, dynamic>? decodeJwtPayload(String token) {
  // 1. token.split('.') 必须是 3 段
  // 2. base64Url.normalize + decode + utf8.decode
  // 3. jsonDecode 必须是 Map
  // 任何异常返回 null
}

num? extractUserIdFromToken(String token) {
  final payload = decodeJwtPayload(token);
  return payload?['userId'];
}
```

**`auth_notifier._init` 修改**：
```dart
Future<void> _init() async {
  final tokens = await getTokens();
  if (tokens != null && tokens.accessToken.isNotEmpty) {
    final userId = extractUserIdFromToken(tokens.accessToken);
    if (userId == null || userId <= 0) {
      // token 异常：当作未登录，清掉
      await removeTokens();
      state = const AuthState(isLoading: false);
    } else {
      state = AuthState(
        isAuthenticated: true,
        userId: userId,
        token: tokens.accessToken,
        isLoading: false,
      );
    }
  } else {
    state = const AuthState(isLoading: false);
  }
  _changeNotifier.notify();
}
```

**Mock 侧配合**：`mock_http.dart` 的 login/register 返回假 JWT：
```dart
String _buildFakeJwt(num userId) {
  final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
  final payload = base64Url.encode(utf8.encode('{"userId":$userId}'));
  return '$header.$payload.fake-sig';
}
```

## 5. 数据流示意

### 5.1 启动恢复流程

```
App 启动
  └─ ProviderScope 初始化
     └─ AuthNotifier._init()
        ├─ getTokens() 读 SharedPreferences
        ├─ 无 token → AuthState(unauth)
        ├─ 有 token → extractUserIdFromToken()
        │  ├─ 解析失败 → removeTokens() → AuthState(unauth)
        │  └─ 成功 → AuthState(auth, userId)
        └─ _changeNotifier.notify() → GoRouter 重新评估路由
```

### 5.2 用户帖子列表加载流程

```
进入 /profile → ProfilePage build
  └─ targetUserId = userId ?? auth.userId
  └─ _ProfileContent build
     └─ UserPostList(UserPostsKey(userId, posts))
        └─ ref.watch(userPostsProvider(key))
           └─ UserPostsNotifier(key) 构造时自动 loadFirstPage()
              └─ UserRepository.fetchUserPosts(userId, page=1, pageSize=20)
                 └─ apiGet('/api/v1/users/$userId/posts?page=1&...')
                    └─ [真实] 后端返回 GetPostListResp
                        [Mock] mock_http.dart 拦截 → 按 authorId 过滤 mockPosts
              └─ setState(items, hasMore, page)
        └─ 渲染 ListView + RefreshIndicator
        └─ 触底 → notifier.loadNextPage()
```

### 5.3 图片上传事务化流程

```
用户点"发布"
  └─ _publish()
     └─ _uploadLocalImages() 并行触发 N 个 uploadImageMultipart
        ├─ 全成功 → 返回 [url1, url2, ...]
        │   └─ createNewPost(images: [...]) → 成功 → 跳转帖子详情
        └─ 任一失败 → 抛 UploadTransactionException(failedIndex, reason)
            └─ catch → Dialog('第 N 张图片上传失败：...')
               └─ 不调 createNewPost
               └─ 草稿状态原样保留，用户可重试
```

## 6. 错误处理策略

| 场景 | 表现 | 状态 |
|---|---|---|
| 评论首页加载失败 | `ErrorView` 替代评论区 | `_comments.isEmpty` 分支 |
| 评论加载更多失败 | `SnackBar` + 保留已加载 | 不重置 page，允许重试 |
| 用户帖子首次加载失败 | `ErrorView` 全屏 | `state.error != null` |
| 用户帖子加载更多失败 | 列表底部 footer | `isLoading=false, hasMore=true, error!=null` |
| 下拉刷新失败 | 顶部 `SnackBar` + 保留旧数据 | `isRefreshing=false` |
| 图片上传任一失败 | `Dialog` + 草稿保留 | 事务化，全部丢弃重来 |
| JWT 解码失败 / userId=0 | 静默降级为未登录 | `removeTokens + AuthState(unauth)` |

**共通原则**：
- Repository 层不二次封装 `ApiException`，直接抛给上层
- UI 层捕获时展示 `e.toString()`
- 不引入全局 `ErrorWidget.builder`，保持 per-screen 错误风格

## 7. 测试策略

**必写（P0）**：
1. `core/auth/jwt_decoder_test.dart` —— 纯逻辑，关系到所有已登录用户的冷启动正确性
   - 正常 token、两段/四段式、payload 不是 JSON、payload 无 userId、base64url padding 边界
2. `features/profile/application/user_posts_notifier_test.dart` —— 状态机正确性
   - 首次加载成功、loadNextPage append、hasMore 判断、refresh 重置、refresh 失败保留旧数据

**可写（P1）**：
3. `post_editor_page` 上传事务 widget 测试：fake Repository 一张成功一张失败 → 验证 `createNewPost` 未触发、草稿保留

**不写（P2）**：
- Mock HTTP 层本身的测试
- SDK 生成代码
- 滚动加载集成测试
- UI 快照测试

**手动验证矩阵**（Mock 模式必跑，真实后端等接口就绪后跑）：

| 场景 | Mock | 真实 |
|---|---|---|
| 冷启动已登录 → 直接进 /profile 不跳登录 | ✓ | ✓ |
| 冷启动未登录 → 进 /profile 跳登录 | ✓ | ✓ |
| Token 坏掉（手动改 SharedPreferences）→ 降级未登录 | ✓ | — |
| 帖子详情滑到评论底部 → 自动加载下一页 | ✓ | ✓ |
| 切换评论排序 → 分页状态完全重置 | ✓ | ✓ |
| 自己主页看到"我的帖子" + "我的收藏" 两 tab | ✓ | ✓ |
| 他人主页（对方 `favoritesVisible==true`）看到帖子 + 收藏两个 Tab | ✓ | ✓ |
| 他人主页（对方 `favoritesVisible==false`）只看到帖子列表、无 TabBar | ✓ | ✓ |
| 发帖选 3 张图 → 全成功 → 发布成功 | ✓ | ✓ |
| 发帖选 3 张图 → 第 2 张失败 → 整单失败、草稿保留 | ✓ | —（Mock 覆盖足矣） |

## 8. 实施顺序

详细 step-by-step 由 `writing-plans` 技能在下一环节生成。此处只记录阶段划分与依赖：

| Phase | 内容 | 依赖 |
|---|---|---|
| 0 | 审计 mock_http / mock_data / api_adapter 当前状态 | 无 |
| 1 | #6 userId 恢复（jwt_decoder + auth_notifier + Mock 假 JWT） | 无 |
| 2 | #1 评论分页加载 | 无 |
| 3 | #4 图片上传 multipart（适配层 + Repository + UI + Mock） | 无 |
| 4 | #2 用户帖子/收藏列表（Notifier + Repo + Widget + profile_page + Mock） | Phase 1 |
| 5 | 验证收尾：analyze + 单测 + 手动矩阵 + 实施日志追加 | 1-4 |

Phase 1-3 彼此独立可并行或顺序随意。**Mock 模式完整跑通即算本次交付完成**，真实后端联调作为第二次收尾，等后端 3 个新接口实现后进行。

## 9. 风险登记

| # | 风险 | 等级 | 应对 |
|---|---|---|---|
| R1 | Mock 对 comment list 的 query 参数支持度未知 | 中 | Phase 0 审计；如缺失则 Phase 2 补 |
| R2 | `api_adapter.dart` header 组装未抽函数 | 低 | Phase 3 顺手重构，或重复代码隔离 |
| R3 | JWT 假 token 的 base64url padding 边界 | 低 | `base64Url.normalize` 处理；单测覆盖 |
| R4 | `http` package 版本兼容性 | 低 | 检查 `pubspec.yaml`；必要时升级 |
| R5 | 真实后端 3 个新接口未实现 → 只能 Mock 验证 | 高（计划内） | X3 路线的已知代价，plan 显式登记阻塞项 |
| R6 | 诱惑前端做图片压缩 | 低 | 明文规定压缩是后端责任，不碰 |
| R7 | `isFollowing` 记账项被遗忘 | 低 | 本文档与 plan 末尾都登记 |
| R8 | `_hasMoreComments` 重置条件漏（首次/切排序/错误重试） | 中 | 三条路径专门手工验证 |

## 10. 已知缺口（本次不做，留给下次 iteration）

1. **`isFollowing` 真实状态**：依赖 `GetUserResp` 新增 `isFollowing` 字段。本次 profile_page 的 `_isFollowing` 仍硬编码 false。
2. **收藏可见性的写侧 UI**：`edit_profile_page` 缺少"收藏可见性"开关。后端加了字段和默认公开后，下次迭代加 UI。
3. **`/api/v1/me` 接口**：冷启动一次拿到完整用户信息（nickname/avatar）。本次用 JWT 只能拿 userId。
4. **RefreshToken 机制**：SDK 缺陷 #2，当前 `refreshToken` 字段置空。Token 过期后只能重新登录。优雅降级由 `_init` 的 `removeTokens` 分支兜底。
5. **SDK 生成文件中的 `avoid_print` / `unnecessary_brace_in_string_interps`**：会被下次生成器覆盖，不改。
6. **测试覆盖**：除 P0 两项外全部留白。

## 11. 变更日志

- 2026-04-11 · v1 · 初稿，待用户审阅
