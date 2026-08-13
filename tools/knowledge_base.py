#!/usr/bin/env python3
"""Validate the repository's five-layer knowledge graph."""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
KNOWLEDGE = DOCS / "knowledge"

LAYER_DIRS = {
    "intent": KNOWLEDGE / "intent",
    "spec": KNOWLEDGE / "spec",
    "design": KNOWLEDGE / "design",
    "implementation": KNOWLEDGE / "implementation",
    "evidence": KNOWLEDGE / "evidence",
}
PREFIXES = {
    "intent": "INT-",
    "spec": "SPEC-",
    "design": "DES-",
    "implementation": "IMP-",
    "evidence": "EVD-",
}
UPSTREAM_LAYER = {
    "intent": None,
    "spec": "intent",
    "design": "spec",
    "implementation": "design",
    "evidence": "implementation",
}
ALLOWED_STATUS = {
    "intent": {"draft", "baseline", "approved", "deprecated"},
    "spec": {"draft", "baseline", "approved", "deprecated"},
    "design": {"draft", "baseline", "accepted", "deprecated"},
    "implementation": {"aligned", "diverged", "unknown", "deprecated"},
    "evidence": {"verified", "partial", "failed", "superseded"},
}

ID_RE = re.compile(r"^(?:INT|SPEC|DES|IMP|EVD)-[a-z0-9]+(?:-[a-z0-9]+)*$")
REQUIREMENT_RE = re.compile(r"`((?:FX|FQ)-\d{3})`")
LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


@dataclass(frozen=True)
class Document:
    path: Path
    layer: str
    body: str
    meta: dict[str, str | list[str]]

    @property
    def id(self) -> str:
        value = self.meta.get("id", "")
        return value if isinstance(value, str) else ""

    def values(self, key: str) -> list[str]:
        value = self.meta.get(key, [])
        if isinstance(value, list):
            return value
        return [value] if value else []


