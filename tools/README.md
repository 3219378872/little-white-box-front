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

## Knowledge validation

`knowledge_base.py` validates the five-layer knowledge graph, including formal
IDs, status values, upstream types, requirement coverage, reciprocal
implementation/evidence references, and local Markdown links.

Run it through the repository command surface:

```bash
make knowledge-check
```
