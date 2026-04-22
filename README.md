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
