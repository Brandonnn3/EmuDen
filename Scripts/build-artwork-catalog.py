#!/usr/bin/env python3
"""Encode accepted artwork masters for delivery and write the app's small catalog seed."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import subprocess

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "ArtworkCatalog"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--allow-fallbacks", action="store_true", help="Record missing images as explicit existing-art/console fallbacks")
parser.add_argument("--report", default="build/artwork-pack-validation.json", help="Validation report path relative to the app workspace")
args = parser.parse_args()
selection = json.loads((ROOT / "Docs/Design/ArtworkCatalog/selection.json").read_text())
config = json.loads((SITE / "catalog-config.json").read_text())
dist = SITE / "dist"
dist.mkdir(exist_ok=True)
games, missing = [], []
assert sorted(g["rank"] for g in selection["games"] if g["rank"] is not None) == list(range(1, 26))
all_ids = set()
for game in selection["games"]:
    assert game["programIDs"], game["key"]
    assert not all_ids.intersection(game["programIDs"]), game["key"]
    all_ids.update(game["programIDs"])
    row = {k: game[k] for k in ("key", "title", "aliases", "programIDs", "rank", "bonus")}
    for kind in ("cover", "scene"):
        source = ROOT / "ArtworkMasters/3ds" / game["key"] / (kind + ".png")
        if not source.exists():
            missing.append({"key": game["key"], "kind": kind})
            row[kind] = None
            continue
        png = source.read_bytes()
        assert png[:8] == b"\x89PNG\r\n\x1a\n", source
        width, height = struct.unpack_from(">II", png, 16)
        ratio = width / height
        if kind == "cover":
            assert 0.6 <= ratio <= 0.76 and height >= 960, (source, width, height)
        else:
            assert min(width, height) >= 720 and max(width, height) >= 1280 and 1.3 <= ratio <= 2.4, (source, width, height)
        assert max(width, height) <= 4096
        target = dist / "images" / game["key"]
        target.mkdir(parents=True, exist_ok=True)
        temporary = target / (kind + ".encoding.jpg")
        # Delivery transcoding only; generated masters and their composition remain unchanged.
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "86", str(source), "--out", str(temporary)], stdout=subprocess.DEVNULL, check=True)
        data = temporary.read_bytes()
        assert data[:2] == b"\xff\xd8" and len(data) <= 4 * 1024 * 1024, temporary
        digest = hashlib.sha256(data).hexdigest()
        destination = target / (kind + "-" + digest[:12] + ".jpg")
        temporary.replace(destination)
        row[kind] = {"path": destination.relative_to(dist).as_posix(), "sha256": digest, "bytes": len(data), "width": width, "height": height}
    games.append(row)
assert args.allow_fallbacks or not missing, f"Missing requested images: {missing}"
manifest = {"schema": 1, "version": config["version"], "baseURL": config["baseURL"], "selectionSource": selection["source"], "games": games}
old_path = dist / "catalog.json"
if old_path.exists():
    old = json.loads(old_path.read_text())
    assert old == manifest or manifest["version"] > old["version"], "Increment catalog-config.json version before replacing published content"
encoded = (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode()
old_path.write_bytes(encoded)
(ROOT / "Resources/CinematicArt/Artwork-Pack.json").write_bytes(encoded)
for game in games:
    for kind in ("cover", "scene"):
        if asset := game[kind]:
            data = (dist / asset["path"]).read_bytes()
            assert hashlib.sha256(data).hexdigest() == asset["sha256"] and len(data) == asset["bytes"]
report = {"catalogVersion": manifest["version"], "rankedEntries": 25, "libraryExtras": sum(g["bonus"] for g in games),
          "entries": len(games), "images": sum(g[k] is not None for g in games for k in ("cover", "scene")),
          "imageBytes": sum(g[k]["bytes"] for g in games for k in ("cover", "scene") if g[k]), "manifestBytes": len(encoded),
          "fallbacks": missing, "baseURL": manifest["baseURL"], "mode": "built-in image_gen; JPEG delivery encoding; PNG masters preserved"}
(ROOT / args.report).write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
