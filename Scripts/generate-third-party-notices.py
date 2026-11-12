#!/usr/bin/env python3
"""Preserve upstream license/notice text for the app and its corresponding-source delivery."""
from pathlib import Path
import argparse
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--check", action="store_true")
args = parser.parse_args()
pattern = re.compile(r"^(LICENSE|LICENCE|COPYING|NOTICE|COPYRIGHT|UNLICENSE)([-_.].*)?$", re.I)
sources = [ROOT / p for p in [
    "Vendor/Azahar/Source/LICENSE.txt", "Vendor/MoltenVK/Source/LICENSE",
    "Resources/Homebrew-NOTICE.txt", "Resources/MenuAudio/NOTICE.txt",
    "Bridge/libretro.h", "Bridge/libretro_vulkan.h",
]]
for folder in ["Vendor/Azahar/Source/externals", "Vendor/MoltenVK/Source/External"]:
    base = ROOT / folder
    assert base.is_dir(), base
    sources += [p for p in base.rglob("*") if p.is_file() and p.stat().st_size > 0 and ".git" not in p.parts
                and pattern.fullmatch(p.name) and p.suffix.lower() in {"", ".txt", ".md", ".rst"}]
sources = sorted(set(sources))
assert len(sources) >= 40
parts = ["EmuDen — open-source notices\n\n"
         "Original EmuDen source contributions: GPL-3.0-or-later. See COPYRIGHT.md and LICENSE.txt in the corresponding source.\n"
         "Upstream notices below are preserved under their respective terms. Some upstream components are not enabled in this build.\n"
         "This notice bundle does not grant rights to third-party games, characters or artwork.\n"]
records = []
entries = []
for source in sources:
    assert source.is_file() and not source.is_symlink(), source
    raw = source.read_bytes()
    try:
        value = raw.decode("utf-8")
    except UnicodeDecodeError:
        value = raw.decode("latin-1")
    if source.parent.name == "Bridge":
        header = re.match(r"/\*.*?\*/", value, re.S)
        assert header and "Permission is hereby granted" in header.group(), source
        value = header.group()
    assert 0 < len(value.encode("utf-8")) <= 128 * 1024, source
    relative = source.relative_to(ROOT).as_posix()
    parts.append("\n" + "=" * 72 + "\n" + relative + "\n" + "=" * 72 + "\n\n" + value + "\n")
    entries.append({"source": relative, "text": value})
    records.append({"source": relative, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
                    "noticeText": "leading license comment" if source.parent.name == "Bridge" else "complete file"})
output = "".join(parts).encode("utf-8")
structured = (json.dumps({"introduction": parts[0], "notices": entries}, ensure_ascii=False, indent=2) + "\n").encode()
manifest = (json.dumps({"sources": records, "noticeSHA256": hashlib.sha256(output).hexdigest(), "structuredNoticeSHA256": hashlib.sha256(structured).hexdigest()}, indent=2) + "\n").encode()
for path, data in [(ROOT / "Resources/ThirdPartyNotices.txt", output), (ROOT / "Resources/ThirdPartyNotices.json", structured), (ROOT / "Docs/Legal/Notice-Sources.json", manifest)]:
    if args.check:
        assert path.read_bytes() == data, "Regenerate changed notices: " + str(path)
    else:
        path.write_bytes(data)
print(f"{'Verified' if args.check else 'Generated'} {len(records)} preserved notice texts, {len(output):,} bytes")
