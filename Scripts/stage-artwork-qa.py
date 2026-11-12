#!/usr/bin/env python3
"""Stage metadata-only artwork fixtures in the isolated simulator; never copies games."""
from pathlib import Path
import argparse
import json
import shutil
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("simulator")
args = parser.parse_args()
devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"], text=True))
device = next(d for group in devices["devices"].values() for d in group if d["udid"] == args.simulator)
assert device["name"] in {"EmuDen Artwork QA", "EmuDen Artwork Files QA"}, "Only the isolated artwork simulators are allowed"
container = Path(subprocess.check_output(["xcrun", "simctl", "get_app_container", args.simulator, "com.brandonaleman.Emulator", "data"], text=True).strip())
docs = container / "Documents"
fixtures = [
    ("DD000000-0000-0000-0000-000000000001", "Donkey Kong Country Returns 3D", "00040000000CCE00", "Donkey Kong Country Returns 3D"),
    ("DD000000-0000-0000-0000-000000000002", "Tomodachi Life", "000400000008C500", "Tomodachi Life"),
    ("DD000000-0000-0000-0000-000000000003", "Mario Golf - World Tour", "00040000000DCD00", "Mario Golf: World Tour"),
    ("DD000000-0000-0000-0000-000000000004", "Unknown homebrew", None, "Unknown homebrew"),
]
library = docs / "library.json"
if library.exists():
    assert {g["id"] for g in json.loads(library.read_text())} <= {g[0] for g in fixtures}, "Unexpected user games; refusing to replace the library"
for folder in ["Games", "Artwork", "Scenes", "Artwork Fixtures"]:
    (docs / folder).mkdir(parents=True, exist_ok=True)
games = []
added = time.time() - 978307200
for i, (identifier, title, program, artname) in enumerate(fixtures):
    header = bytearray(0x200)
    if program:
        header[0x100:0x104] = b"NCCH"
        struct.pack_into("<Q", header, 0x118, int(program, 16))
    else:
        header[:4] = b"3DSX"
    filename = identifier + (".cci" if program else ".3dsx")
    (docs / "Games" / filename).write_bytes(header)
    games.append({"id": identifier, "title": title, "fileName": filename, "added": added - i, "programID": program})
shutil.copy2(ROOT / "Resources/CinematicArt/Console-3ds.png", docs / "Artwork Fixtures/Console Cover.png")
library.write_text(json.dumps(games))
print(f"Staged {len(games)} artwork-only metadata fixtures. These files do not contain executable games.")
