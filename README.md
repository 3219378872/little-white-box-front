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
make setup
make analyze
make test
```

## Web Development

The browser development entry point uses the in-repo mock API and does not
require the Go backend or local middleware services:

Mock mode starts authenticated as the seed user `1` (`小白鸽`).

For foreground development with hot reload:

```bash
make dev
```

The default development port is `3000`; override it with `make dev PORT=8080`.

For a release-style background server:

```bash
make start
make status
make stop
```

Open `http://localhost:3000` from the host browser. `make start` builds
`build/web/`, starts a background static server, and records its PID under
`.dart_tool/`. `make restart` rebuilds and restarts it. Use `make serve` when a
foreground static server is preferred.

To use a real API instead of Mock, run the normal entry point and provide the
gateway URL explicitly:

```bash
make dev-real SERVER_HOST=http://127.0.0.1:8888
```

The API gateway must allow the browser origin through CORS for this mode.

## SDK Workflow

1. Treat `vendor/sdk_source/` as the source of truth for generated SDK code.
2. Treat `lib/sdk/` as the app integration copy.
3. Keep app-specific workarounds in `lib/core/api/` or feature repositories instead of modifying generated SDK files unless there is no practical alternative.

## Documentation

- Forui component usage and official LLM documentation links live in [`docs/forui.md`](docs/forui.md)
- Design specs and plans live under `docs/superpowers/`
- Backend coordination notes live under `docs/backend/`
