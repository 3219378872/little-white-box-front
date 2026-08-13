# App-Centric Repo Organization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize the project so the Flutter app lives at the repository root, generated SDK source lives under `vendor/sdk_source`, and project docs live inside the same app-centric repo.

**Architecture:** Execute the migration in an isolated staging copy of the current workspace because the active `master` worktree is dirty and the git boundary currently lives under `xiaobaihe_app/.git`. In the staging copy, move the git root to the workspace root, merge the existing app repo with the workspace-level docs and SDK source, update repo documentation, then verify Flutter commands from the new root before promoting the staged repo into the canonical workspace path.

**Tech Stack:** PowerShell, Git, Flutter CLI

---

## Working Directory Assumptions

- Current workspace root: `D:\Learning\projects\work projects\little-white-box-front`
- Current git directory: `D:\Learning\projects\work projects\little-white-box-front\xiaobaihe_app\.git`
- Staging workspace for the migration: `D:\Learning\projects\work projects\little-white-box-front-reorg`
- Execute PowerShell commands from `D:\Learning\projects\work projects` unless a step says otherwise

## File Map

**Filesystem moves in the staging workspace**

- Move `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\.git` -> `D:\Learning\projects\work projects\little-white-box-front-reorg\.git`
- Move selected children of `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\` -> `D:\Learning\projects\work projects\little-white-box-front-reorg\`
- Move `D:\Learning\projects\work projects\little-white-box-front-reorg\dart` -> `D:\Learning\projects\work projects\little-white-box-front-reorg\vendor\sdk_source`
- Merge `D:\Learning\projects\work projects\little-white-box-front-reorg\_workspace_docs\**` -> `D:\Learning\projects\work projects\little-white-box-front-reorg\docs\**`
- Move `D:\Learning\projects\work projects\little-white-box-front-reorg\doc\2026-04-22-网关错误响应格式说明.md` -> `D:\Learning\projects\work projects\little-white-box-front-reorg\docs\backend\2026-04-22-网关错误响应格式说明.md`

**Tracked files to create or modify in the staging repo**

- Modify: `.gitignore`
- Modify: `README.md`
- Create: `CLAUDE.md`
- Create: `tools/README.md`
- Create by move/import: `vendor/sdk_source/**`
- Create by merge/import: `docs/backend/2026-04-11-后端待补接口.md`
- Create by move/import: `docs/backend/2026-04-22-网关错误响应格式说明.md`
- Create by merge/import: `docs/superpowers/plans/2026-04-11-mvp-收尾-plan.md`
- Create by merge/import: `docs/superpowers/specs/2026-04-11-mvp-收尾-design.md`

### Task 1: Create an isolated staging workspace and move the git root

**Files:**
- Modify (filesystem only): `D:\Learning\projects\work projects\little-white-box-front-reorg\`
- Move: `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\.git`
- Move: `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\android`
- Move: `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\ios`
- Move: `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\web`
- Move: `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\windows`
- Move: `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\linux`
- Move: `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\macos`
- Move: `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\lib`
- Move: `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\test`
- Move: `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\pubspec.yaml`
- Move: `D:\Learning\projects\work projects\little-white-box-front-reorg\xiaobaihe_app\analysis_options.yaml`
- Test: `git status --short`, `git rev-parse --show-toplevel`

- [ ] **Step 1: Copy the current workspace into a sibling staging directory**

```powershell
Set-Location 'D:\Learning\projects\work projects'
if (Test-Path '.\little-white-box-front-reorg') {
  throw 'Delete or rename little-white-box-front-reorg before starting this migration.'
}
Copy-Item -Recurse -Force '.\little-white-box-front' '.\little-white-box-front-reorg'
```

- [ ] **Step 2: Rename the workspace-level docs and instruction file in the staging copy to avoid merge conflicts**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
Rename-Item '.\docs' '_workspace_docs'
Rename-Item '.\CLAUDE.md' '_workspace_CLAUDE.md'
```

- [ ] **Step 3: Move the git directory to the staging workspace root**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
Move-Item '.\xiaobaihe_app\.git' '.\.git'
```

- [ ] **Step 4: Move the Flutter app contents to the staging workspace root, excluding local build metadata**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
$exclude = @('.git', '.idea', '.dart_tool', 'build')
Get-ChildItem '.\xiaobaihe_app' -Force |
  Where-Object { $exclude -notcontains $_.Name } |
  Move-Item -Destination '.'
Remove-Item -Recurse -Force '.\xiaobaihe_app'
```

- [ ] **Step 5: Create the migration branch in the staging repo**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
git switch -c chore/app-centric-repo-root
```

- [ ] **Step 6: Verify that git now treats the staging workspace root as the repository root**

Run:

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
git rev-parse --show-toplevel
git status --short
```

Expected:

- `git rev-parse --show-toplevel` prints `D:/Learning/projects/work projects/little-white-box-front-reorg`
- `git status --short` shows untracked root-level workspace assets such as `_workspace_docs/`, `_workspace_CLAUDE.md`, `dart/`, `doc/`, and possibly local-only directories, but does **not** show tracked app files as deleted

### Task 2: Import workspace assets and normalize the new root layout

**Files:**
- Create by move: `vendor/sdk_source/**`
- Create by merge: `docs/backend/2026-04-11-后端待补接口.md`
- Create by move: `docs/backend/2026-04-22-网关错误响应格式说明.md`
- Create by merge: `docs/superpowers/plans/2026-04-11-mvp-收尾-plan.md`
- Create by merge: `docs/superpowers/specs/2026-04-11-mvp-收尾-design.md`
- Create: `tools/README.md`
- Modify: `.gitignore`
- Test: `Test-Path`, `git status --short`

- [ ] **Step 1: Create the top-level support directories**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
New-Item -ItemType Directory -Force '.\vendor' | Out-Null
New-Item -ItemType Directory -Force '.\tools' | Out-Null
New-Item -ItemType Directory -Force '.\docs\backend' | Out-Null
New-Item -ItemType Directory -Force '.\docs\superpowers\plans' | Out-Null
New-Item -ItemType Directory -Force '.\docs\superpowers\specs' | Out-Null
```

- [ ] **Step 2: Move the generated SDK source into `vendor/sdk_source`**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
Move-Item '.\dart' '.\vendor\sdk_source'
```

- [ ] **Step 3: Merge the existing workspace docs into the repo docs tree**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
Copy-Item -Recurse -Force '.\_workspace_docs\backend\*' '.\docs\backend\'
Copy-Item -Recurse -Force '.\_workspace_docs\superpowers\plans\*' '.\docs\superpowers\plans\'
Copy-Item -Recurse -Force '.\_workspace_docs\superpowers\specs\*' '.\docs\superpowers\specs\'
Remove-Item -Recurse -Force '.\_workspace_docs'
```

- [ ] **Step 4: Move the standalone gateway note into `docs/backend` and remove the old single-file docs directory**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
Move-Item '.\doc\2026-04-22-网关错误响应格式说明.md' '.\docs\backend\2026-04-22-网关错误响应格式说明.md'
Remove-Item -Recurse -Force '.\doc'
```

- [ ] **Step 5: Create `tools/README.md` so the `tools/` directory has a tracked purpose**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
@'
# Tools

This directory stores repeatable repository-maintenance scripts for the app-centric repo layout.

Current policy:

- Store future SDK sync automation here
- Store future repo-layout validation scripts here
- Do not leave one-off migration scratch files at the repository root
'@ | Set-Content '.\tools\README.md'
```

- [ ] **Step 6: Append repo-local ignore rules for local AI tooling and scratch notes**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
@'

# Repo-local tooling and scratch notes
.claude/
examination/
'@ | Add-Content '.\.gitignore'
```

- [ ] **Step 7: Verify the new root layout before committing**

Run:

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
Test-Path '.\vendor\sdk_source\api\gateway.dart'
Test-Path '.\lib\sdk\api\gateway.dart'
Test-Path '.\docs\backend\2026-04-11-后端待补接口.md'
Test-Path '.\docs\backend\2026-04-22-网关错误响应格式说明.md'
Test-Path '.\tools\README.md'
git status --short
```

Expected:

- All `Test-Path` commands return `True`
- `git status --short` shows additions for `vendor/sdk_source/**`, `docs/backend/**`, `docs/superpowers/**`, `tools/README.md`, and `.gitignore`
- `git status --short` does **not** show `dart/` or `doc/` at the repo root anymore

- [ ] **Step 8: Commit the imported SDK source and merged docs**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
git add .gitignore docs vendor tools
git commit -m "chore: import vendored sdk and workspace docs"
```

### Task 3: Rewrite root documentation for the app-centric layout

**Files:**
- Modify: `README.md`
- Create: `CLAUDE.md`
- Remove after rewrite: `_workspace_CLAUDE.md`
- Test: `git diff -- README.md CLAUDE.md`, `rg "xiaobaihe_app|dart/" README.md CLAUDE.md`

- [ ] **Step 1: Replace `README.md` with app-centric repository documentation**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
@'
# little-white-box-front

Flutter front-end for Xiaobaihe.

This repository is app-centric:

- The Flutter app lives at the repository root
- Generated SDK source lives under `vendor/sdk_source/`
- The app-consumed SDK copy lives under `lib/sdk/`
- Project docs live under `docs/`

## Repository Layout

```text
.
├── android/
├── ios/
├── web/
├── windows/
├── linux/
├── macos/
├── lib/
│   ├── core/
│   ├── features/
│   ├── mock/
│   └── sdk/
├── test/
├── docs/
├── tools/
└── vendor/
    └── sdk_source/
```

## Common Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk
```

## SDK Workflow

1. Treat `vendor/sdk_source/` as the source of truth for generated SDK code.
2. Treat `lib/sdk/` as the app integration copy.
3. Keep app-specific workarounds in `lib/core/api/` or feature repositories instead of modifying generated SDK files unless there is no practical alternative.

## Documentation

- Design specs and plans live under `docs/superpowers/`
- Backend coordination notes live under `docs/backend/`
'@ | Set-Content '.\README.md'
```

- [ ] **Step 2: Replace the root `CLAUDE.md` with repository instructions that match the new layout**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
@'
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

本仓库现在是 **app-centric** 结构：

1. **仓库根目录** — Flutter 应用本体（直接运行 `flutter` 命令）
2. **`vendor/sdk_source/`** — 原始 Dart API 客户端 SDK 生成源
3. **`lib/sdk/`** — 集成到 Flutter 应用中的 SDK 副本

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
'@ | Set-Content '.\CLAUDE.md'
```

- [ ] **Step 3: Remove the temporary `_workspace_CLAUDE.md` file**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
Remove-Item '.\_workspace_CLAUDE.md'
```

- [ ] **Step 4: Verify that the rewritten docs no longer reference the old nested app root or the old SDK source path**

Run:

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
git diff -- README.md CLAUDE.md
rg 'cd xiaobaihe_app|xiaobaihe_app/|`dart/`' README.md CLAUDE.md
```

Expected:

- `git diff -- README.md CLAUDE.md` shows only the intended rewrites
- `rg` returns no matches

- [ ] **Step 5: Commit the documentation rewrite**

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
git add README.md CLAUDE.md
git commit -m "docs: describe app-centric repo layout"
```

### Task 4: Verify the Flutter project from the new repository root

**Files:**
- Test only: `pubspec.yaml`, `analysis_options.yaml`, `lib/**`, `test/**`
- Test: `flutter pub get`, `flutter analyze`, `flutter test`, `git status --short`

- [ ] **Step 1: Confirm the repo status before running Flutter commands**

Run:

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
git status --short
```

Expected:

- `git status --short` is empty before verification, or only shows ignored local tooling directories outside version control

- [ ] **Step 2: Install dependencies from the new repo root**

Run:

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
flutter pub get
```

Expected:

- `flutter pub get` completes successfully from the repo root without requiring `cd xiaobaihe_app`

- [ ] **Step 3: Run static analysis from the new repo root**

Run:

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
flutter analyze
```

Expected:

- Analysis finishes successfully
- If SDK-generated files emit info-level notices that were already accepted before the migration, those info-level notices may remain, but there should be no new errors caused by the repo move

- [ ] **Step 4: Run the Flutter test suite from the new repo root**

Run:

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
flutter test
```

Expected:

- All existing tests pass from the repo root

- [ ] **Step 5: Verify that the repo root is clean after verification**

Run:

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front-reorg'
git status --short
```

Expected:

- `git status --short` is empty
- If `flutter pub get` changed `pubspec.lock` unexpectedly, stop here and inspect the diff before committing anything else

### Task 5: Promote the verified staging repo into the canonical workspace path

**Files:**
- Modify (filesystem only): `D:\Learning\projects\work projects\little-white-box-front`
- Modify (filesystem only): `D:\Learning\projects\work projects\little-white-box-front-reorg`
- Preserve as backup: `D:\Learning\projects\work projects\little-white-box-front-pre-reorg`
- Test: `git rev-parse --show-toplevel`, `git status --short`

- [ ] **Step 1: Close IDEs or terminals that still hold files open in the original workspace**

```powershell
Write-Host 'Close editors, terminals, and file explorers that are still using little-white-box-front before running the rename steps.'
```

- [ ] **Step 2: Rename the original workspace to a backup path**

```powershell
Set-Location 'D:\Learning\projects\work projects'
if (Test-Path '.\little-white-box-front-pre-reorg') {
  throw 'Delete or rename little-white-box-front-pre-reorg before promoting the staged repo.'
}
Rename-Item '.\little-white-box-front' 'little-white-box-front-pre-reorg'
```

- [ ] **Step 3: Rename the verified staging repo into the canonical workspace path**

```powershell
Set-Location 'D:\Learning\projects\work projects'
Rename-Item '.\little-white-box-front-reorg' 'little-white-box-front'
```

- [ ] **Step 4: Verify that the canonical workspace path now points at the reorganized repo**

Run:

```powershell
Set-Location 'D:\Learning\projects\work projects\little-white-box-front'
git rev-parse --show-toplevel
git status --short
```

Expected:

- `git rev-parse --show-toplevel` prints `D:/Learning/projects/work projects/little-white-box-front`
- `git status --short` is empty

- [ ] **Step 5: Keep the backup workspace until the user explicitly decides to remove it**

```powershell
Write-Host 'Keep D:\Learning\projects\work projects\little-white-box-front-pre-reorg as a rollback backup until the reorganized repo has been accepted.'
```

## Self-Review

### Spec coverage

- Repository root becomes the Flutter app root: covered by Task 1 and Task 5
- Generated SDK source moves under `vendor/sdk_source/`: covered by Task 2
- Docs move under the app-centric repo root: covered by Task 2
- Directory responsibilities and root rules are documented: covered by Task 2 and Task 3
- Flutter commands run from the new root: covered by Task 4
- No `lib/` internal refactor: preserved by all tasks because no task edits `lib/**` structure

### Placeholder scan

- No placeholder markers remain
- Every file edit step includes exact content or exact commands
- Every verification step includes commands and expected results

### Type and naming consistency

- The plan consistently uses `vendor/sdk_source/` as the SDK source-of-truth path
- The plan consistently uses `lib/sdk/` as the app integration copy
- The plan consistently uses `little-white-box-front-reorg` as the staging workspace path
