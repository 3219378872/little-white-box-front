import os
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from knowledge_base import requirement_definitions


CHECKER = Path(__file__).with_name("knowledge_base.py")


class KnowledgeBaseFixtureTest(unittest.TestCase):
    def setUp(self):
        self.temporary = TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self._write("AGENTS.md", "docs/knowledge/README.md\nmake knowledge-check\n")
        self._write("README.md", "docs/knowledge/README.md\nmake knowledge-check\n")
        self._write(
            "Makefile", "knowledge-check:\n\tpython3 tools/knowledge_base.py check\n"
        )
        self._write("docs/knowledge/README.md", "# Router\n")
        self._write("docs/knowledge/archive/README.md", "# Archive\n")
        self._write("docs/knowledge/templates/README.md", "# Templates\n")
        self._write("lib/app.dart", "void main() {}\n")
        self._git("init")
        self._git("config", "user.name", "Knowledge Test")
        self._git("config", "user.email", "knowledge@example.test")
        self._git("add", "lib/app.dart")
        self._git("commit", "-m", "fixture source")
        self.commit = self._git("rev-parse", "HEAD").stdout.strip()
        self._write_valid_graph()

    def tearDown(self):
        self.temporary.cleanup()

    def _write(self, relative: str, contents: str):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")

    def _git(self, *args: str):
        return subprocess.run(
            ["git", *args],
            cwd=self.root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )

    def _write_valid_graph(self):
        docs = {
            "intent/INT-client.md": """---
id: INT-client
layer: intent
title: Client
status: approved
owner: human
upstream: []
updated_at: 2026-09-06
---
# Client
""",
            "spec/SPEC-client.md": """---
id: SPEC-client
layer: spec
title: Client spec
status: approved
owner: human
upstream:
  - INT-client
updated_at: 2026-09-06
---
# Client spec

- `FX-001`: Works.
""",
            "design/DES-client.md": """---
id: DES-client
layer: design
title: Client design
status: active
role: baseline
owner: agent
upstream:
  - SPEC-client
tracks:
  - FX-001
updated_at: 2026-09-06
---
# Client design
""",
            "implementation/IMP-client.md": """---
id: IMP-client
layer: implementation
title: Client implementation
status: aligned
owner: agent
upstream:
  - DES-client
tracks:
  - FX-001
code_paths:
  - lib/app.dart
evidence:
  - EVD-client-2026-09-06
updated_at: 2026-09-06
---
# Client implementation

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-001 | DES-client | aligned | EVD-client-2026-09-06 |
""",
            "evidence/EVD-client-2026-09-06.md": f"""---
id: EVD-client-2026-09-06
layer: evidence
title: Client evidence
status: active
result: passed
owner: agent
upstream:
  - IMP-client
covers:
  - FX-001
scope:
  - unit
commands:
  - make test
observed_commit: {self.commit}
updated_at: 2026-09-06
---
# Client evidence
""",
        }
        for relative, contents in docs.items():
            self._write(f"docs/knowledge/{relative}", contents)
        for layer in ("intent", "spec", "design", "implementation", "evidence"):
            files = sorted((self.root / "docs/knowledge" / layer).glob("*.md"))
            links = "\n".join(
                f"- [{path.stem}]({path.name})"
                for path in files
                if path.name != "README.md"
            )
            self._write(f"docs/knowledge/{layer}/README.md", f"# {layer}\n\n{links}\n")

    def _run(self):
        env = dict(os.environ)
        env["KNOWLEDGE_ROOT"] = str(self.root)
        return subprocess.run(
            [sys.executable, str(CHECKER), "check"],
            cwd=self.root,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def _replace(self, relative: str, old: str, new: str):
        path = self.root / relative
        path.write_text(
            path.read_text(encoding="utf-8").replace(old, new), encoding="utf-8"
        )

    def _append(self, relative: str, contents: str):
        path = self.root / relative
        path.write_text(path.read_text(encoding="utf-8") + contents, encoding="utf-8")

    def test_accepts_complete_graph_and_baseline_role(self):
        result = self._run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("aligned=1", result.stdout)

    def test_rejects_missing_layer_index_entry(self):
        self._write("docs/knowledge/design/README.md", "# design\n")
        result = self._run()
        self.assertIn("missing formal document DES-client.md", result.stderr)

    def test_rejects_nested_readme_as_an_unindexed_formal_document(self):
        self._write(
            "docs/knowledge/evidence/nested/README.md",
            f"""---
id: EVD-hidden-2026-09-06
layer: evidence
title: Hidden evidence
status: active
result: passed
owner: agent
upstream:
  - IMP-client
covers:
  - FX-001
scope:
  - unit
commands:
  - make test
observed_commit: {self.commit}
updated_at: 2026-09-06
---
# Hidden evidence
""",
        )

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "docs/knowledge/evidence/nested/README.md: filename must match id "
            "'EVD-hidden-2026-09-06'",
            result.stderr,
        )
        self.assertIn("missing formal document README.md", result.stderr)

    def test_rejects_superseded_only_coverage(self):
        self._replace(
            "docs/knowledge/evidence/EVD-client-2026-09-06.md",
            "status: active",
            "status: superseded",
        )
        result = self._run()
        self.assertIn(
            "aligned authority FX-001 requires active passed evidence", result.stderr
        )

    def test_rejects_short_or_unknown_observed_commit(self):
        path = "docs/knowledge/evidence/EVD-client-2026-09-06.md"
        self._replace(path, self.commit, self.commit[:7])
        result = self._run()
        self.assertIn("full 40-character SHA", result.stderr)

        self._replace(path, self.commit[:7], "f" * 40)
        result = self._run()
        self.assertIn("not an ancestor of HEAD", result.stderr)

    def test_rejects_missing_evidence_scope_and_result(self):
        path = "docs/knowledge/evidence/EVD-client-2026-09-06.md"
        self._replace(path, "result: passed\n", "")
        self._replace(path, "scope:\n  - unit\n", "")
        result = self._run()
        self.assertIn("scope must be a YAML list", result.stderr)
        self.assertIn("invalid evidence result", result.stderr)

    def test_validates_external_upstream_shape(self):
        path = "docs/knowledge/design/DES-client.md"
        formal = (
            "external_upstream:\n"
            f"  - little-white-box-content-community@{self.commit}:SPEC-community-core\n"
        )
        self._replace(path, "tracks:\n", formal + "tracks:\n")
        self.assertEqual(self._run().returncode, 0)

        self._replace(path, ":SPEC-community-core", ":AGENT-A01")
        self.assertEqual(self._run().returncode, 0)

        self._replace(path, ":AGENT-A01", ":REL-054-01")
        self.assertEqual(self._run().returncode, 0)

        self._replace(path, ":REL-054-01", ":not-a-contract-id")
        result = self._run()
        self.assertIn("invalid external_upstream", result.stderr)

        self._replace(path, ":not-a-contract-id", ":SPEC-community-core")
        self._replace(path, "little-white-box-content-community@", "backend@")
        result = self._run()
        self.assertIn("invalid external_upstream", result.stderr)

        self._replace(
            path,
            f"external_upstream:\n  - backend@{self.commit}:SPEC-community-core\n",
            "external_upstream: []\n",
        )
        result = self._run()
        self.assertIn("external_upstream must not be empty", result.stderr)

    def test_allows_superseded_evidence_on_retired_pointer(self):
        self._write(
            "docs/knowledge/implementation/IMP-history.md",
            """---
id: IMP-history
layer: implementation
title: Historical pointer
status: retired
owner: agent
upstream:
  - DES-client
tracks: []
code_paths: []
evidence:
  - EVD-history-2026-09-06
updated_at: 2026-09-06
---
# Historical pointer
""",
        )
        self._write(
            "docs/knowledge/evidence/EVD-history-2026-09-06.md",
            f"""---
id: EVD-history-2026-09-06
layer: evidence
title: Historical evidence
status: superseded
result: passed
owner: agent
upstream:
  - IMP-history
covers:
  - FX-001
scope:
  - unit
commands:
  - make test
observed_commit: {self.commit}
updated_at: 2026-09-06
---
# Historical evidence
""",
        )
        self._write(
            "docs/knowledge/implementation/README.md",
            "# implementation\n\n"
            "- [IMP-client](IMP-client.md)\n"
            "- [IMP-history](IMP-history.md)\n",
        )
        self._write(
            "docs/knowledge/evidence/README.md",
            "# evidence\n\n"
            "- [EVD-client-2026-09-06](EVD-client-2026-09-06.md)\n"
            "- [EVD-history-2026-09-06](EVD-history-2026-09-06.md)\n",
        )
        self.assertEqual(self._run().returncode, 0)

    def test_rejects_duplicate_current_implementation_authority(self):
        original = self.root / "docs/knowledge/implementation/IMP-client.md"
        duplicate = original.read_text(encoding="utf-8").replace(
            "IMP-client", "IMP-client-copy"
        )
        self._write("docs/knowledge/implementation/IMP-client-copy.md", duplicate)
        self._write(
            "docs/knowledge/implementation/README.md",
            "# implementation\n\n"
            "- [IMP-client](IMP-client.md)\n"
            "- [IMP-client-copy](IMP-client-copy.md)\n",
        )
        result = self._run()
        self.assertIn("FX-001 has 2", result.stderr)

    def test_rejects_duplicate_requirement_in_one_spec(self):
        self._replace(
            "docs/knowledge/spec/SPEC-client.md",
            "- `FX-001`: Works.",
            "- `FX-001`: Works.\n- `FX-001`: Declared twice.",
        )

        result = self._run()

        self.assertIn("duplicate requirement FX-001 in the same spec", result.stderr)

    def test_rejects_duplicate_current_design_for_approved_requirement(self):
        original = self.root / "docs/knowledge/design/DES-client.md"
        duplicate = original.read_text(encoding="utf-8").replace(
            "DES-client", "DES-client-copy"
        )
        self._write("docs/knowledge/design/DES-client-copy.md", duplicate)
        self._write(
            "docs/knowledge/design/README.md",
            "# design\n\n"
            "- [DES-client](DES-client.md)\n"
            "- [DES-client-copy](DES-client-copy.md)\n",
        )

        result = self._run()

        self.assertIn(
            "approved requirement requires exactly one current design: FX-001 has 2",
            result.stderr,
        )

    def test_requires_explicit_gap_for_unknown_or_diverged_authority(self):
        path = "docs/knowledge/implementation/IMP-client.md"
        self._replace(path, "status: aligned", "status: unknown")
        self._replace(
            path,
            "| FX-001 | DES-client | aligned | EVD-client-2026-09-06 |",
            "| FX-001 | DES-client | unknown | no current evidence |",
        )
        result = self._run()
        self.assertIn(
            "unknown authority FX-001 requires an explicit gap:", result.stderr
        )

        self._replace(path, "no current evidence", "gap: live provider not run")
        self.assertEqual(self._run().returncode, 0)

    def test_rejects_active_passed_evidence_with_only_tmp_artifacts(self):
        path = "docs/knowledge/evidence/EVD-client-2026-09-06.md"
        self._replace(
            path,
            "commands:\n  - make test\n",
            "commands:\n  - make test\nartifacts:\n  - /tmp/result.json\n",
        )
        result = self._run()
        self.assertIn("must not rely only on /tmp artifacts", result.stderr)

    def test_rejects_active_passed_evidence_after_covered_code_changes(self):
        self._write("lib/app.dart", "void main() { print('changed'); }\n")
        self._git("add", "lib/app.dart")
        self._git("commit", "-m", "change covered source")

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("stale", result.stderr)
        self.assertIn("code_paths", result.stderr)
        self.assertIn("lib/app.dart", result.stderr)

    def test_rejects_dirty_tracked_code_path(self):
        self._write("lib/app.dart", "void main() { print('dirty'); }\n")

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("stale", result.stderr)
        self.assertIn("code_paths", result.stderr)
        self.assertIn("lib/app.dart", result.stderr)

    def test_rejects_staged_code_path(self):
        self._write("lib/app.dart", "void main() { print('staged'); }\n")
        self._git("add", "lib/app.dart")

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("stale", result.stderr)
        self.assertIn("code_paths", result.stderr)
        self.assertIn("lib/app.dart", result.stderr)

    def test_rejects_untracked_file_under_code_path(self):
        self._replace(
            "docs/knowledge/implementation/IMP-client.md",
            "code_paths:\n  - lib/app.dart",
            "code_paths:\n  - lib",
        )
        self._write("lib/new_feature.dart", "void newFeature() {}\n")

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("stale", result.stderr)
        self.assertIn("code_paths", result.stderr)
        self.assertIn("lib/new_feature.dart", result.stderr)

    def test_allows_knowledge_only_changes_after_observed_commit(self):
        self._git(
            "add",
            "docs/knowledge/implementation/IMP-client.md",
            "docs/knowledge/evidence/EVD-client-2026-09-06.md",
        )
        self._git("commit", "-m", "record implementation and evidence")

        result = self._run()

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_allows_dirty_implementation_and_evidence_docs(self):
        implementation = "docs/knowledge/implementation/IMP-client.md"
        evidence = "docs/knowledge/evidence/EVD-client-2026-09-06.md"
        self._git("add", implementation, evidence)
        self._git("commit", "-m", "record knowledge docs")
        self._append(implementation, "\nImplementation note.\n")
        self._append(evidence, "\nEvidence note.\n")
        self._git("add", implementation)

        result = self._run()

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_blank_title_commands_and_code_paths(self):
        cases = (
            (
                "title",
                "docs/knowledge/evidence/EVD-client-2026-09-06.md",
                "title: Client evidence",
                'title: ""',
            ),
            (
                "commands",
                "docs/knowledge/evidence/EVD-client-2026-09-06.md",
                "commands:\n  - make test",
                "commands:\n  - '   '",
            ),
            (
                "code_paths",
                "docs/knowledge/implementation/IMP-client.md",
                "code_paths:\n  - lib/app.dart",
                "code_paths:\n  - '   '",
            ),
        )
        for field, path, original, invalid in cases:
            with self.subTest(field=field):
                self._replace(path, original, invalid)
                try:
                    result = self._run()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(field, result.stderr)
                finally:
                    self._replace(path, invalid, original)

    def test_rejects_duplicate_items_in_controlled_lists(self):
        external = (
            f"little-white-box-content-community@{self.commit}:SPEC-community-core"
        )
        cases = (
            (
                "upstream",
                "docs/knowledge/design/DES-client.md",
                "upstream:\n  - SPEC-client",
                "upstream:\n  - SPEC-client\n  - SPEC-client",
            ),
            (
                "tracks",
                "docs/knowledge/design/DES-client.md",
                "tracks:\n  - FX-001",
                "tracks:\n  - FX-001\n  - FX-001",
            ),
            (
                "code_paths",
                "docs/knowledge/implementation/IMP-client.md",
                "code_paths:\n  - lib/app.dart",
                "code_paths:\n  - lib/app.dart\n  - lib/app.dart",
            ),
            (
                "evidence",
                "docs/knowledge/implementation/IMP-client.md",
                "evidence:\n  - EVD-client-2026-09-06",
                "evidence:\n  - EVD-client-2026-09-06\n  - EVD-client-2026-09-06",
            ),
            (
                "covers",
                "docs/knowledge/evidence/EVD-client-2026-09-06.md",
                "covers:\n  - FX-001",
                "covers:\n  - FX-001\n  - FX-001",
            ),
            (
                "scope",
                "docs/knowledge/evidence/EVD-client-2026-09-06.md",
                "scope:\n  - unit",
                "scope:\n  - unit\n  - unit",
            ),
            (
                "commands",
                "docs/knowledge/evidence/EVD-client-2026-09-06.md",
                "commands:\n  - make test",
                "commands:\n  - make test\n  - make test",
            ),
            (
                "external_upstream",
                "docs/knowledge/design/DES-client.md",
                "tracks:",
                f"external_upstream:\n  - {external}\n  - {external}\ntracks:",
            ),
        )
        for field, path, original, invalid in cases:
            with self.subTest(field=field):
                self._replace(path, original, invalid)
                try:
                    result = self._run()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(field, result.stderr)
                finally:
                    self._replace(path, invalid, original)

    def test_ignores_requirements_in_fences_and_html_comments(self):
        self._append(
            "docs/knowledge/spec/SPEC-client.md",
            """

```markdown
- `FX-001`: Fenced example.
```

~~~markdown
- `FX-001`: Alternate fenced example.
~~~

<!--
- `FX-001`: Commented example.
-->
""",
        )

        result = self._run()

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_unclosed_comment_hides_index_entries_to_end_of_file(self):
        self._write(
            "docs/knowledge/design/README.md",
            "# design\n\n<!--\n- [DES-client](DES-client.md)\n",
        )

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing formal document DES-client.md", result.stderr)

    def test_fenced_comment_literal_does_not_hide_visible_requirements(self):
        self._append(
            "docs/knowledge/spec/SPEC-client.md",
            """

```markdown
<!-- literal comment opener
```

- `FX-001`: Visible duplicate requirement.
-->
""",
        )

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate requirement FX-001", result.stderr)

    def test_prose_requirement_reference_is_not_a_definition(self):
        self._replace(
            "docs/knowledge/spec/SPEC-client.md",
            "- `FX-001`: Works.",
            "This prose merely refers to `FX-001`.",
        )

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("tracks not declared by upstream specs: FX-001", result.stderr)

    def test_frontmatter_requirement_example_is_not_a_definition(self):
        raw = """---
id: SPEC-client
examples:
  - "- `FX-001`: Frontmatter example."
---
# No requirements
"""
        self.assertEqual(requirement_definitions(raw), [])

        path = "docs/knowledge/spec/SPEC-client.md"
        self._replace(
            path,
            "updated_at: 2026-09-06\n---",
            "updated_at: 2026-09-06\n"
            "examples:\n"
            '  - "- `FX-001`: Frontmatter example."\n'
            "---",
        )
        self._replace(path, "- `FX-001`: Works.", "No formal requirements.")

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("tracks not declared by upstream specs: FX-001", result.stderr)

    def test_isolated_or_malformed_table_rows_are_not_definitions(self):
        path = "docs/knowledge/spec/SPEC-client.md"
        original = "- `FX-001`: Works."
        cases = {
            "isolated row": "| `FX-001` | Incidental reference |",
            "unrelated header": (
                "| reference | note |\n"
                "| --- | --- |\n"
                "| `FX-001` | Incidental reference |"
            ),
            "malformed separator": (
                "| requirement | acceptance |\n| -- | --- |\n| `FX-001` | Works. |"
            ),
            "mismatched columns": (
                "| requirement | acceptance |\n| --- |\n| `FX-001` | Works. |"
            ),
            "four-space indented code": (
                "    | requirement | acceptance |\n"
                "    | --- | --- |\n"
                "    | `FX-001` | Code example. |"
            ),
            "tab-indented code": (
                "\t| requirement | acceptance |\n"
                "\t| --- | --- |\n"
                "\t| `FX-001` | Code example. |"
            ),
            "spaces-before-tab indented code": (
                "   \t| requirement | acceptance |\n"
                "   \t| --- | --- |\n"
                "   \t| `FX-001` | Code example. |"
            ),
        }
        for name, invalid in cases.items():
            with self.subTest(case=name):
                self._replace(path, original, invalid)
                try:
                    result = self._run()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(
                        "tracks not declared by upstream specs: FX-001",
                        result.stderr,
                    )
                finally:
                    self._replace(path, invalid, original)

    def test_valid_requirement_table_headers_define_requirements(self):
        path = "docs/knowledge/spec/SPEC-client.md"
        original = "- `FX-001`: Works."
        tables = {
            "requirement": (
                "| requirement | acceptance |\n| --- | --- |\n| `FX-001` | Works. |"
            ),
            "条款": "| 条款 | 验收 |\n| --- | --- |\n| `FX-001` | Works. |",
            "ID without outer pipes": (
                "   ID | acceptance\n"
                "   --- | ---\n"
                r"   FX-001 | Works \| with an escaped pipe."
            ),
        }
        for name, table in tables.items():
            with self.subTest(case=name):
                self._replace(path, original, table)
                try:
                    result = self._run()
                    self.assertEqual(result.returncode, 0, result.stderr)
                finally:
                    self._replace(path, table, original)

    def test_rejects_malformed_requirement_bullets(self):
        path = "docs/knowledge/spec/SPEC-client.md"
        original = "- `FX-001`: Works."
        cases = {
            "unquoted id": "- FX-001: Works.",
            "missing colon": "- `FX-001` Works.",
            "missing definition": "- `FX-001`:",
            "indented code": "    - `FX-001`: Code example.",
        }
        for name, invalid in cases.items():
            with self.subTest(case=name):
                self._replace(path, original, invalid)
                try:
                    result = self._run()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(
                        "tracks not declared by upstream specs: FX-001",
                        result.stderr,
                    )
                finally:
                    self._replace(path, invalid, original)

    def test_accepts_star_requirement_bullet(self):
        self._replace(
            "docs/knowledge/spec/SPEC-client.md",
            "- `FX-001`: Works.",
            "* `FX-001`: Works.",
        )

        result = self._run()

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_inline_code_comment_literal_does_not_hide_visible_requirement(self):
        path = "docs/knowledge/spec/SPEC-client.md"
        original = (self.root / path).read_text(encoding="utf-8")
        for delimiter in ("`", "``"):
            with self.subTest(delimiter=delimiter):
                self._append(
                    path,
                    f"\nThe literal {delimiter}<!--{delimiter} is not a comment.\n"
                    "- `FX-001`: Visible duplicate requirement.\n",
                )
                try:
                    result = self._run()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("duplicate requirement FX-001", result.stderr)
                finally:
                    self._write(path, original)

    def test_ignores_authority_shaped_rows_outside_the_authority_table(self):
        self._append(
            "docs/knowledge/implementation/IMP-client.md",
            """

```markdown
| FX-001 | DES-client | aligned | EVD-client-2026-09-06 |
```

<!-- | FX-001 | DES-client | aligned | EVD-client-2026-09-06 | -->

| FX-001 | DES-client | aligned | EVD-client-2026-09-06 |
""",
        )

        result = self._run()

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_ignores_index_links_in_fences_and_html_comments(self):
        self._append(
            "docs/knowledge/design/README.md",
            """

```markdown
- [fenced duplicate](DES-client.md)
```

<!-- [commented duplicate](DES-client.md) -->
""",
        )

        result = self._run()

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_missing_duplicate_or_malformed_authority_table(self):
        path = "docs/knowledge/implementation/IMP-client.md"
        header = "| requirement | design | state | evidence or gap |"
        separator = "| --- | --- | --- | --- |"
        table = (
            f"{header}\n{separator}\n"
            "| FX-001 | DES-client | aligned | EVD-client-2026-09-06 |"
        )
        cases = (
            ("missing", header, "Authority matrix"),
            ("duplicate", table, f"{table}\n\n{table}"),
            ("malformed separator", separator, "| --- | -- | --- | --- |"),
        )
        for name, original, invalid in cases:
            with self.subTest(case=name):
                self._replace(path, original, invalid)
                try:
                    result = self._run()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("authority table", result.stderr)
                finally:
                    self._replace(path, invalid, original)


if __name__ == "__main__":
    unittest.main()
