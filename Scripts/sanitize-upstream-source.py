#!/usr/bin/env python3
"""Make a reproducible source input without the three unused console-data payloads."""
from pathlib import Path
import argparse
import copy
import hashlib
import io
import json
import tarfile

ROOT = Path(__file__).resolve().parent.parent
ORIGINAL_SHA = "4c966d8344da9a95c2c9ccfc6671991ba3bf36d82157c7d0a64ca25f1d30ed24"
NAME = "azahar-unified-source-2127.0-rc1-emuden-resources.tar.xz"
HEADERS = {
    "src/core/hw/default_keys.h",
    "src/core/hle/service/http/ctr-common-1-cert.h",
    "src/core/hle/service/http/ctr-common-1-key.h",
}
PLACEHOLDER = b"// EmuDen build 21: unused console-data payload omitted.\n// See EMUDEN-RESOURCE-POLICY.txt and the mandatory local source patch.\n"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--check", action="store_true")
args = parser.parse_args()
output = ROOT / "Upstream" / NAME
record_path = ROOT / "Docs/Legal/SANITIZED-UPSTREAM-21.json"
if not args.check:
    source = ROOT / "build/Downloads/azahar-unified-source-2127.0-rc1.tar.xz"
    assert hashlib.sha256(source.read_bytes()).hexdigest() == ORIGINAL_SHA
    assert not output.exists(), "Preserve an existing derived source; use --check."
    records = []
    with tarfile.open(source) as original, tarfile.open(output, "w:xz", preset=6) as derived:
        for member in original:
            assert not member.name.startswith("/") and ".." not in Path(member.name).parts
            relative = member.name.partition("/")[2]
            if member.isfile() and relative in HEADERS:
                data = original.extractfile(member).read()
                records.append({"source": relative, "originalBytes": len(data), "originalSHA256": hashlib.sha256(data).hexdigest(),
                                "replacementSHA256": hashlib.sha256(PLACEHOLDER).hexdigest()})
                replacement = copy.copy(member); replacement.size = len(PLACEHOLDER)
                derived.addfile(replacement, io.BytesIO(PLACEHOLDER))
            else:
                derived.addfile(member, original.extractfile(member) if member.isfile() else None)
        assert {r["source"] for r in records} == HEADERS
        prefix = original.getmembers()[0].name.split("/")[0]
        text = ("EmuDen modifications, 12 November 2026: the three unused default key/client-certificate data headers are notice-only placeholders. "
                "All other original source/license files are preserved. Apply Scripts/azahar-no-bundled-resources.patch before building. "
                "This removes the corresponding includes and runtime fallback, retaining user-supplied resources. "
                "The original pinned input is preserved privately; this derived archive does not grant publisher rights or legal clearance.\n").encode()
        info = tarfile.TarInfo(prefix + "/EMUDEN-RESOURCE-POLICY.txt"); info.size = len(text); info.mode = 0o644
        derived.addfile(info, io.BytesIO(text))
    record = {"build": "21", "originalArchiveSHA256": ORIGINAL_SHA, "derivedArchive": "Upstream/" + NAME,
              "derivedArchiveSHA256": hashlib.sha256(output.read_bytes()).hexdigest(), "modifiedHeaders": records,
              "policy": "Only the three data headers are replaced; complete required source/licenses plus local patches retained.",
              "originalPreservedOutsideRelease": True}
    record_path.write_text(json.dumps(record, indent=2) + "\n")
record = json.loads(record_path.read_text())
assert hashlib.sha256(output.read_bytes()).hexdigest() == record["derivedArchiveSHA256"]
with tarfile.open(output) as archive:
    found = set()
    for member in archive:
        relative = member.name.partition("/")[2]
        if member.isfile() and relative in HEADERS:
            assert archive.extractfile(member).read() == PLACEHOLDER
            found.add(relative)
    assert found == HEADERS
print("Verified derived upstream source: three unused payloads replaced, pinned digest recorded.")
