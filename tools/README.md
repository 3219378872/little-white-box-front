# Tools

This directory stores repeatable repository-maintenance scripts for the app-centric repo layout.

Current policy:

- Store SDK sync automation here
- Store future repo-layout validation scripts here
- Do not leave one-off migration scratch files at the repository root

## Gateway SDK sync

`sync_gateway_sdk.py` regenerates Dart types and API methods from the sibling
backend `gateway.api` via `goctl api dart`, then patches PUT/DELETE verbs that
the Dart generator still emits as POST. It also removes the checkout-specific
absolute source path and formats the generated files before copying them.

```bash
python3 tools/sync_gateway_sdk.py \
  --api ../little-white-box-content-community/app/gateway/gateway.api
```

It updates `vendor/sdk_source/{api,data}/gateway.dart` and the `lib/sdk/`
copies. Application-owned transport (`api/api.dart`, tokens, vars) is left
untouched.

Use check mode in CI or review gates. It generates into a temporary directory,
compares both tracked destinations byte-for-byte, and does not modify the
checkout:

```bash
make sdk-check BACKEND_API=/absolute/path/to/verified/gateway.api
```

The API path must refer to the backend revision actually being reviewed. Do not
let sibling-directory auto-discovery stand in for the root repository's pinned
submodule contract. `--check`, `make sdk-check`, and `make check` therefore
reject a missing explicit API path. Sibling discovery remains available only
for the writing sync command.

## Knowledge validation

`knowledge_base.py` validates the five-layer knowledge graph, including formal
IDs and lifecycle values, external reference syntax, complete layer indexes,
requirement ownership, code paths, authority rows, evidence result/scope/SHA,
reciprocal implementation/evidence references, and local Markdown links.

Titles and every item in the controlled list fields (`upstream`, `tracks`,
`code_paths`, `evidence`, `covers`, `scope`, `commands`, and optional
`external_upstream`) must contain non-whitespace text; list items must be
unique. Requirements, layer-index links, and implementation authority are read
from semantic Markdown, so fenced examples and HTML comments do not contribute
to the graph. Each non-retired implementation must contain exactly one
authority table with the canonical four-column header followed by a valid
Markdown separator; only its consecutive data rows are authoritative.

For active passed evidence, the checker also diffs every upstream
implementation's `code_paths` from `observed_commit` through `HEAD`. A later
committed, unstaged, staged, or untracked change under those paths makes the
evidence stale, while implementation or evidence documentation-only changes do
not.

Run it through the repository command surface:

```bash
make knowledge-test
make knowledge-check
```

`make check BACKEND_API=...` composes static analysis, Flutter and tool tests,
the knowledge graph, and non-writing SDK drift detection.
