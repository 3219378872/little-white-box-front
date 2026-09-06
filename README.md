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
│   └── knowledge/
├── tools/
└── vendor/
    └── sdk_source/
```

## Common Commands

```bash
make setup
make analyze
make test
make test-coverage
make knowledge-test
make knowledge-check
make sdk-check BACKEND_API=/absolute/path/to/verified/gateway.api
make check BACKEND_API=/absolute/path/to/verified/gateway.api
```

## Web Development

The browser development entry point uses the in-repo mock API and does not
require the Go backend or local middleware services:

Mock mode starts authenticated as the seed user `1` (`小白鸽` / `xiaobaige`).
The in-repo mock now follows the current Gateway HTTP contract: typed
success payloads, `{code, message}` errors, Bearer JWT on protected
routes, and the same v1/v2 path table as `gateway.api`. Seed password
is `123456`. Username `admin` maps to the same seed user.

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

To use a real API instead of Mock, run the normal entry point. Requests use
relative paths such as `/api/v1/health`, so the page origin must reverse-proxy
or otherwise serve the gateway:

```bash
make dev-real
```

To call an absolute gateway instead (for example a local process on another
port), pass `SERVER_HOST` explicitly. That mode requires CORS for the browser
origin:

```bash
make dev-real SERVER_HOST=http://127.0.0.1:8888
```

## SDK Workflow

1. Treat `vendor/sdk_source/` as the source of truth for generated SDK code.
2. Treat `lib/sdk/` as the app integration copy.
3. Keep app-specific workarounds in `lib/core/api/` or feature repositories instead of modifying generated SDK files unless there is no practical alternative.

## Documentation

Project knowledge follows one governed chain:

```text
intent -> specification -> design -> implementation <-> evidence
```

- Start at the [knowledge router](docs/knowledge/README.md).
- Forui and presentation rules live in the [presentation design](docs/knowledge/design/DES-presentation-client.md).
- Historical MVP plans, repository-migration records, and backend coordination snapshots live in the
  [non-authoritative archive](docs/knowledge/archive/README.md).
- Run `make knowledge-check` after changing governed knowledge, and use `make check` with an explicitly verified
  backend API when changing tracked behavior or the generated contract.
