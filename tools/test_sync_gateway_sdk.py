import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from sync_gateway_sdk import (
    default_backend_api_path,
    normalize_generated_header,
    patch_bodyless_request_args,
    patch_generated_types,
)


class NullablePrimitivePatchTest(unittest.TestCase):
    def test_finds_backend_api_from_main_checkout(self):
        with TemporaryDirectory() as tmp:
            workspace = Path(tmp) / "little"
            frontend = workspace / "little-white-box-front"
            api = (
                workspace
                / "little-white-box-content-community"
                / "app"
                / "gateway"
                / "gateway.api"
            )
            frontend.mkdir(parents=True)
            api.parent.mkdir(parents=True)
            api.touch()

            self.assertEqual(default_backend_api_path(frontend), api)

    def test_finds_backend_api_from_nested_task_worktree(self):
        with TemporaryDirectory() as tmp:
            workspace = Path(tmp) / "little"
            frontend = (
                workspace
                / "little-white-box-front"
                / ".worktree"
                / "task-sdk"
            )
            api = (
                workspace
                / "little-white-box-content-community"
                / "app"
                / "gateway"
                / "gateway.api"
            )
            frontend.mkdir(parents=True)
            api.parent.mkdir(parents=True)
            api.touch()

            self.assertEqual(default_backend_api_path(frontend), api)

    def test_normalizes_checkout_specific_source_header(self):
        generated = "// --/tmp/worktree/app/gateway/gateway--\n\nclass Req {}\n"

        patched = normalize_generated_header(generated)

        self.assertEqual(
            "// --app/gateway/gateway--\n\nclass Req {}\n",
            patched,
        )

    def test_additive_post_media_preserves_constructor_compatibility(self):
        generated = """// --/temporary/worktree/app/gateway/gateway--
class PostItem {
  final List<int> mediaIds;
  PostItem({required this.mediaIds,});
  factory PostItem.fromJson(Map<String,dynamic> m) { return PostItem(); }
}
"""
        patched = patch_generated_types(generated)
        self.assertIn("this.mediaIds = const [],", patched)
        self.assertIn("final List<Object> mediaIds;", patched)
        self.assertNotIn("/temporary/worktree", patched)
        self.assertEqual(patch_generated_types(patched), patched)

    def test_patches_nullable_primitive_serialization(self):
        generated = """
final String? value;
final double? score;
final bool? suppressed;
value: m['value'] == null ? null : String?.fromJson(m['value']),
score: m['score'] == null ? null : double?.fromJson(m['score']),
suppressed: m['suppressed'] == null ? null : bool?.fromJson(m['suppressed']),
'value': value?.toJson(),
'score': score?.toJson(),
'suppressed': suppressed?.toJson(),
"""

        patched = patch_generated_types(generated)

        self.assertNotIn("?.fromJson", patched)
        self.assertNotIn("?.toJson", patched)
        self.assertIn("m['value']?.toString()", patched)
        self.assertIn("(m['score'] as num).toDouble()", patched)
        self.assertIn("m['suppressed'] as bool", patched)

    def test_widens_generated_entity_ids(self):
        generated = """
final num runId;
final num sessionId;
final num changeId;
final num lastMessageId;
final num activeRunId;
final num beforeId;
final num nextBeforeId;
final num mediaId;
final List<int> mediaIds;
final List<int> changeIds;
mediaIds: m['mediaIds']?.cast<int>() ?? [],
changeIds: m['changeIds']?.cast<int>() ?? [],
"""
        patched = patch_generated_types(generated)
        self.assertIn("final Object runId;", patched)
        self.assertIn("final Object sessionId;", patched)
        self.assertIn("final Object changeId;", patched)
        self.assertIn("final Object lastMessageId;", patched)
        self.assertIn("final Object activeRunId;", patched)
        self.assertIn("final Object beforeId;", patched)
        self.assertIn("final Object nextBeforeId;", patched)
        self.assertIn("final Object mediaId;", patched)
        self.assertIn("final List<Object> mediaIds;", patched)
        self.assertIn("List<Object>.from(m['mediaIds'] as List)", patched)
        self.assertIn("final List<Object> changeIds;", patched)
        self.assertIn("List<Object>.from(m['changeIds'] as List)", patched)

    def test_replaces_undefined_request_in_bodyless_helpers(self):
        generated = """
Future createAssistantSession({
  Function(CreateAssistantSessionResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v2/assistant/sessions",
    request,
    ok: (data) {
      if (ok != null) ok(CreateAssistantSessionResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}
"""
        patched = patch_bodyless_request_args(generated)
        self.assertIn("const {},", patched)
        self.assertNotIn("    request,", patched)


if __name__ == "__main__":
    unittest.main()
