import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class NoticeResourcesTests(unittest.TestCase):
    def test_structured_viewer_preserves_every_notice_in_the_full_text(self):
        raw = (ROOT / "Resources/ThirdPartyNotices.json").read_bytes()
        document = json.loads(raw)
        manifest = json.loads((ROOT / "Docs/Legal/Notice-Sources.json").read_text())
        self.assertEqual(hashlib.sha256(raw).hexdigest(), manifest["structuredNoticeSHA256"])
        self.assertEqual(len(document["notices"]), 84)
        self.assertEqual([entry["source"] for entry in document["notices"]], [item["source"] for item in manifest["sources"]])
        separator = "\n" + "=" * 72 + "\n"
        text = document["introduction"] + "".join(separator + entry["source"] + separator + "\n" + entry["text"] + "\n" for entry in document["notices"])
        self.assertEqual(text.encode(), (ROOT / "Resources/ThirdPartyNotices.txt").read_bytes())


if __name__ == "__main__":
    unittest.main()
