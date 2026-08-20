#!/usr/bin/env python3
"""Regenerate the Dart gateway SDK from the sibling backend .api file.

goctl api dart only emits GET/POST helpers. This script:
1. runs goctl into a temp directory
2. patches PUT/DELETE verbs from gateway.api
3. fixes known goctl Dart type bugs
4. copies generated types and API methods into vendor/sdk_source and lib/sdk

Application-owned transport files are not overwritten:
  api/api.dart, data/tokens.dart, vars/*
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HANDLER_RE = re.compile(r"@handler\s+(\w+)")
ROUTE_RE = re.compile(
    r"^\s*(get|post|put|delete|patch)\s+(\S+)", re.IGNORECASE
)
FUNC_RE = re.compile(r"^Future (\w+)\(")
INT_FROM_JSON_RE = re.compile(r"int\?\.fromJson\(m\['(\w+)'\]\)")
OPTIONAL_NUM_TO_JSON_RE = re.compile(
    r"\b(position|durationMs|status)\?\.toJson\(\)"
)
ENTITY_ID_FIELDS = (
    "id",
    "postId",
    "authorId",
    "userId",
    "targetId",
    "commentId",
    "parentId",
    "replyUserId",
    "mediaId",
    "conversationId",
    "senderId",
    "receiverId",
    "followeeId",
    "targetUserId",
    "cursorPostId",
    "nextCursorPostId",
    "messageId",
    "lastId",
    "eventId",
)
PATH_ID_PARAMS = ("postId", "userId", "commentId", "id")

VERB_TO_HELPER = {
    "put": "apiPut",
    "delete": "apiDelete",
    "patch": "apiPatch",
}


def parse_handler_verbs(api_path: Path) -> dict[str, str]:
    verbs: dict[str, str] = {}
    pending: str | None = None
    for raw in api_path.read_text(encoding="utf-8").splitlines():
        handler = HANDLER_RE.search(raw)
        if handler:
            pending = handler.group(1)
            continue
        if pending is None:
            continue
        route = ROUTE_RE.search(raw)
        if not route:
            continue
        func = pending[0].lower() + pending[1:]
        verbs[func] = route.group(1).lower()
        pending = None
    return verbs


def patch_gateway_methods(source: str, verbs: dict[str, str]) -> str:
    lines = source.splitlines(keepends=True)
    current: str | None = None
    out: list[str] = []
    for line in lines:
        match = FUNC_RE.match(line)
        if match:
            current = match.group(1)
        helper = VERB_TO_HELPER.get(verbs.get(current, ""))
        if helper and "await apiPost(" in line:
            line = line.replace("await apiPost(", f"await {helper}(")
        out.append(line)
    return "".join(out)


def patch_generated_types(source: str) -> str:
    source = INT_FROM_JSON_RE.sub(
        r"(m['\1'] is num) ? (m['\1'] as num).toInt() : null",
        source,
    )
    source = OPTIONAL_NUM_TO_JSON_RE.sub(r"\1", source)
    for field in ENTITY_ID_FIELDS:
        source = source.replace(f"final num {field};", f"final Object {field};")
    source = source.replace("final List<int> mediaIds;", "final List<Object> mediaIds;")
    source = source.replace(
        "mediaIds: m['mediaIds']?.cast<int>() ?? [],",
        "mediaIds: m['mediaIds'] is List\n"
        "          ? List<Object>.from(m['mediaIds'] as List)\n"
        "          : <Object>[],",
    )
    return source


def patch_generated_api(source: str) -> str:
    for field in PATH_ID_PARAMS:
        source = source.replace(f"  int {field},", f"  Object {field},")
        source = source.replace(f"  int {field}", f"  Object {field}")
    return source


def copy_generated(src_root: Path, dest_root: Path, files: list[str]) -> None:
    for rel in files:
        src = src_root / rel
        dest = dest_root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dest)


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--api",
        default=str(
            repo.parent.parent
            / "little-white-box-content-community"
            / "app"
            / "gateway"
            / "gateway.api"
        ),
        help="Path to backend gateway.api",
    )
    args = parser.parse_args()
    api_path = Path(args.api).resolve()
    if not api_path.is_file():
        print(f"gateway.api not found: {api_path}", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="xbh-goctl-dart-") as tmp:
        generated = Path(tmp)
        cmd = [
            "goctl",
            "api",
            "dart",
            "--api",
            str(api_path),
            "--dir",
            str(generated),
        ]
        print(" ".join(cmd))
        subprocess.run(cmd, check=True)

        verbs = parse_handler_verbs(api_path)
        gateway_api = patch_generated_api(
            patch_gateway_methods(
                (generated / "api" / "gateway.dart").read_text(encoding="utf-8"),
                verbs,
            )
        )
        (generated / "api" / "gateway.dart").write_text(
            gateway_api, encoding="utf-8"
        )
        types = patch_generated_types(
            (generated / "data" / "gateway.dart").read_text(encoding="utf-8")
        )
        (generated / "data" / "gateway.dart").write_text(types, encoding="utf-8")

        generated_files = ["api/gateway.dart", "data/gateway.dart"]
        copy_generated(generated, repo / "vendor" / "sdk_source", generated_files)
        copy_generated(generated, repo / "lib" / "sdk", generated_files)

        patched = sorted(
            name for name, verb in verbs.items() if verb in VERB_TO_HELPER
        )
        print("synced generated SDK files:")
        for rel in generated_files:
            print(f"  {rel}")
        print("patched HTTP helpers:")
        for name in patched:
            print(f"  {name} -> {VERB_TO_HELPER[verbs[name]]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
