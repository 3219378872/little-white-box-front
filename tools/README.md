# Tools

This directory stores repeatable repository-maintenance scripts for the app-centric repo layout.

Current policy:

- Store SDK sync automation here
- Store future repo-layout validation scripts here
- Do not leave one-off migration scratch files at the repository root

## Gateway SDK sync

`sync_gateway_sdk.py` regenerates Dart types and API methods from the sibling
backend `openapi.yaml` using pinned PyYAML and project templates. OpenAPI operation
verbs, path/query fields, JSON aliases, lossless IDs and PATCH presence are generated
deterministically. Dart formats both outputs before copying them.

```bash
python3 tools/sync_gateway_sdk.py \
  --api ../little-white-box-content-community/app/gateway/openapi.yaml
```

It updates `vendor/sdk_source/{api,data}/gateway.dart` and the `lib/sdk/`
copies. Application-owned transport (`api/api.dart`, tokens, vars) is left
untouched. Multipart and SSE operations generate route helpers used by those
transports; they do not generate JSON request wrappers.

Use check mode in CI or review gates. It generates into a temporary directory,
compares both tracked destinations byte-for-byte, and does not modify the
checkout:

```bash
make sdk-check BACKEND_API=/absolute/path/to/verified/openapi.yaml
```

The API path must refer to the backend revision actually being reviewed. Do not
let sibling-directory auto-discovery stand in for the root repository's pinned
submodule contract. `--check`, `make sdk-check`, and `make check` therefore
reject a missing explicit API path. Sibling discovery remains available only
for the writing sync command.

## Knowledge validation

Run `make knowledge-setup` once to install pinned YAML and Markdown parsers in
`.venv-knowledge`. `make knowledge-check` is read-only; `make knowledge-index`
explicitly updates generated index blocks. `make knowledge-export REF=<sha>` emits
versioned JSON from Git blobs without executing historical scripts.

The implementation matrix is the sole hand-maintained ownership/state record.
Evidence stores independent requirement/input groups; only changed groups stop
supporting current aligned rows. Historical results and explicit gaps are retained.
See [the knowledge contract](../docs/knowledge/README.md) for the authoring rules.

`make knowledge-test` exercises parsers, graph ownership, snapshots, and evidence
invalidation. `make check BACKEND_API=...` retains the application and SDK gates.
