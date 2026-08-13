# Tools

This directory stores repeatable repository-maintenance scripts for the app-centric repo layout.

Current policy:

- Store future SDK sync automation here
- Store future repo-layout validation scripts here
- Do not leave one-off migration scratch files at the repository root

## Knowledge validation

`knowledge_base.py` validates the five-layer knowledge graph, including formal
IDs, status values, upstream types, requirement coverage, reciprocal
implementation/evidence references, and local Markdown links.

Run it through the repository command surface:

```bash
make knowledge-check
```
