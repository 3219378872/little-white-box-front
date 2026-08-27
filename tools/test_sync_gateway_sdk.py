import unittest

from sync_gateway_sdk import patch_generated_types


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


if __name__ == "__main__":
    unittest.main()
