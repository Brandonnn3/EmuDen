#!/usr/bin/env python3
"""Stage metadata-only artwork fixtures in the isolated simulator; never copies games."""
from pathlib import Path
import argparse
import json
import shutil
import struct
import subprocess
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("simulator")
parser.add_argument("--collection", action="store_true", help="Include the complete metadata-only artwork collection")
parser.add_argument("--cached-artwork", action="store_true", help="Stage validated catalog images for offline UI review")
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
catalog = json.loads((ROOT / "Resources/CinematicArt/Artwork-Pack.json").read_text()) if args.collection or args.cached_artwork else None
if args.collection:
    existing = {row[1] for row in fixtures}
    for game in catalog["games"]:
        if game["title"] in existing:
            continue
        identifier = "DD000000-0000-0000-0000-" + f"{len(fixtures) + 1:012d}"
        fixtures.append((identifier, game["title"], game["programIDs"][0], game["title"]))
library = docs / "library.json"
if library.exists():
    assert {g["id"] for g in json.loads(library.read_text())} <= {g[0] for g in fixtures}, "Unexpected user games; refusing to replace the library"
for folder in ["Games", "Artwork", "Scenes", "Artwork Fixtures"]:
    (docs / folder).mkdir(parents=True, exist_ok=True)
if args.collection:
    for identifier, *_ in fixtures:
        for folder in ("Artwork", "Scenes"):
            for suffix in ("custom", "user.png"):
                (docs / folder / (identifier + "." + suffix)).unlink(missing_ok=True)
files = json.loads((ROOT / "Resources/3ds-artwork-index.json").read_text())["files"]
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
    prefix = title + " (USA)"
    match = next((n for n in files if n.startswith(prefix)), None)
    if match:
        url = "https://thumbnails.libretro.com/Nintendo%20-%20Nintendo%203DS/Named_Boxarts/" + urllib.parse.quote(match)
        with urllib.request.urlopen(url, timeout=20) as response:
            image = response.read(4 * 1024 * 1024 + 1)
        assert image[:8] == b"\x89PNG\r\n\x1a\n" and len(image) <= 4 * 1024 * 1024
        (docs / "Artwork" / (identifier + ".png")).write_bytes(image)
        (docs / "Artwork" / (identifier + ".name")).write_text(artname)
        (docs / "Scenes" / (identifier + ".png")).write_bytes(image)
        (docs / "Scenes" / (identifier + ".name")).write_text(artname)
shutil.copy2(ROOT / "Resources/CinematicArt/Console-3ds.png", docs / "Artwork Fixtures/Console Cover.png")
library.write_text(json.dumps(games))
if args.cached_artwork:
    import hashlib
    cache = container / "Library/Caches/EmuDenArtwork"
    cache.mkdir(parents=True, exist_ok=True)
    for game in catalog["games"]:
        for kind in ("cover", "scene"):
            if asset := game[kind]:
                source = ROOT / "ArtworkCatalog/dist" / asset["path"]
                assert hashlib.sha256(source.read_bytes()).hexdigest() == asset["sha256"]
                shutil.copy2(source, cache / (asset["sha256"] + ".jpg"))
    shutil.copy2(ROOT / "Resources/CinematicArt/Artwork-Pack.json", cache / "catalog.json")
print(f"Staged {len(games)} artwork-only metadata fixtures. These files do not contain executable games.")
