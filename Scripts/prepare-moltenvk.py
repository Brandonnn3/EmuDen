#!/usr/bin/env python3
"""Fetch the official, checksum-pinned MoltenVK release used by both hosts."""
from pathlib import Path, PurePosixPath
import hashlib
import subprocess
import tarfile
import urllib.request

root = Path(__file__).resolve().parent.parent
archive = root / "build/Downloads/MoltenVK-all-1.4.2.tar"
expected = "562a15a29bc358446a56a4091c5f7e08f604184187c1d34f712148b61ef17276"
archive.parent.mkdir(parents=True, exist_ok=True)
if not archive.exists():
    urllib.request.urlretrieve("https://github.com/KhronosGroup/MoltenVK/releases/download/v1.4.2/MoltenVK-all.tar", archive)
digest = hashlib.sha256()
with archive.open("rb") as file:
    for block in iter(lambda: file.read(1024 * 1024), b""):
        digest.update(block)
if digest.hexdigest() != expected:
    raise SystemExit("MoltenVK checksum mismatch; remove the archive and retry")
destination = root / "Vendor/MoltenVK"
destination.mkdir(parents=True, exist_ok=True)
if not (destination / "MoltenVK/MoltenVK/include/vulkan/vulkan.h").exists():
    with tarfile.open(archive) as file:
        for member in file.getmembers():
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts:
                raise SystemExit("Unsafe archive path")
            if member.issym() or member.islnk():
                target = (destination / str(path.parent) / member.linkname).resolve()
                if destination.resolve() not in target.parents:
                    raise SystemExit("Unsafe archive link")
    subprocess.run(["/usr/bin/tar", "-xf", str(archive), "-C", str(destination)], check=True)
print("Verified MoltenVK 1.4.2 ready")
