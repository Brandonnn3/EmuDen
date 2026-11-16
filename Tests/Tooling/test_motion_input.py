from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


@unittest.skipUnless(sys.platform == "darwin", "Uses the same Apple clang as the iOS bridge")
class MotionInputTests(unittest.TestCase):
    def test_sensor_requests_units_pause_and_invalid_samples(self):
        root = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory() as directory:
            binary = str(Path(directory) / "motion-input")
            subprocess.run(["xcrun", "clang++", "-std=c++17", "-I", str(root / "Bridge"),
                            str(root / "Tests/MotionInputTests.cpp"), "-o", binary], check=True)
            subprocess.run([binary], check=True)
