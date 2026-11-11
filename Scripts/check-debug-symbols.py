#!/usr/bin/env python3
"""Require real DWARF sections and matching build UUIDs, not placeholder symbol bundles."""
from pathlib import Path
import re
import subprocess
import sys


def uuids(path):
    output = subprocess.run(["xcrun", "dwarfdump", "--uuid", str(path)],
                            capture_output=True, text=True, check=True).stdout
    result = set(re.findall(r"UUID: ([0-9A-Fa-f-]+) \(([^)]+)\)", output))
    assert result, f"No UUID found in {path}"
    return result


def check(binary, bundle):
    assert bundle.is_dir(), f"Missing dSYM: {bundle}"
    files = list((bundle / "Contents/Resources/DWARF").iterdir())
    assert len(files) == 1, f"Expected one DWARF file in {bundle}"
    dwarf = files[0]
    assert uuids(binary) == uuids(dwarf), f"Mismatched dSYM for {binary}"
    output = subprocess.run(["xcrun", "otool", "-l", str(dwarf)],
                            capture_output=True, text=True, check=True).stdout
    for section in ("__debug_info", "__debug_line"):
        sizes = re.findall(r"sectname " + section + r"\s+segname __DWARF\s+addr \S+\s+size (0x[0-9a-fA-F]+)", output)
        assert sizes and all(int(size, 16) > 0 for size in sizes), f"Empty {section} in {dwarf}"
    print(f"Verified matching UUIDs and real DWARF: {binary.name}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: check-debug-symbols.py BINARY FRAMEWORK.dSYM")
    check(Path(sys.argv[1]), Path(sys.argv[2]))
