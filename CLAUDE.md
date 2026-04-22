# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

本仓库现在是 **app-centric** 结构：

1. **仓库根目录** - Flutter 应用本体（直接运行 `flutter` 命令）
2. **`vendor/sdk_source/`** - 原始 Dart API 客户端 SDK 生成源
3. **`lib/sdk/`** - 集成到 Flutter 应用中的 SDK 副本

技术栈：Flutter + Riverpod + GoRouter + Material 3，目前以 Android 为主要目标平台，同时保留 Flutter 默认多平台目录。

## 常用命令

```bash
flutter pub get          # 安装依赖
flutter analyze          # 静态分析（0 error 为通过，info 级别来自 SDK 可忽略）
flutter test             # 运行测试
flutter run              # 运行应用
flutter build apk        # 构建 APK
```

## 目录结构

```text
.
├── android/ ios/ web/ windows/ linux/ macos/
├── lib/
│   ├── core/            # 核心基础设施
│   ├── features/        # 业务模块（feature-first）
│   ├── mock/            # 本地 mock 运行与数据
│   └── sdk/             # App 实际引用的 SDK 副本
├── test/
├── docs/                # 设计、计划、协作文档
├── tools/               # 维护脚本
└── vendor/
    └── sdk_source/      # 原始生成 SDK 源
```

## 架构

### 分层总览

```text
UI (Pages/Widgets)
    ↓ watch/read
StateNotifier / FutureProvider (application/)
    ↓ read
Repository (data/)
    ↓ 调用
apiCall<T> 适配层 (core/api/api_adapter.dart)
    ↓ 桥接 ok/fail/eventually → Future<T>
SDK (lib/sdk/api/gateway.dart → lib/sdk/api/api.dart → 后端)
```

每个 feature 内部结构：`data/` (Repository) → `application/` (StateNotifier) → `presentation/` (Pages + Widgets)

## SDK 关键约定

### 代码生成文件

`vendor/sdk_source/api/gateway.dart` 和 `vendor/sdk_source/data/gateway.dart` 是原始生成产物。

`lib/sdk/api/gateway.dart` 和 `lib/sdk/data/gateway.dart` 是应用集成副本。

如果需要同步 SDK，先以 `vendor/sdk_source/` 为源，再同步到 `lib/sdk/`，不要把业务 workaround 直接堆进生成源里。

### SDK 回调模式 → Future 适配

应用层通过 `apiCall<T>()` 将 SDK 的 `ok`/`fail`/`eventually` 回调模式转换为 `Future<T>`：

```dart
final resp = await apiCall<LoginResp>(
  (ok, fail, eventually) => login(req, ok: ok, fail: fail, eventually: eventually),
);
```

### 已知的 SDK 缺陷（必须在 Repository 层绕过）

1. **`getPostList()` 和 `getCommentList()` 不传分页/排序参数**
   Repository 层绕过 SDK 函数，直接调用 `apiGet` 拼接 query string。

2. **`LoginResp` 与 `Tokens` 模型不匹配**
   登录后用 token 字符串构造 `Tokens` 对象，refresh 字段置空。

3. **图片上传**
   `UploadImageReq` 当前通过 JSON 发送字节数组，后续如需修复应在适配层或同步流程中处理。

## 路由

GoRouter 配置在 `lib/core/router/app_router.dart`。认证守卫通过 `AuthChangeNotifier` + `refreshListenable` 实现。

公开路由：`/feed`、`/post/:postId`、`/user/:userId`
需认证路由：`/post/new`、`/post/edit/:postId`、`/profile`、`/profile/edit`

## 状态管理模式

- 认证状态：`StateNotifierProvider<AuthNotifier, AuthState>` + `AuthChangeNotifier`
- Feed 列表：`StateNotifierProvider.family<FeedNotifier, FeedState, int>`
- 帖子详情：`FutureProvider.family<GetPostResp, int>`
- 点赞/收藏：乐观更新，失败回滚

## 添加新接口的步骤

1. 先更新 `vendor/sdk_source/` 中的生成模型和接口定义
2. 再把需要的 SDK 变更同步到 `lib/sdk/`
3. 在对应 feature 的 `data/` 目录创建或更新 Repository，用 `apiCall<T>()` 包装
4. 如果是 GET 请求需要 query 参数，直接调用 `apiGet` 拼接 URL
