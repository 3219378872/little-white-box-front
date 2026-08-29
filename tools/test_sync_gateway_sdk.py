import unittest

from sync_gateway_sdk import patch_bodyless_request_args, patch_generated_types


class NullablePrimitivePatchTest(unittest.TestCase):
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

    def test_widens_assistant_entity_ids(self):
        generated = """
final num runId;
final num sessionId;
final num changeId;
final num lastMessageId;
final num activeRunId;
final List<int> changeIds;
changeIds: m['changeIds']?.cast<int>() ?? [],
"""
        patched = patch_generated_types(generated)
        self.assertIn("final Object runId;", patched)
        self.assertIn("final Object sessionId;", patched)
        self.assertIn("final Object changeId;", patched)
        self.assertIn("final Object lastMessageId;", patched)
        self.assertIn("final Object activeRunId;", patched)
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
