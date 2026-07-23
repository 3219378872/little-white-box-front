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

## Web Development

The browser development entry point uses the in-repo mock API and does not
require the Go backend or local middleware services:

```bash
flutter pub get
flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port 8080 \
  -t lib/main_mock.dart
```

Open `http://localhost:8080` from the host browser. For a release artifact:

```bash
flutter build web --release -t lib/main_mock.dart
python3 -m http.server 8080 --directory build/web
```

To use a real API instead of Mock, run the normal entry point and provide the
gateway URL explicitly:

```bash
flutter run -d web-server \
  --dart-define=SERVER_HOST=http://127.0.0.1:8888
```

The API gateway must allow the browser origin through CORS for this mode.

## SDK Workflow

1. Treat `vendor/sdk_source/` as the source of truth for generated SDK code.
2. Treat `lib/sdk/` as the app integration copy.
3. Keep app-specific workarounds in `lib/core/api/` or feature repositories instead of modifying generated SDK files unless there is no practical alternative.

## Documentation

- Design specs and plans live under `docs/superpowers/`
- Backend coordination notes live under `docs/backend/`
