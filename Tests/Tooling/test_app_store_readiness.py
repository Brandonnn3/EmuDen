import importlib.util
from pathlib import Path
import tempfile
import unittest

path = Path(__file__).resolve().parents[2] / "Scripts/validate-app-store-readiness.py"
spec = importlib.util.spec_from_file_location("readiness", path)
readiness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(readiness)


class PublicReadinessTests(unittest.TestCase):
    def test_missing_or_empty_records_do_not_clear_release(self):
        self.assertTrue(readiness.blockers({}, {}))
        review = {"publicReleaseCleared": True, "criteria": []}
        self.assertTrue(readiness.blockers({"supportURL": "https://example.com/support", "privacyPolicyURL": "https://example.com/privacy"}, review))

    def test_resolved_records_require_evidence_and_valid_urls(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "evidence.txt").write_text("Test fixture, not actual clearance.")
            review = {"publicReleaseCleared": True, "criteria": [
                {"id": key, "status": "resolved", "evidence": ["evidence.txt"]} for key in readiness.REQUIRED
            ]}
            metadata = {"supportURL": "https://example.com/support", "privacyPolicyURL": "https://example.com/privacy"}
            self.assertEqual(readiness.blockers(metadata, review, root), [])
            (root / "evidence.txt").unlink()
            self.assertTrue(readiness.blockers(metadata, review, root))
            metadata["privacyPolicyURL"] = "file:///private/policy.html"
            self.assertTrue(readiness.blockers(metadata, review, root))


if __name__ == "__main__":
    unittest.main()
