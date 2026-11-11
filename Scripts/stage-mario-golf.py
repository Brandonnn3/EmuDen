#!/usr/bin/env python3
"""Stage a user-provided ROM in this app's current simulator container."""
from pathlib import Path
import shutil
import subprocess
import sys
import json
import time
import uuid

if len(sys.argv) != 3:
    raise SystemExit("Usage: stage-mario-golf.py <simulator-UDID> <local-ROM>")
device, source = sys.argv[1], Path(sys.argv[2]).resolve(strict=True)
# Reinstalls can replace the container, so never persist its UUID in this script.
container = subprocess.check_output(["xcrun", "simctl", "get_app_container", device,
                                     "com.brandonaleman.Emulator", "data"], text=True).strip()
subprocess.run(["xcrun", "simctl", "terminate", device, "com.brandonaleman.Emulator"], capture_output=True)
documents = Path(container) / "Documents"
catalog = documents / "library.json"
games = json.loads(catalog.read_text()) if catalog.exists() else []
if not isinstance(games, list):
    raise SystemExit("Unexpected library catalog; leaving it unchanged")
target = documents / "Games/MarioGolf.3ds"
target.parent.mkdir(parents=True, exist_ok=True)
temporary = target.with_suffix(".importing")
shutil.copyfile(source, temporary)
temporary.replace(target)
if not any(game.get("fileName") == target.name for game in games):
    games.append({"id": str(uuid.uuid4()), "title": "Mario Golf – World Tour", "fileName": target.name,
                  "added": time.time() - 978307200})
pending = catalog.with_suffix(".pending")
pending.write_text(json.dumps(games))
pending.replace(catalog)
alias = documents / "TestGames/MarioGolf.3ds"
alias.parent.mkdir(parents=True, exist_ok=True)
if alias.exists() or alias.is_symlink(): alias.unlink()
alias.symlink_to("../Games/MarioGolf.3ds")
print(f"Added {source.name} to the dedicated simulator library. The source is unchanged.")
print("Launch with: xcrun simctl launch " + device + " com.brandonaleman.Emulator --boot-test-game")
