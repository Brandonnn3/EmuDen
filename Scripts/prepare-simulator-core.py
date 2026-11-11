#!/usr/bin/env python3
"""Fetch the exact source and local tools for the checked-in simulator build recipe."""
from pathlib import Path
import hashlib
import subprocess
import urllib.request

root = Path(__file__).resolve().parent.parent
url = "https://github.com/azahar-emu/azahar/releases/download/2127.0-rc1/azahar-unified-source-2127.0-rc1.tar.xz"
expected = "4c966d8344da9a95c2c9ccfc6671991ba3bf36d82157c7d0a64ca25f1d30ed24"
tools = root / ".tools"
if not (tools / "bin/python3").exists():
    subprocess.run(["python3", "-m", "venv", str(tools)], check=True)
subprocess.run([str(tools / "bin/pip"), "install", "--no-cache-dir", "cmake==3.31.6", "ninja==1.11.1.4"], check=True)
archive = root / "build/Downloads/azahar-unified-source-2127.0-rc1.tar.xz"
archive.parent.mkdir(parents=True, exist_ok=True)
if not archive.exists():
    urllib.request.urlretrieve(url, archive)
if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
    raise SystemExit("Azahar source checksum mismatch; remove the archive and retry.")
source = root / "Vendor/Azahar/Source"
source.mkdir(parents=True, exist_ok=True)
if not (source / "CMakeLists.txt").exists():
    subprocess.run(["/usr/bin/tar", "-xJf", str(archive), "--strip-components=1", "-C", str(source)], check=True)
print("Verified source ready. Run Scripts/build-simulator-core.sh next.")
