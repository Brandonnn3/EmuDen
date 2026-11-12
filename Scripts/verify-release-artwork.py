#!/usr/bin/env python3
"""Check the active release asset scope, hashes and absence of artwork service endpoints."""
from pathlib import Path
import argparse, hashlib, json, plistlib

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--app", type=Path)
args = parser.parse_args()
register = json.loads((ROOT / "Docs/Legal/ASSET-REGISTER-21.json").read_text())
expected = {"Console-3ds.png", "Title-IDs.json", "PROVENANCE.md"}
assert {p.name for p in (ROOT / "Resources/CinematicArt").iterdir() if p.is_file()} == expected
for asset in register["assets"]:
    assert hashlib.sha256((ROOT / asset["path"]).read_bytes()).hexdigest() == asset["sha256"], asset["path"]
project = (ROOT / "EmulatorApp.xcodeproj/project.pbxproj").read_text()
assert "App/Domain/RemoteArtwork.swift in Sources" not in project
assert "3ds-scene-index.json in Resources" not in project
for relative in ["App/ArtworkStore.swift", "App/CinematicArt.swift", "App/Domain/Artwork.swift"]:
    source = (ROOT / relative).read_text()
    assert "URLSession" not in source and "thumbnails.libretro.com" not in source and "emuden-artwork-catalog" not in source
if args.app:
    art = args.app / "CinematicArt"
    assert {p.name for p in art.iterdir() if p.is_file()} == expected
    assert hashlib.sha256((art / "Console-3ds.png").read_bytes()).hexdigest() == register["assets"][0]["sha256"]
    assert not (args.app / "3ds-scene-index.json").exists()
    info = plistlib.loads((args.app / "Info.plist").read_bytes())
    binary = (args.app / info["CFBundleExecutable"]).read_bytes()
    for host in [b"thumbnails.libretro.com", b"emuden-artwork-catalog.headyopossum2.chatgpt.site"]:
        assert host not in binary, host
print("Verified local-artwork resource scope, 11 original asset hashes and no compiled gallery/cover-service endpoints.")
