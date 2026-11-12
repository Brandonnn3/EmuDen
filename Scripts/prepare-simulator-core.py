#!/usr/bin/env python3
"""Fetch the exact source and local tools for the checked-in simulator build recipe."""
from pathlib import Path
import hashlib
import subprocess
import json
import shutil

root = Path(__file__).resolve().parent.parent
policy = json.loads((root / "Docs/Legal/SANITIZED-UPSTREAM-21.json").read_text())
packaged = root / policy["derivedArchive"]
expected = policy["derivedArchiveSHA256"]
tools = root / ".tools"
if not (tools / "bin/python3").exists():
    subprocess.run(["python3", "-m", "venv", str(tools)], check=True)
subprocess.run([str(tools / "bin/pip"), "install", "--no-cache-dir", "cmake==3.31.6", "ninja==1.11.1.4"], check=True)
archive = root / "build/Downloads" / packaged.name
archive.parent.mkdir(parents=True, exist_ok=True)
if not archive.exists():
    if not packaged.is_file():
        raise SystemExit("Obtain the matching EmuDen source package; its derived upstream source is required.")
    shutil.copy2(packaged, archive)
if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
    raise SystemExit("Azahar source checksum mismatch; remove the archive and retry.")
source = root / "Vendor/Azahar/Source"
source.mkdir(parents=True, exist_ok=True)
if not (source / "CMakeLists.txt").exists():
    subprocess.run(["/usr/bin/tar", "-xJf", str(archive), "--strip-components=1", "-C", str(source)], check=True)
print("Verified source ready. Run Scripts/build-simulator-core.sh next.")
