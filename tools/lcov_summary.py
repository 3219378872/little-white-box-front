#!/usr/bin/env python3
"""Summarize a lcov.info tracefile produced by `flutter test --coverage`.

Prints overall line coverage plus a per-source-file table sorted by
uncovered lines so the largest gaps are visible at a glance.
"""

from __future__ import annotations

import argparse
import pathlib
import sys


def parse_lcov(path: pathlib.Path) -> list[dict]:
    records = []
    current: dict | None = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line == "end_of_record":
            if current is not None:
                records.append(current)
                current = None
            continue
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        if key == "SF":
            current = {"source": value, "hit": 0, "found": 0}
        elif key == "LF" and current is not None:
            current["found"] = int(value)
        elif key == "LH" and current is not None:
            current["hit"] = int(value)
    return records


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tracefile", type=pathlib.Path, help="path to lcov.info")
    parser.add_argument(
        "--top",
        type=int,
        default=15,
        help="how many worst-covered files to list (0 disables)",
    )
    args = parser.parse_args()

    if not args.tracefile.is_file():
        print(f"lcov tracefile not found: {args.tracefile}", file=sys.stderr)
        return 1

    records = parse_lcov(args.tracefile)
    total_found = sum(r["found"] for r in records)
    total_hit = sum(r["hit"] for r in records)
    pct = (100.0 * total_hit / total_found) if total_found else 100.0
    print(f"total: {total_hit}/{total_found} lines ({pct:.1f}%)")

    if args.top > 0:
        gaps = [r for r in records if r["found"] - r["hit"] > 0]
        gaps.sort(key=lambda r: r["found"] - r["hit"], reverse=True)
        if gaps:
            print("\nworst covered files:")
            for r in gaps[: args.top]:
                missed = r["found"] - r["hit"]
                file_pct = 100.0 * r["hit"] / r["found"]
                print(f"  {missed:5d} missed  {file_pct:5.1f}%  {r['source']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
