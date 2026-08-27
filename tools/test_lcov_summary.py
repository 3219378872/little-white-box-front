import unittest

from lcov_summary import handwritten_records


class HandwrittenRecordsTest(unittest.TestCase):
    def test_excludes_only_generated_gateway_sdk(self):
        records = [
            {"source": "lib/sdk/api/gateway.dart", "hit": 1, "found": 10},
            {"source": "lib/sdk/data/gateway.dart", "hit": 1, "found": 10},
            {"source": "lib/sdk/api/api.dart", "hit": 5, "found": 10},
            {"source": "lib/features/feed/feed.dart", "hit": 8, "found": 10},
        ]

        kept = handwritten_records(records)

        self.assertEqual(
            [record["source"] for record in kept],
            ["lib/sdk/api/api.dart", "lib/features/feed/feed.dart"],
        )


if __name__ == "__main__":
    unittest.main()