def parse_frontmatter(path: Path, errors: list[str]) -> tuple[dict[str, str | list[str]], str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        errors.append(f"{relative(path)}: missing frontmatter")
        return {}, text
    try:
        end = next(index for index, line in enumerate(lines[1:], start=1) if line.strip() == "---")
    except StopIteration:
        errors.append(f"{relative(path)}: unclosed frontmatter")
        return {}, text

    meta: dict[str, str | list[str]] = {}
    active_list: str | None = None
    for number, line in enumerate(lines[1:end], start=2):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith("  - "):
            if active_list is None:
                errors.append(f"{relative(path)}:{number}: list item has no key")
                continue
            value = line[4:].strip().strip('"\'')
            current = meta.setdefault(active_list, [])
            if not isinstance(current, list):
                errors.append(f"{relative(path)}:{number}: {active_list} is not a list")
                continue
            current.append(value)
            continue
        match = re.fullmatch(r"([a-z_][a-z0-9_]*):(?:\s*(.*))?", line)
        if match is None:
            errors.append(f"{relative(path)}:{number}: unsupported frontmatter syntax")
            active_list = None
            continue
        key, raw = match.groups()
        raw = (raw or "").strip()
        if key in meta:
            errors.append(f"{relative(path)}:{number}: duplicate frontmatter key {key}")
        if raw in {"", "[]"}:
            meta[key] = []
            active_list = key if raw == "" else None
        else:
            meta[key] = raw.strip('"\'')
            active_list = None
    return meta, "\n".join(lines[end + 1 :])


def relative(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def formal_documents(errors: list[str]) -> list[Document]:
    documents: list[Document] = []
    for layer, directory in LAYER_DIRS.items():
        if not directory.is_dir():
            errors.append(f"{relative(directory)}: required layer directory is missing")
            continue
        readme = directory / "README.md"
        if not readme.is_file():
            errors.append(f"{relative(readme)}: required layer index is missing")
        for path in sorted(directory.rglob("*.md")):
            if path.name == "README.md":
                continue
            meta, body = parse_frontmatter(path, errors)
            documents.append(Document(path=path, layer=layer, body=body, meta=meta))
    return documents


def validate_metadata(documents: list[Document], errors: list[str]) -> dict[str, Document]:
    by_id: dict[str, Document] = {}
    required = {"id", "layer", "title", "status", "owner", "upstream", "updated_at"}
    for doc in documents:
        label = relative(doc.path)
        missing = sorted(required - doc.meta.keys())
        if missing:
            errors.append(f"{label}: missing frontmatter keys: {', '.join(missing)}")

        if doc.meta.get("layer") != doc.layer:
            errors.append(f"{label}: layer must be {doc.layer}")
        if not doc.id.startswith(PREFIXES[doc.layer]) or not ID_RE.fullmatch(doc.id):
            errors.append(f"{label}: invalid {doc.layer} id {doc.id!r}")
        elif doc.id in by_id:
            errors.append(f"{label}: duplicate id {doc.id} (also {relative(by_id[doc.id].path)})")
        else:
            by_id[doc.id] = doc

        status = doc.meta.get("status")
        if status not in ALLOWED_STATUS[doc.layer]:
            errors.append(f"{label}: invalid status {status!r} for {doc.layer}")
        owner = doc.meta.get("owner")
        if owner not in {"human", "agent"}:
            errors.append(f"{label}: owner must be human or agent")
        if doc.layer in {"intent", "spec"} and owner != "human":
            errors.append(f"{label}: intent/spec semantic owner must be human")

        updated = doc.meta.get("updated_at")
        if not isinstance(updated, str) or not DATE_RE.fullmatch(updated):
            errors.append(f"{label}: updated_at must be YYYY-MM-DD")
        else:
            try:
                date.fromisoformat(updated)
            except ValueError:
                errors.append(f"{label}: updated_at is not a valid date")

        upstream = doc.meta.get("upstream")
        if not isinstance(upstream, list):
            errors.append(f"{label}: upstream must be a YAML list")
        elif doc.layer == "intent" and upstream:
            errors.append(f"{label}: intent must not have upstream references")
        elif doc.layer != "intent" and not upstream:
            errors.append(f"{label}: {doc.layer} requires at least one upstream reference")

        if doc.layer in {"design", "implementation"} and not doc.values("tracks"):
            errors.append(f"{label}: {doc.layer} requires a non-empty tracks list")
        if doc.layer == "implementation" and not doc.values("evidence"):
            errors.append(f"{label}: implementation requires a non-empty evidence list")
        if doc.layer == "evidence" and not doc.values("covers"):
            errors.append(f"{label}: evidence requires a non-empty covers list")
    return by_id


def validate_graph(documents: list[Document], by_id: dict[str, Document], errors: list[str]) -> None:
    requirements: dict[str, Document] = {}
    for doc in documents:
        if doc.layer != "spec":
            continue
        for requirement in REQUIREMENT_RE.findall(doc.body):
            previous = requirements.get(requirement)
            if previous is not None and previous.path != doc.path:
                errors.append(
                    f"{relative(doc.path)}: requirement {requirement} also belongs to {relative(previous.path)}"
                )
            requirements[requirement] = doc

    for doc in documents:
        expected = UPSTREAM_LAYER[doc.layer]
        for upstream_id in doc.values("upstream"):
            upstream = by_id.get(upstream_id)
            if upstream is None:
                errors.append(f"{relative(doc.path)}: unknown upstream id {upstream_id}")
                continue
            if upstream.layer != expected:
                errors.append(
                    f"{relative(doc.path)}: upstream {upstream_id} must be in {expected}, not {upstream.layer}"
                )

        status = doc.meta.get("status")
        if doc.layer == "spec" and status == "approved":
            for upstream_id in doc.values("upstream"):
                upstream = by_id.get(upstream_id)
                if upstream is not None and upstream.meta.get("status") != "approved":
                    errors.append(f"{relative(doc.path)}: approved spec requires approved intent {upstream_id}")
        if doc.layer == "design" and status == "accepted":
            for upstream_id in doc.values("upstream"):
                upstream = by_id.get(upstream_id)
                if upstream is not None and upstream.meta.get("status") != "approved":
                    errors.append(f"{relative(doc.path)}: accepted design requires approved spec {upstream_id}")

        for requirement in doc.values("tracks") + doc.values("covers"):
            if requirement not in requirements:
                errors.append(f"{relative(doc.path)}: unknown requirement {requirement}")

    design_tracks = {
        requirement
        for doc in documents
        if doc.layer == "design"
        for requirement in doc.values("tracks")
    }
    implementation_tracks = {
        requirement
        for doc in documents
        if doc.layer == "implementation"
        for requirement in doc.values("tracks")
    }
    evidence_covers = {
        requirement
        for doc in documents
        if doc.layer == "evidence"
        for requirement in doc.values("covers")
    }
    for description, missing in (
        ("requirements without design coverage", set(requirements) - design_tracks),
        ("design tracks without implementation coverage", design_tracks - implementation_tracks),
        ("implementation tracks without evidence coverage", implementation_tracks - evidence_covers),
    ):
        if missing:
            errors.append(f"{description}: {', '.join(sorted(missing))}")

    for doc in documents:
        if doc.layer == "implementation":
            upstream_tracks = {
                requirement
                for upstream_id in doc.values("upstream")
                for requirement in (by_id.get(upstream_id).values("tracks") if by_id.get(upstream_id) else [])
            }
            unexpected = set(doc.values("tracks")) - upstream_tracks
            if unexpected:
                errors.append(
                    f"{relative(doc.path)}: tracks not covered by upstream design: {', '.join(sorted(unexpected))}"
                )
            for evidence_id in doc.values("evidence"):
                evidence = by_id.get(evidence_id)
                if evidence is None or evidence.layer != "evidence":
                    errors.append(f"{relative(doc.path)}: unknown evidence id {evidence_id}")
                elif doc.id not in evidence.values("upstream"):
                    errors.append(
                        f"{relative(doc.path)}: evidence {evidence_id} does not link back to {doc.id}"
                    )

        if doc.layer == "evidence":
            upstream_tracks = {
                requirement
                for upstream_id in doc.values("upstream")
                for requirement in (by_id.get(upstream_id).values("tracks") if by_id.get(upstream_id) else [])
            }
            unexpected = set(doc.values("covers")) - upstream_tracks
            if unexpected:
                errors.append(
                    f"{relative(doc.path)}: covers not tracked by upstream implementation: {', '.join(sorted(unexpected))}"
                )
            for implementation_id in doc.values("upstream"):
                implementation = by_id.get(implementation_id)
                if implementation is not None and doc.id not in implementation.values("evidence"):
                    errors.append(
                        f"{relative(doc.path)}: implementation {implementation_id} does not link back to {doc.id}"
                    )


def validate_links(errors: list[str]) -> int:
    paths = [ROOT / "AGENTS.md", ROOT / "README.md"]
    paths.extend(sorted(KNOWLEDGE.rglob("*.md")))
    checked = 0
    for path in paths:
        if not path.is_file() or "templates" in path.parts:
            continue
        text = path.read_text(encoding="utf-8")
        for raw_target in LINK_RE.findall(text):
            target = raw_target.strip().split(maxsplit=1)[0].strip("<>")
            if not target or target.startswith(("#", "http://", "https://", "mailto:")):
                continue
            if re.match(r"^[A-Za-z]:[\\/]", target):
                continue
            target = unquote(target.split("#", maxsplit=1)[0])
            resolved = (path.parent / target).resolve()
            checked += 1
            if not resolved.exists():
                errors.append(f"{relative(path)}: broken local link {raw_target}")
    return checked


def validate_governance(errors: list[str]) -> None:
    required = [
        KNOWLEDGE / "README.md",
        KNOWLEDGE / "archive" / "README.md",
        KNOWLEDGE / "templates" / "README.md",
    ]
    for path in required:
        if not path.is_file():
            errors.append(f"{relative(path)}: required knowledge entry is missing")

    outside = [
        path
        for path in DOCS.rglob("*.md")
        if KNOWLEDGE not in path.parents and path != KNOWLEDGE
    ]
    if outside:
        errors.append(
            "markdown files outside docs/knowledge: "
            + ", ".join(relative(path) for path in sorted(outside))
        )

    required_text = {
        ROOT / "AGENTS.md": ["docs/knowledge/README.md", "make knowledge-check"],
        ROOT / "README.md": ["docs/knowledge/README.md", "make knowledge-check"],
        ROOT / "Makefile": ["knowledge-check:"],
    }
    for path, needles in required_text.items():
        if not path.is_file():
            errors.append(f"{relative(path)}: required governance file is missing")
            continue
        text = path.read_text(encoding="utf-8")
        for needle in needles:
            if needle not in text:
                errors.append(f"{relative(path)}: missing governance reference {needle!r}")


def check() -> int:
    errors: list[str] = []
    validate_governance(errors)
    documents = formal_documents(errors)
    by_id = validate_metadata(documents, errors)
    validate_graph(documents, by_id, errors)
    link_count = validate_links(errors)

    if errors:
        print("knowledge-check: FAILED", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    requirement_count = sum(
        len(set(REQUIREMENT_RE.findall(doc.body)))
        for doc in documents
        if doc.layer == "spec"
    )
    print(
        "knowledge-check: OK "
        f"({len(documents)} formal documents, {requirement_count} requirements, {link_count} local links)"
    )
    return 0


def main(argv: list[str]) -> int:
    if argv != ["check"]:
        print("usage: python3 tools/knowledge_base.py check", file=sys.stderr)
        return 2
    return check()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
