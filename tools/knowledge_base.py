#!/usr/bin/env python3
"""Validate the repository's five-layer knowledge graph."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from urllib.parse import unquote


DEFAULT_ROOT = Path(__file__).resolve().parents[1]
ROOT = Path(os.environ.get("KNOWLEDGE_ROOT", DEFAULT_ROOT)).resolve()
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
    "intent": {"draft", "approved", "retired"},
    "spec": {"draft", "approved", "retired"},
    "design": {"draft", "active", "blocked", "superseded"},
    "implementation": {"unknown", "aligned", "diverged", "retired"},
    "evidence": {"active", "superseded"},
}
EVIDENCE_RESULTS = {"passed", "partial", "failed", "blocked"}
EVIDENCE_SCOPES = {
    "static",
    "unit",
    "integration",
    "e2e",
    "browser",
    "device",
    "synthetic",
    "human-review",
    "live-provider",
    "production",
}
EXTERNAL_REPOS = {
    "little-white-box",
    "little-white-box-content-community",
    "little-white-box-front",
}
CONTROLLED_LIST_KEYS = {
    "upstream",
    "tracks",
    "code_paths",
    "evidence",
    "covers",
    "scope",
    "commands",
    "external_upstream",
}

ID_RE = re.compile(r"^(?:INT|SPEC|DES|IMP|EVD)-[a-z0-9]+(?:-[a-z0-9]+)*$")
REQUIREMENT_BULLET_RE = re.compile(
    r"^ {0,3}[-*][ \t]+`(?P<requirement>(?:FX|FQ)-\d{3})`[：:]"
    r"[ \t]*\S"
)
REQUIREMENT_ID_RE = re.compile(r"^(?:FX|FQ)-\d{3}$")
REQUIREMENT_TABLE_HEADERS = {"requirement", "条款", "id"}
EXTERNAL_REQUIREMENT_ID_RE = re.compile(
    r"^[A-Z][A-Z0-9]*-(?:A[0-9]{2}|[0-9]{3}(?:-[0-9]{2})?)$"
)
LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
EXTERNAL_UPSTREAM_RE = re.compile(r"^([^@]+)@([0-9a-f]{40}):(.+)$")
FENCE_OPEN_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
ATX_HEADING_RE = re.compile(r"^ {0,3}#{1,6}(?:[ \t]+|$)")
SETEXT_HEADING_RE = re.compile(r"^ {0,3}(?:=+|-+)[ \t]*$")
LIST_MARKER_RE = re.compile(r"(?:[-+*]|\d{1,9}[.)])")
INLINE_SPAN_SENTINEL = "x"
AUTHORITY_HEADER = ("requirement", "design", "state", "evidence or gap")
AUTHORITY_SEPARATOR_RE = re.compile(r"^:?-{3,}:?$")
EVIDENCE_ID_RE = re.compile(r"EVD-[a-z0-9]+(?:-[a-z0-9]+)*")


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


@dataclass(frozen=True)
class ContainerScope:
    quote_depth: int = 0
    list_marker_indent: int | None = None
    list_content_indent: int | None = None

    @property
    def is_container(self) -> bool:
        return self.quote_depth > 0 or self.list_content_indent is not None


@dataclass(frozen=True)
class ListItem:
    marker_indent: int
    content_indent: int
    content_start: int


@dataclass(frozen=True)
class FenceState:
    character: str
    length: int
    container: ContainerScope


def relative(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def _frontmatter_body(text: str) -> str:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return text
    for index, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            return "\n".join(lines[index + 1 :])
    return ""


def _backtick_run_end(line: str, start: int) -> int:
    end = start
    while end < len(line) and line[end] == "`":
        end += 1
    return end


def _next_visual_column(column: int, character: str) -> int:
    if character == "\t":
        return column + (4 - column % 4)
    return column + 1


def _leading_indent(text: str, start_column: int = 0) -> tuple[int, int]:
    cursor = 0
    column = start_column
    while cursor < len(text) and text[cursor] in " \t":
        column = _next_visual_column(column, text[cursor])
        cursor += 1
    return cursor, column - start_column


def _strip_indent(text: str, width: int) -> str | None:
    cursor, actual = _leading_indent(text)
    if actual < width:
        return None
    return " " * (actual - width) + text[cursor:]


def _strip_blockquote_prefixes(line: str) -> tuple[str, int, int]:
    cursor = 0
    depth = 0
    while cursor < len(line):
        indentation_end, indentation = _leading_indent(line[cursor:])
        if indentation > 3:
            break
        marker = cursor + indentation_end
        if marker >= len(line) or line[marker] != ">":
            break
        cursor = marker + 1
        if cursor < len(line) and line[cursor] in " \t":
            cursor += 1
        depth += 1
    return line[cursor:], depth, cursor


def _parse_list_item(text: str, base_column: int = 0) -> ListItem | None:
    indentation_end, indentation = _leading_indent(text, base_column)
    if indentation > 3:
        return None
    marker = LIST_MARKER_RE.match(text, indentation_end)
    if marker is None:
        return None
    marker_end = marker.end()
    marker_column = base_column + indentation + len(marker.group())
    if marker_end == len(text):
        spacing_end = 0
        spacing = 1
    elif text[marker_end] not in " \t":
        return None
    else:
        spacing_end, spacing = _leading_indent(text[marker_end:], marker_column)
        if not 1 <= spacing <= 4:
            return None
    return ListItem(
        marker_indent=base_column + indentation,
        content_indent=marker_column + spacing,
        content_start=marker_end + spacing_end,
    )


def _container_candidates(line: str) -> list[tuple[str, ContainerScope]]:
    content, quote_depth, _ = _strip_blockquote_prefixes(line)
    candidates = [(content, ContainerScope(quote_depth=quote_depth))]
    remaining = content
    base_column = 0
    while True:
        item = _parse_list_item(remaining, base_column)
        if item is None:
            break
        remaining = remaining[item.content_start :]
        base_column = item.content_indent
        candidates.append(
            (
                remaining,
                ContainerScope(
                    quote_depth=quote_depth,
                    list_marker_indent=item.marker_indent,
                    list_content_indent=item.content_indent,
                ),
            )
        )
    return candidates


def _fence_candidates(
    line: str, active_container: ContainerScope | None = None
) -> list[tuple[str, ContainerScope]]:
    candidates: list[tuple[str, ContainerScope]] = []
    if active_container is not None and active_container.list_content_indent is not None:
        content, quote_depth, _ = _strip_blockquote_prefixes(line)
        if quote_depth == active_container.quote_depth:
            continuation = _strip_indent(
                content, active_container.list_content_indent
            )
            if continuation is not None:
                candidates.append((continuation, active_container))
    candidates.extend(_container_candidates(line))
    return candidates


def _fence_opening(
    line: str, active_container: ContainerScope | None = None
) -> FenceState | None:
    for candidate, container in _fence_candidates(line, active_container):
        opening = FENCE_OPEN_RE.fullmatch(candidate)
        if opening is None:
            continue
        marker, remainder = opening.groups()
        if marker[0] != "`" or "`" not in remainder:
            return FenceState(marker[0], len(marker), container)
    return None


def _is_invalid_backtick_fence(
    line: str, active_container: ContainerScope | None = None
) -> bool:
    for candidate, _ in _fence_candidates(line, active_container):
        opening = FENCE_OPEN_RE.fullmatch(candidate)
        if opening is not None:
            marker, remainder = opening.groups()
            if marker[0] == "`" and "`" in remainder:
                return True
    return False


def _plain_block_boundary(line: str) -> bool:
    return (
        not line.strip()
        or ATX_HEADING_RE.match(line) is not None
        or SETEXT_HEADING_RE.fullmatch(line) is not None
        or _fence_opening(line) is not None
    )


def _inline_line_crosses_boundary(line: str, scope: ContainerScope) -> bool:
    if not line.strip():
        return True
    content, quote_depth, _ = _strip_blockquote_prefixes(line)
    if quote_depth != scope.quote_depth:
        return True
    if scope.list_content_indent is not None:
        content = _strip_indent(content, scope.list_content_indent)
        if content is None:
            return True
    elif not scope.is_container and quote_depth > 0:
        return True
    if _parse_list_item(content) is not None:
        return True
    return _plain_block_boundary(content)


def _inline_code_span_end(
    lines: list[str], line_index: int, start: int, scope: ContainerScope
) -> tuple[int, int] | None:
    opening_end = _backtick_run_end(lines[line_index], start)
    opening_length = opening_end - start
    single_line_only = _is_invalid_backtick_fence(lines[line_index], scope)
    for candidate_line_index in range(line_index, len(lines)):
        line = lines[candidate_line_index]
        if candidate_line_index > line_index:
            if single_line_only or _inline_line_crosses_boundary(line, scope):
                return None
        cursor = opening_end if candidate_line_index == line_index else 0
        while cursor < len(line):
            candidate = line.find("`", cursor)
            if candidate < 0:
                break
            candidate_end = _backtick_run_end(line, candidate)
            if candidate_end - candidate == opening_length:
                return candidate_line_index, candidate_end
            cursor = candidate_end
    return None


def _update_list_context(
    line: str, stack: list[ContainerScope]
) -> ContainerScope:
    content, quote_depth, _ = _strip_blockquote_prefixes(line)
    if line.strip() and any(item.quote_depth != quote_depth for item in stack):
        stack.clear()

    list_scopes = [
        scope
        for _, scope in _container_candidates(line)
        if scope.list_content_indent is not None
    ]
    if list_scopes:
        first_marker_indent = list_scopes[0].list_marker_indent
        assert first_marker_indent is not None
        while (
            stack
            and stack[-1].list_content_indent is not None
            and first_marker_indent < stack[-1].list_content_indent
        ):
            stack.pop()
        for scope in list_scopes:
            marker_indent = scope.list_marker_indent
            assert marker_indent is not None
            if stack:
                content_indent = stack[-1].list_content_indent
                assert content_indent is not None
                if marker_indent < content_indent:
                    break
            elif marker_indent > 3:
                break
            stack.append(scope)
    elif line.strip():
        _, indentation = _leading_indent(content)
        while (
            stack
            and stack[-1].list_content_indent is not None
            and indentation < stack[-1].list_content_indent
        ):
            stack.pop()

    if stack and stack[-1].quote_depth == quote_depth:
        return stack[-1]
    return ContainerScope(quote_depth=quote_depth)


def _fence_line(
    line: str, state: FenceState
) -> tuple[str | None, bool]:
    if not state.container.is_container:
        return line, False
    if not line.strip():
        return "", False
    content, quote_depth, _ = _strip_blockquote_prefixes(line)
    if quote_depth != state.container.quote_depth:
        return None, True
    if state.container.list_content_indent is not None:
        content = _strip_indent(content, state.container.list_content_indent)
        if content is None:
            return None, True
    return content, False


def _is_fence_closing(line: str, state: FenceState) -> bool:
    indentation_end, indentation = _leading_indent(line)
    if indentation > 3:
        return False
    candidate = line[indentation_end:]
    return (
        re.fullmatch(
            rf"{re.escape(state.character)}{{{state.length},}}[ \t]*",
            candidate,
        )
        is not None
    )


def semantic_markdown(text: str) -> str:
    """Remove content that Markdown renders as comments or fenced code."""
    lines = text.splitlines()
    semantic_lines: list[str] = []
    fence_state: FenceState | None = None
    in_comment = False
    multiline_span_end: tuple[int, int] | None = None
    list_stack: list[ContainerScope] = []
    for line_index, line in enumerate(lines):
        if fence_state is not None:
            candidate, boundary = _fence_line(line, fence_state)
            if not boundary:
                if candidate is not None and _is_fence_closing(candidate, fence_state):
                    fence_state = None
                continue
            fence_state = None

        active_container = _update_list_context(line, list_stack)
        visible_parts: list[str] = []
        cursor = 0
        if multiline_span_end is not None:
            closing_line, closing_end = multiline_span_end
            if line_index < closing_line:
                semantic_lines.append(INLINE_SPAN_SENTINEL)
                continue
            # Keep a non-whitespace prefix so a closing-line suffix cannot
            # become a block-level definition after the span is removed.
            visible_parts.append(INLINE_SPAN_SENTINEL)
            cursor = closing_end
            multiline_span_end = None
        elif not in_comment:
            opening = _fence_opening(line, active_container)
            if opening is not None:
                fence_state = opening
                continue

        while cursor < len(line):
            if in_comment:
                end = line.find("-->", cursor)
                if end < 0:
                    cursor = len(line)
                    break
                in_comment = False
                cursor = end + 3
                continue
            if line.startswith("<!--", cursor):
                in_comment = True
                cursor += 4
                continue
            if line[cursor] == "`":
                opening_end = _backtick_run_end(line, cursor)
                span_end = _inline_code_span_end(
                    lines, line_index, cursor, active_container
                )
                if span_end is not None:
                    closing_line, closing_end = span_end
                    if closing_line == line_index:
                        visible_parts.append(line[cursor:closing_end])
                        cursor = closing_end
                    else:
                        visible_parts.append(INLINE_SPAN_SENTINEL)
                        multiline_span_end = span_end
                        cursor = len(line)
                else:
                    visible_parts.append(line[cursor:opening_end])
                    cursor = opening_end
                continue
            visible_parts.append(line[cursor])
            cursor += 1
        semantic_lines.append("".join(visible_parts))
    return "\n".join(semantic_lines)


def _split_requirement_table_row(line: str) -> list[str] | None:
    leading_spaces = len(line) - len(line.lstrip(" "))
    if leading_spaces > 3 or line[leading_spaces:].startswith("\t"):
        return None
    stripped = line.strip()
    cells: list[str] = []
    current: list[str] = []
    separators = 0
    for character in stripped:
        if character == "|":
            backslashes = 0
            for previous in reversed(current):
                if previous != "\\":
                    break
                backslashes += 1
            if backslashes % 2 == 0:
                cells.append("".join(current).strip())
                current = []
                separators += 1
                continue
        current.append(character)
    if separators == 0:
        return None
    cells.append("".join(current).strip())
    if cells and not cells[0]:
        cells.pop(0)
    if cells and not cells[-1]:
        cells.pop()
    return cells


def requirement_definitions(text: str) -> list[str]:
    lines = semantic_markdown(_frontmatter_body(text)).splitlines()
    definitions: list[str] = []
    index = 0
    while index < len(lines):
        bullet = REQUIREMENT_BULLET_RE.match(lines[index])
        if bullet is not None:
            definitions.append(bullet.group("requirement"))

        header = _split_requirement_table_row(lines[index])
        if (
            header is None
            or len(header) < 2
            or _normalized_requirement_header(header[0])
            not in REQUIREMENT_TABLE_HEADERS
            or not all(cell.strip() for cell in header)
            or index + 1 >= len(lines)
        ):
            index += 1
            continue

        separator = _split_requirement_table_row(lines[index + 1])
        if (
            separator is None
            or len(separator) != len(header)
            or not all(AUTHORITY_SEPARATOR_RE.fullmatch(cell) for cell in separator)
        ):
            index += 1
            continue

        index += 2
        while index < len(lines):
            row = _split_requirement_table_row(lines[index])
            if row is None or len(row) != len(header):
                break
            requirement = _requirement_table_id(row[0])
            if requirement is not None and any(cell.strip() for cell in row[1:]):
                definitions.append(requirement)
            index += 1
    return definitions


def _normalized_requirement_header(cell: str) -> str:
    normalized = cell.strip()
    if normalized.startswith("`") and normalized.endswith("`"):
        normalized = normalized[1:-1]
    return " ".join(normalized.lower().split())


def _requirement_table_id(cell: str) -> str | None:
    candidate = cell.strip()
    if candidate.startswith("`") and candidate.endswith("`"):
        candidate = candidate[1:-1].strip()
    return candidate if REQUIREMENT_ID_RE.fullmatch(candidate) else None


def _parse_frontmatter_text(
    text: str, label: str, errors: list[str]
) -> tuple[dict[str, str | list[str]], str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        errors.append(f"{label}: missing frontmatter")
        return {}, text
    try:
        end = next(
            index
            for index, line in enumerate(lines[1:], start=1)
            if line.strip() == "---"
        )
    except StopIteration:
        errors.append(f"{label}: unclosed frontmatter")
        return {}, text

    meta: dict[str, str | list[str]] = {}
    active_list: str | None = None
    for number, line in enumerate(lines[1:end], start=2):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith("  - "):
            if active_list is None:
                errors.append(f"{label}:{number}: list item has no key")
                continue
            value = line[4:].strip().strip("\"'")
            current = meta.setdefault(active_list, [])
            if not isinstance(current, list):
                errors.append(f"{label}:{number}: {active_list} is not a list")
                continue
            current.append(value)
            continue
        match = re.fullmatch(r"([a-z_][a-z0-9_]*):(?:\s*(.*))?", line)
        if match is None:
            errors.append(f"{label}:{number}: unsupported frontmatter syntax")
            active_list = None
            continue
        key, raw = match.groups()
        raw = (raw or "").strip()
        if key in meta:
            errors.append(f"{label}:{number}: duplicate frontmatter key {key}")
        if raw in {"", "[]"}:
            meta[key] = []
            active_list = key if raw == "" else None
        else:
            meta[key] = raw.strip("\"'")
            active_list = None
    return meta, "\n".join(lines[end + 1 :])


def parse_frontmatter(
    path: Path, errors: list[str]
) -> tuple[dict[str, str | list[str]], str]:
    return _parse_frontmatter_text(
        path.read_text(encoding="utf-8"), relative(path), errors
    )


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
            if path == readme:
                continue
            meta, body = parse_frontmatter(path, errors)
            documents.append(Document(path=path, layer=layer, body=body, meta=meta))
    return documents


def _require_list(
    doc: Document, key: str, errors: list[str], *, nonempty: bool = False
) -> list[str]:
    value = doc.meta.get(key)
    if not isinstance(value, list):
        errors.append(f"{relative(doc.path)}: {key} must be a YAML list")
        return []
    if nonempty and not value:
        errors.append(f"{relative(doc.path)}: {key} must not be empty")
    return value


def _require_controlled_list(
    doc: Document, key: str, errors: list[str], *, nonempty: bool = False
) -> list[str]:
    if key not in CONTROLLED_LIST_KEYS:
        raise ValueError(f"uncontrolled list key: {key}")
    values = _require_list(doc, key, errors, nonempty=nonempty)
    seen: set[str] = set()
    for value in values:
        if not isinstance(value, str) or not value.strip():
            errors.append(
                f"{relative(doc.path)}: {key} items must be non-blank strings"
            )
            continue
        normalized = value.strip()
        if normalized in seen:
            errors.append(f"{relative(doc.path)}: duplicate {key} item {normalized!r}")
        seen.add(normalized)
    return values


def _commit_is_ancestor(commit: str) -> bool:
    exists = subprocess.run(
        ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if exists.returncode != 0:
        return False
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", commit, "HEAD"],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return ancestor.returncode == 0


def _code_paths_at_commit(
    commit: str, implementation: Document
) -> tuple[list[str], str]:
    path = implementation.path.relative_to(ROOT).as_posix()
    object_name = f"{commit}:{path}"
    exists = subprocess.run(
        ["git", "cat-file", "-e", object_name],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if exists.returncode != 0:
        return implementation.values("code_paths"), ""

    historical = subprocess.run(
        ["git", "show", object_name],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if historical.returncode != 0:
        return [], historical.stderr.strip() or f"could not read {object_name}"
    history_errors: list[str] = []
    meta, _ = _parse_frontmatter_text(
        historical.stdout, f"{path}@{commit}", history_errors
    )
    value = meta.get("code_paths")
    if not isinstance(value, list):
        history_errors.append(f"{path}@{commit}: code_paths must be a YAML list")
        value = []
    return value, "; ".join(history_errors)


def _changed_paths_since(commit: str, paths: list[str]) -> tuple[list[str], str]:
    commands = [
        ["git", "diff", "--no-ext-diff", "--name-only", f"{commit}..HEAD"],
        ["git", "diff", "--no-ext-diff", "--name-only"],
        ["git", "diff", "--no-ext-diff", "--cached", "--name-only"],
        ["git", "ls-files", "--others", "--exclude-standard"],
    ]
    changed: set[str] = set()
    failures: list[str] = []
    for command in commands:
        comparison = subprocess.run(
            [*command, "--", *paths],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if comparison.returncode != 0:
            failures.append(comparison.stderr.strip() or "git comparison failed")
            continue
        changed.update(line for line in comparison.stdout.splitlines() if line)
    return sorted(changed), "; ".join(failures)


def _validate_code_paths(doc: Document, paths: list[str], errors: list[str]) -> None:
    for raw in paths:
        candidate = Path(raw)
        if candidate.is_absolute() or ".." in candidate.parts:
            errors.append(
                f"{relative(doc.path)}: code_path must be root-relative: {raw}"
            )
            continue
        if not (ROOT / candidate).exists():
            errors.append(f"{relative(doc.path)}: code_path does not exist: {raw}")


def _validate_external_upstream(doc: Document, errors: list[str]) -> None:
    if "external_upstream" not in doc.meta:
        return
    for value in _require_controlled_list(
        doc, "external_upstream", errors, nonempty=True
    ):
        match = EXTERNAL_UPSTREAM_RE.fullmatch(value)
        target = match.group(3) if match is not None else ""
        if (
            match is None
            or match.group(1) not in EXTERNAL_REPOS
            or not (
                ID_RE.fullmatch(target) or EXTERNAL_REQUIREMENT_ID_RE.fullmatch(target)
            )
        ):
            errors.append(
                f"{relative(doc.path)}: invalid external_upstream {value!r}; "
                "expected repo@40hex:formal-or-requirement-ID"
            )


def validate_metadata(
    documents: list[Document], errors: list[str]
) -> dict[str, Document]:
    by_id: dict[str, Document] = {}
    required = {"id", "layer", "title", "status", "owner", "upstream", "updated_at"}
    for doc in documents:
        label = relative(doc.path)
        missing = sorted(required - doc.meta.keys())
        if missing:
            errors.append(f"{label}: missing frontmatter keys: {', '.join(missing)}")

        title = doc.meta.get("title")
        if not isinstance(title, str) or not title.strip():
            errors.append(f"{label}: title must be a non-blank string")

        if doc.meta.get("layer") != doc.layer:
            errors.append(f"{label}: layer must be {doc.layer}")
        if not doc.id.startswith(PREFIXES[doc.layer]) or not ID_RE.fullmatch(doc.id):
            errors.append(f"{label}: invalid {doc.layer} id {doc.id!r}")
        elif doc.id in by_id:
            errors.append(
                f"{label}: duplicate id {doc.id} (also {relative(by_id[doc.id].path)})"
            )
        else:
            by_id[doc.id] = doc
        if doc.path.stem != doc.id:
            errors.append(f"{label}: filename must match id {doc.id!r}")

        status = doc.meta.get("status")
        if status not in ALLOWED_STATUS[doc.layer]:
            errors.append(f"{label}: invalid status {status!r} for {doc.layer}")
        owner = doc.meta.get("owner")
        if owner not in {"human", "agent"}:
            errors.append(f"{label}: owner must be human or agent")
        if doc.layer in {"intent", "spec"} and owner != "human":
            errors.append(f"{label}: intent/spec semantic owner must be human")

        role = doc.meta.get("role")
        if role is not None and role != "baseline":
            errors.append(f"{label}: role must be baseline when present")

        updated = doc.meta.get("updated_at")
        if not isinstance(updated, str) or not DATE_RE.fullmatch(updated):
            errors.append(f"{label}: updated_at must be YYYY-MM-DD")
        else:
            try:
                date.fromisoformat(updated)
            except ValueError:
                errors.append(f"{label}: updated_at is not a valid date")

        upstream = _require_controlled_list(doc, "upstream", errors)
        if doc.layer == "intent" and upstream:
            errors.append(f"{label}: intent must not have upstream references")
        if doc.layer != "intent" and not upstream:
            errors.append(
                f"{label}: {doc.layer} requires at least one upstream reference"
            )

        _validate_external_upstream(doc, errors)

        if doc.layer in {"design", "implementation"}:
            inactive = status in {"superseded", "retired"}
            tracks = _require_controlled_list(
                doc, "tracks", errors, nonempty=not inactive
            )
            for requirement in tracks:
                if not REQUIREMENT_ID_RE.fullmatch(requirement):
                    errors.append(
                        f"{label}: invalid requirement in tracks: {requirement}"
                    )

        if doc.layer == "implementation":
            if "observed_commit" in doc.meta or "verified_commit" in doc.meta:
                errors.append(
                    f"{label}: implementation must not store commit observations"
                )
            inactive = status == "retired"
            code_paths = _require_controlled_list(
                doc, "code_paths", errors, nonempty=not inactive
            )
            _require_controlled_list(doc, "evidence", errors, nonempty=not inactive)
            _validate_code_paths(doc, code_paths, errors)

        if doc.layer == "evidence":
            covers = _require_controlled_list(doc, "covers", errors, nonempty=True)
            scopes = _require_controlled_list(doc, "scope", errors, nonempty=True)
            _require_controlled_list(doc, "commands", errors, nonempty=True)
            unexpected_scopes = set(scopes) - EVIDENCE_SCOPES
            if unexpected_scopes:
                errors.append(
                    f"{label}: invalid evidence scope: "
                    f"{', '.join(sorted(unexpected_scopes))}"
                )
            for requirement in covers:
                if not REQUIREMENT_ID_RE.fullmatch(requirement):
                    errors.append(
                        f"{label}: invalid requirement in covers: {requirement}"
                    )
            result = doc.meta.get("result")
            if result not in EVIDENCE_RESULTS:
                errors.append(f"{label}: invalid evidence result {result!r}")
            commit = doc.meta.get("observed_commit")
            if not isinstance(commit, str) or not COMMIT_RE.fullmatch(commit):
                errors.append(
                    f"{label}: observed_commit must be a full 40-character SHA"
                )
            elif not _commit_is_ancestor(commit):
                errors.append(
                    f"{label}: observed_commit is not an ancestor of HEAD: {commit}"
                )
            artifacts = []
            if "artifacts" in doc.meta:
                artifacts = _require_list(doc, "artifacts", errors)
            only_temporary = bool(artifacts) and all(
                item == "/tmp" or item.startswith("/tmp/") for item in artifacts
            )
            if status == "active" and result == "passed" and only_temporary:
                errors.append(
                    f"{label}: active passed evidence must not rely only on /tmp artifacts"
                )
    return by_id


def validate_indexes(documents: list[Document], errors: list[str]) -> None:
    for layer, directory in LAYER_DIRS.items():
        readme = directory / "README.md"
        if not readme.is_file():
            continue
        links = []
        index_body = semantic_markdown(readme.read_text(encoding="utf-8"))
        for raw_target in LINK_RE.findall(index_body):
            target = raw_target.strip().split(maxsplit=1)[0].strip("<>")
            target = unquote(target.split("#", maxsplit=1)[0])
            resolved = (readme.parent / target).resolve()
            if resolved.parent == directory.resolve() and resolved.suffix == ".md":
                links.append(resolved)
        counts = Counter(links)
        expected = {doc.path.resolve() for doc in documents if doc.layer == layer}
        for path in sorted(expected):
            count = counts[path]
            if count == 0:
                errors.append(
                    f"{relative(readme)}: missing formal document {path.name}"
                )
            elif count > 1:
                errors.append(
                    f"{relative(readme)}: duplicate formal document {path.name}"
                )


def _split_table_row(line: str) -> list[str] | None:
    stripped = line.strip()
    if not stripped.startswith("|") or not stripped.endswith("|"):
        return None
    return [cell.strip() for cell in stripped[1:-1].split("|")]


def _normalized_header(cells: list[str]) -> tuple[str, ...]:
    return tuple(" ".join(cell.lower().split()) for cell in cells)


def _authority_rows(
    doc: Document, errors: list[str]
) -> list[tuple[str, str, str, str]]:
    lines = semantic_markdown(doc.body).splitlines()
    header_indexes = []
    for index, line in enumerate(lines):
        cells = _split_table_row(line)
        if cells is not None and _normalized_header(cells) == AUTHORITY_HEADER:
            header_indexes.append(index)

    if len(header_indexes) != 1:
        errors.append(
            f"{relative(doc.path)}: requires exactly one authority table header; "
            f"found {len(header_indexes)}"
        )
    if not header_indexes:
        return []

    header_index = header_indexes[0]
    if header_index + 1 >= len(lines):
        errors.append(
            f"{relative(doc.path)}: authority table header must be followed by "
            "a valid Markdown separator"
        )
        return []
    separator = _split_table_row(lines[header_index + 1])
    if (
        separator is None
        or len(separator) != len(AUTHORITY_HEADER)
        or not all(AUTHORITY_SEPARATOR_RE.fullmatch(cell) for cell in separator)
    ):
        errors.append(
            f"{relative(doc.path)}: authority table header must be followed by "
            "a valid Markdown separator"
        )
        return []

    rows: list[tuple[str, str, str, str]] = []
    for number, line in enumerate(lines[header_index + 2 :], start=header_index + 3):
        cells = _split_table_row(line)
        if cells is None:
            break
        if len(cells) != len(AUTHORITY_HEADER):
            errors.append(
                f"{relative(doc.path)}:{number}: authority row must have four columns"
            )
            continue
        requirement, design_id, state, support = cells
        if requirement.startswith("`") and requirement.endswith("`"):
            requirement = requirement[1:-1].strip()
        if design_id.startswith("`") and design_id.endswith("`"):
            design_id = design_id[1:-1].strip()
        if (
            not REQUIREMENT_ID_RE.fullmatch(requirement)
            or not design_id.startswith("DES-")
            or not ID_RE.fullmatch(design_id)
            or state not in {"aligned", "diverged", "unknown"}
        ):
            errors.append(f"{relative(doc.path)}:{number}: invalid authority row")
            continue
        rows.append((requirement, design_id, state, support))
    return rows


def validate_graph(
    documents: list[Document], by_id: dict[str, Document], errors: list[str]
) -> tuple[dict[str, Document], Counter[str]]:
    requirements: dict[str, Document] = {}
    for doc in documents:
        if doc.layer != "spec":
            continue
        for requirement in requirement_definitions(doc.body):
            previous = requirements.get(requirement)
            if previous is None:
                requirements[requirement] = doc
            elif previous.path == doc.path:
                errors.append(
                    f"{relative(doc.path)}: duplicate requirement {requirement} "
                    "in the same spec"
                )
            else:
                errors.append(
                    f"{relative(doc.path)}: requirement {requirement} also belongs to "
                    f"{relative(previous.path)}"
                )

    for doc in documents:
        expected = UPSTREAM_LAYER[doc.layer]
        upstream_docs: list[Document] = []
        for upstream_id in doc.values("upstream"):
            upstream = by_id.get(upstream_id)
            if upstream is None:
                errors.append(
                    f"{relative(doc.path)}: unknown upstream id {upstream_id}"
                )
                continue
            if upstream.layer != expected:
                errors.append(
                    f"{relative(doc.path)}: upstream {upstream_id} must be in "
                    f"{expected}, not {upstream.layer}"
                )
                continue
            upstream_docs.append(upstream)

        status = doc.meta.get("status")
        if doc.layer == "spec" and status == "approved":
            for upstream in upstream_docs:
                if upstream.meta.get("status") != "approved":
                    errors.append(
                        f"{relative(doc.path)}: approved spec requires approved intent {upstream.id}"
                    )

        if doc.layer == "design":
            allowed = {
                requirement
                for upstream in upstream_docs
                for requirement in requirement_definitions(upstream.body)
            }
            unexpected = set(doc.values("tracks")) - allowed
            if unexpected:
                errors.append(
                    f"{relative(doc.path)}: tracks not declared by upstream specs: "
                    f"{', '.join(sorted(unexpected))}"
                )

        if doc.layer == "implementation":
            allowed = {
                requirement
                for upstream in upstream_docs
                for requirement in upstream.values("tracks")
            }
            unexpected = set(doc.values("tracks")) - allowed
            if unexpected:
                errors.append(
                    f"{relative(doc.path)}: tracks not covered by upstream design: "
                    f"{', '.join(sorted(unexpected))}"
                )
            for evidence_id in doc.values("evidence"):
                evidence = by_id.get(evidence_id)
                if evidence is None or evidence.layer != "evidence":
                    errors.append(
                        f"{relative(doc.path)}: unknown evidence id {evidence_id}"
                    )
                elif doc.id not in evidence.values("upstream"):
                    errors.append(
                        f"{relative(doc.path)}: evidence {evidence_id} does not link back to {doc.id}"
                    )

        if doc.layer == "evidence":
            if status == "active":
                for upstream in upstream_docs:
                    if upstream.meta.get("status") == "retired":
                        errors.append(
                            f"{relative(doc.path)}: active evidence cannot reference retired {upstream.id}"
                        )
            historical_pointer = (
                status == "superseded"
                and bool(upstream_docs)
                and all(
                    upstream.meta.get("status") == "retired"
                    for upstream in upstream_docs
                )
            )
            if not historical_pointer:
                allowed = {
                    requirement
                    for upstream in upstream_docs
                    for requirement in upstream.values("tracks")
                }
                unexpected = set(doc.values("covers")) - allowed
                if unexpected:
                    errors.append(
                        f"{relative(doc.path)}: covers not tracked by upstream implementation: "
                        f"{', '.join(sorted(unexpected))}"
                    )
            for implementation in upstream_docs:
                if doc.id not in implementation.values("evidence"):
                    errors.append(
                        f"{relative(doc.path)}: implementation {implementation.id} "
                        f"does not link back to {doc.id}"
                    )
            commit = doc.meta.get("observed_commit")
            if (
                status == "active"
                and doc.meta.get("result") == "passed"
                and isinstance(commit, str)
                and COMMIT_RE.fullmatch(commit)
                and _commit_is_ancestor(commit)
            ):
                for implementation in upstream_docs:
                    observed_paths, history_error = _code_paths_at_commit(
                        commit, implementation
                    )
                    if history_error:
                        errors.append(
                            f"{relative(doc.path)}: could not load {implementation.id} "
                            f"code_paths at {commit}: {history_error}"
                        )
                        continue
                    code_paths = [
                        raw
                        for raw in observed_paths
                        if raw.strip()
                        and not Path(raw).is_absolute()
                        and ".." not in Path(raw).parts
                    ]
                    if not code_paths:
                        continue
                    changed_paths, comparison_error = _changed_paths_since(
                        commit, code_paths
                    )
                    if comparison_error:
                        errors.append(
                            f"{relative(doc.path)}: could not compare {implementation.id} "
                            f"code_paths at {commit}: {comparison_error}"
                        )
                    elif changed_paths:
                        errors.append(
                            f"{relative(doc.path)}: active passed evidence is stale for "
                            f"{implementation.id}; code_paths changed after {commit}: "
                            f"{', '.join(changed_paths)}"
                        )

    authority_rows: dict[str, list[tuple[Document, str, str, str]]] = {}
    for doc in documents:
        if doc.layer != "implementation" or doc.meta.get("status") == "retired":
            continue
        rows = _authority_rows(doc, errors)
        row_requirements = [row[0] for row in rows]
        duplicates = sorted(
            requirement
            for requirement, count in Counter(row_requirements).items()
            if count > 1
        )
        if duplicates:
            errors.append(
                f"{relative(doc.path)}: duplicate authority rows: {', '.join(duplicates)}"
            )
        tracks = set(doc.values("tracks"))
        missing_rows = tracks - set(row_requirements)
        unexpected_rows = set(row_requirements) - tracks
        if missing_rows:
            errors.append(
                f"{relative(doc.path)}: tracks without authority rows: "
                f"{', '.join(sorted(missing_rows))}"
            )
        if unexpected_rows:
            errors.append(
                f"{relative(doc.path)}: authority rows not declared in tracks: "
                f"{', '.join(sorted(unexpected_rows))}"
            )

        states = {row[2] for row in rows}
        expected_status = (
            "diverged"
            if "diverged" in states
            else "unknown"
            if "unknown" in states
            else "aligned"
        )
        if rows and doc.meta.get("status") != expected_status:
            errors.append(
                f"{relative(doc.path)}: status must be {expected_status} for its authority rows"
            )

        for requirement, design_id, state, support in rows:
            authority_rows.setdefault(requirement, []).append(
                (doc, design_id, state, support)
            )
            design = by_id.get(design_id)
            if design_id not in doc.values("upstream"):
                errors.append(
                    f"{relative(doc.path)}: authority design {design_id} is not an upstream"
                )
            if design is None or design.layer != "design":
                errors.append(
                    f"{relative(doc.path)}: unknown authority design {design_id}"
                )
            elif design.meta.get("status") not in {
                "active",
                "blocked",
            } or requirement not in design.values("tracks"):
                errors.append(
                    f"{relative(doc.path)}: authority design {design_id} does not currently track {requirement}"
                )

            evidence_ids = sorted(set(EVIDENCE_ID_RE.findall(support)))
            if state == "aligned":
                valid_support = []
                for evidence_id in evidence_ids:
                    evidence = by_id.get(evidence_id)
                    if (
                        evidence is not None
                        and evidence.layer == "evidence"
                        and evidence.meta.get("status") == "active"
                        and evidence.meta.get("result") == "passed"
                        and requirement in evidence.values("covers")
                        and doc.id in evidence.values("upstream")
                        and evidence_id in doc.values("evidence")
                    ):
                        valid_support.append(evidence_id)
                if not valid_support:
                    errors.append(
                        f"{relative(doc.path)}: aligned authority {requirement} requires "
                        "active passed evidence"
                    )
            elif not re.search(r"\bgap:\s*\S", support):
                errors.append(
                    f"{relative(doc.path)}: {state} authority {requirement} requires an explicit gap:"
                )

    authority_results: Counter[str] = Counter()
    approved_requirements = {
        requirement
        for requirement, spec in requirements.items()
        if spec.meta.get("status") == "approved"
    }
    for requirement in sorted(approved_requirements):
        active_designs = [
            doc
            for doc in documents
            if doc.layer == "design"
            and doc.meta.get("status") in {"active", "blocked"}
            and requirement in doc.values("tracks")
        ]
        if len(active_designs) != 1:
            errors.append(
                "approved requirement requires exactly one current design: "
                f"{requirement} has {len(active_designs)}"
            )

        rows = authority_rows.get(requirement, [])
        if len(rows) != 1:
            errors.append(
                f"approved requirement requires exactly one current authority row: "
                f"{requirement} has {len(rows)}"
            )
            continue
        authority_results[rows[0][2]] += 1
    return requirements, authority_results


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
                errors.append(
                    f"{relative(path)}: missing governance reference {needle!r}"
                )


def check() -> int:
    errors: list[str] = []
    validate_governance(errors)
    documents = formal_documents(errors)
    by_id = validate_metadata(documents, errors)
    validate_indexes(documents, errors)
    requirements, authority_results = validate_graph(documents, by_id, errors)
    link_count = validate_links(errors)

    if errors:
        print("knowledge-check: FAILED", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    result_summary = ", ".join(
        f"{name}={authority_results[name]}"
        for name in ("aligned", "diverged", "unknown")
    )
    print(
        "knowledge-check: OK "
        f"({len(documents)} formal documents, {len(requirements)} requirements, "
        f"{link_count} local links; {result_summary})"
    )
    return 0


def main(argv: list[str]) -> int:
    if argv != ["check"]:
        print("usage: python3 tools/knowledge_base.py check", file=sys.stderr)
        return 2
    return check()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
