#!/usr/bin/env python3
"""Report recorded public-release blockers; this cannot certify legality or Apple acceptance."""
from pathlib import Path
from urllib.parse import urlsplit
import json
import sys

ROOT = Path(__file__).resolve().parent.parent
REQUIRED = {
    "artwork-rights", "corresponding-source", "store-license-compatibility", "dependency-notices",
    "public-support-privacy", "privacy-disclosure", "export-compliance", "emulator-content-age",
    "branding-clearance", "release-quality",
}


def blockers(metadata, review, root=ROOT):
    problems = []
    if review.get("publicReleaseCleared") is not True:
        problems.append("Public-release clearance has not been recorded.")
    for field in ("supportURL", "privacyPolicyURL"):
        value = metadata.get(field)
        parts = urlsplit(value) if isinstance(value, str) else None
        if not parts or parts.scheme != "https" or not parts.hostname or parts.username or parts.password:
            problems.append(field + " needs a real public HTTPS URL.")
    rows = review.get("criteria", [])
    ids = [row.get("id") for row in rows]
    if len(ids) != len(set(ids)) or set(ids) != REQUIRED:
        problems.append("The required review criteria are missing or duplicated.")
    for row in rows:
        if row.get("status") != "resolved":
            problems.append(str(row.get("id")) + ": " + str(row.get("resolution", "Unresolved.")))
            continue
        evidence = row.get("evidence")
        if not isinstance(evidence, list) or not evidence or any(
            not isinstance(p, str) or not p or not (root / p).is_file() for p in evidence
        ):
            problems.append(str(row.get("id")) + ": recorded resolution needs local evidence for review.")
    return problems


if __name__ == "__main__":
    try:
        metadata = json.loads((ROOT / "TestFlight/AppInformation.json").read_text())
        review = json.loads((ROOT / "TestFlight/AppStoreReadiness.json").read_text())
        problems = blockers(metadata, review)
    except (OSError, ValueError, TypeError, AttributeError) as error:
        print("Public-readiness records could not be checked: " + str(error), file=sys.stderr)
        sys.exit(1)
    if problems:
        print("PUBLIC RELEASE ON HOLD")
        for problem in problems:
            print("- " + problem)
        sys.exit(1)
    print("No unresolved local review records. This does not certify legal compliance or guarantee Apple acceptance.")
