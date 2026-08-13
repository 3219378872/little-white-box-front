# App-Centric Repo Organization Design

Date: 2026-04-22
Status: Approved design
Scope: Repository structure only

## Context

The current workspace mixes three concerns at the top level:

- The actual Flutter application lives under `xiaobaihe_app/`
- Generated Dart SDK source lives under `dart/`
- Project documentation lives under `docs/`

This makes the workspace read like a mixed staging area instead of an application-first repository. Day-to-day development starts from the Flutter app, but the directory structure does not reflect that.

The current git repository is rooted at `xiaobaihe_app/`, not at the workspace root. That means the desired future repository shape and the current version-control boundary are misaligned.

## Goal

Reorganize the project so the workspace root becomes the Flutter application's repository root.

After the reorganization:

- The root directory should look like a normal Flutter app root
- Generated SDK source should remain in the repository
- SDK source should no longer sit beside the app as a peer top-level project
- Multi-platform Flutter directories should remain in place
- This effort should not change feature architecture inside `lib/`

## Non-Goals

This design explicitly does not include:

- Refactoring `lib/core`, `lib/features`, `lib/mock`, or `lib/sdk`
- Splitting large presentation files such as `post_detail_page.dart`
- Converting the SDK into a separate package
- Moving the SDK to an external repository or external dependency source
- Removing `ios/`, `web/`, `windows/`, `linux/`, or `macos/`

## Recommended Approach

Use an app-centric vendor layout.

The Flutter app becomes the primary repository shape. Supporting assets remain in the repository, but they are placed in supporting directories with explicit responsibilities.

This is preferred over:

- A minimal move that still keeps generated source too visible at the root
- A package-based split, which would introduce a dependency-model change before the structure problem is solved

## Target Structure

The workspace root should become the repository root and directly contain the Flutter project structure:

- `android/`
- `ios/`
- `web/`
- `windows/`
- `linux/`
- `macos/`
- `lib/`
- `test/`
- `pubspec.yaml`
- `analysis_options.yaml`
- `README.md`

The root should also contain supporting directories:

- `docs/`
- `tools/`
- `vendor/`

Within that structure:

- `vendor/sdk_source/` stores the original generated Dart SDK source currently under `dart/`
- `lib/sdk/` remains the app-consumed integrated SDK copy
- `tools/` stores repeatable engineering scripts such as future SDK sync automation

## Directory Responsibilities

### `lib/`

Contains application runtime code only. This includes:

- `lib/core`
- `lib/features`
- `lib/mock`
- `lib/sdk`

Only code required to build or run the Flutter application should live here.

### `vendor/sdk_source/`

Contains the generated SDK source of record. This directory preserves the upstream-generated structure and is not the place for app-specific workaround logic.

### `tools/`

Contains engineering support scripts and utilities, such as:

- SDK sync scripts
- validation helpers
- migration helpers if needed

Temporary one-off scripts should not remain at the repository root.

### `docs/`

Contains design docs, plans, and collaboration material. Existing Superpowers documentation should continue to live here once the repository root is moved.

## Source-of-Truth Rule for SDK Code

The repository should enforce a clear relationship between SDK source and app integration:

- `vendor/sdk_source/` is the source of truth for generated SDK code
- `lib/sdk/` is the app integration copy

Operational rules:

- Structural or generated changes begin in `vendor/sdk_source/`
- `lib/sdk/` should be updated through synchronization, not ad hoc divergence
- App-specific workarounds should live in repositories, adapters, or `lib/core/api`, not inside the generated SDK unless there is no practical alternative
- The sync direction from `vendor/sdk_source/` to `lib/sdk/` must be documented

This rule is intended to prevent the current risk of source drift between generated code and app-integrated code.

## Root Directory Rules

Once the migration is complete, the repository root should no longer contain:

- A nested app project directory such as `xiaobaihe_app/`
- A standalone generated-source directory such as `dart/`
- Unclassified experiment or scratch directories that are not part of `docs/`, `tools/`, or another intentional top-level area

The root should stay limited to:

- Flutter app standard directories and files
- Supporting engineering directories
- Documentation

## Migration Plan

Perform the migration in repository-boundary order, not in feature-refactor order.

1. Create or reserve top-level support directories: `vendor/`, `tools/`, and `docs/`
2. Move the contents of `xiaobaihe_app/` to the workspace root so the Flutter project lives directly at the root
3. Move `dart/` to `vendor/sdk_source/`
4. Keep `lib/sdk/` unchanged during the boundary migration
5. Update documentation to describe the new repository layout and SDK ownership rules
6. Optionally add `tools/sync_sdk.ps1` later once the directory model is stable

The sequencing is deliberate:

- First solve repository clarity
- Then add automation

This keeps the migration easier to review and easier to roll back if needed.

## Risks

### Git boundary risk

The current `.git` directory is inside `xiaobaihe_app/`. Moving the repository root to the workspace root changes the version-control boundary and must be handled as a focused migration, not mixed with feature work.

### Path and tooling risk

Any path assumptions in documentation, IDE settings, scripts, or future CI configuration may still assume `xiaobaihe_app/` is the execution root. Those references must be reviewed during migration.

### SDK drift risk

If the team does not document and follow the source-of-truth rule, `vendor/sdk_source/` and `lib/sdk/` will diverge over time and recreate the same maintenance ambiguity in a different directory layout.

## Acceptance Criteria

The migration is successful when all of the following are true:

- Opening the workspace root shows the Flutter project directly
- The root no longer contains both `xiaobaihe_app/` and `dart/`
- Generated SDK source has a fixed home under `vendor/sdk_source/`
- Flutter commands such as `flutter analyze`, `flutter test`, and `flutter run` are executed from the workspace root
- Documentation clearly explains SDK ownership and synchronization direction
- No `lib/` internal architectural refactor is bundled into this migration

## Follow-Up Work

After this migration is complete, future design and planning can address:

- `lib/` internal organization cleanup
- Large-file decomposition in presentation layers
- SDK synchronization automation
- Possible package-based SDK extraction if the integration model later needs stronger isolation
