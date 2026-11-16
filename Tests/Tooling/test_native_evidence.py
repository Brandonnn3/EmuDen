import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("native_evidence", ROOT / "Scripts/validate-gamecube-candidate.py")
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


class NativeEvidenceTests(unittest.TestCase):
    def run_result(self, finished, status, name="case"):
        return {"finishedAt": finished, "cases": [{"name": name, "result": status}]}

    def test_a_later_failure_cannot_use_an_older_pass(self):
        with self.assertRaises(AssertionError):
            evidence.verify_native_cases([self.run_result(1, "Passed"), self.run_result(2, "Failed")], {"case"}, True)

    def test_successful_rerun_preserves_history_and_uses_actual_time(self):
        history = [self.run_result(2, "Passed"), self.run_result(1, "Failed")]
        evidence.verify_native_cases(history, {"case"}, True)
        self.assertEqual(history[1]["cases"][0]["result"], "Failed")

    def test_missing_required_case_still_blocks(self):
        with self.assertRaises(AssertionError):
            evidence.verify_native_cases([self.run_result(1, "Passed")], {"case", "missing"}, True)

    def test_original_all_pass_policy_is_unchanged(self):
        with self.assertRaises(AssertionError):
            evidence.verify_native_cases([self.run_result(1, "Failed"), self.run_result(2, "Passed")], {"case"})


if __name__ == "__main__":
    unittest.main()
