#!/usr/bin/env python3
"""Package the matching source using a strict allowlist; never include user games or contacts."""
from pathlib import Path
import hashlib
import json
import tarfile

ROOT = Path(__file__).resolve().parent.parent
upstream = ROOT / "build/Downloads/azahar-unified-source-2127.0-rc1.tar.xz"
assert hashlib.sha256(upstream.read_bytes()).hexdigest() == "4c966d8344da9a95c2c9ccfc6671991ba3bf36d82157c7d0a64ca25f1d30ed24"
metadata = json.loads((ROOT / "TestFlight/AppInformation.json").read_text())
output = ROOT / f"build/TestFlight/EmuDen-{metadata['version']}-{metadata['build']}-source.tar.gz"
if output.exists():
    raise FileExistsError(f"Preserve the existing matching-source package: {output.name}. Increment the build before packaging modified source.")
output.parent.mkdir(parents=True, exist_ok=True)
files = []
for folder in ("App", "Bridge", "Scripts", "Resources", "Widgets", "Tests", "TestFlight"):
    for path in (ROOT / folder).rglob("*"):
        if "Private" in path.relative_to(ROOT).parts:
            continue
        assert not path.is_symlink(), path
        if path.is_file() and "__pycache__" not in path.parts and path.name != ".DS_Store":
            files.append(path)
for name in ("README.md", "Package.swift", "LICENSE.txt", "COPYRIGHT.md", "EmulatorApp.xcodeproj/project.pbxproj",
             "EmulatorApp.xcodeproj/xcshareddata/xcschemes/Emulator.xcscheme",
             "EmulatorApp.xcodeproj/xcshareddata/xcschemes/Emulator Tips QA.xcscheme",
             "Vendor/Azahar/Info.plist", "Vendor/Azahar/LICENSE.txt", "Vendor/Azahar/PROVENANCE.md",
             "Vendor/MoltenVK/PROVENANCE.md", "Docs/HOMEBREW.md", "Docs/BUILD-5.md", "Docs/BUILD-6.md", "Docs/BUILD-7.md", "Docs/BUILD-8.md", "Docs/BUILD-9.md",
             "Docs/BUILD-10.md", "Docs/BUILD-11.md", "Docs/BUILD-12.md", "Docs/BUILD-13.md", "Docs/BUILD-14.md", "Docs/BUILD-15.md", "Docs/BUILD-16.md", "Docs/BUILD-17.md", "Docs/BUILD-18.md", "Docs/BUILD-19.md", "Docs/Legal/EXPORT-ASSESSMENT-19.json", "Docs/Legal/RELEASE-19-REVIEW-PACKET.md", "Docs/Legal/Notice-Sources.json", "Docs/Legal/SOURCE-PUBLICATION-2026-11-11.json", "Docs/Legal/OWNER-AUTHORIZATION-2026-11-11.json", "Docs/Design/Build12-Console-Art/prompts.json", "Docs/Design/Build12-Console-Art/PROVENANCE.md", "Docs/Design/Option-A-Assets/prompts.json",
             "Docs/Design/Build13-Artwork/selection.json", "Docs/Design/Build13-Artwork/artwork-a.json", "Docs/Design/Build13-Artwork/artwork-b.json", "Docs/Design/Build13-Artwork/artwork-c.json", "Docs/Design/Build13-Artwork/PROVENANCE.md", "Docs/Design/Build13-Artwork/final-assets.json",
             "Docs/Branding/README.md", "Docs/Branding/EmuDen-Icon-Master.png",
             "Docs/Design/ArtworkCatalog/selection.json", "Docs/Design/ArtworkCatalog/queue.json", "Docs/Design/ArtworkCatalog/README.md", "Docs/Design/ArtworkCatalog/batch-2026-11-11-1252.json", "Docs/Design/ArtworkCatalog/batch-2026-11-11-1347.json", "Docs/Design/ArtworkCatalog/batch-2026-11-11-1656.json", "Docs/Design/ArtworkCatalog/batch-2026-11-11-1813.json",
             "ArtworkCatalog/.openai/hosting.json", "ArtworkCatalog/catalog-config.json", "ArtworkCatalog/README.md",
             "Docs/PERFORMANCE.md", "Docs/DEBUG-SYMBOLS.md", "Docs/VALIDATION.md", "Docs/Legal/REVIEW-2026-11-11.md"):
    files.append(ROOT / name)
for path in (ROOT / "ArtworkCatalog/dist").rglob("*"):
    assert not path.is_symlink(), path
    if path.is_file() and path.suffix.lower() in {".html", ".css", ".js", ".json", ".jpg"}:
        files.append(path)
with tarfile.open(output, "w:gz", compresslevel=6) as archive:
    for path in sorted(files):
        assert path.suffix.lower() not in {".3ds", ".cci", ".cxi", ".cia", ".p8", ".p12", ".mobileprovision"}, path
        archive.add(path, arcname="EmuDenSource/" + path.relative_to(ROOT).as_posix(), recursive=False)
    archive.add(upstream, arcname="EmuDenSource/Upstream/" + upstream.name, recursive=False)
with tarfile.open(output) as archive:
    names = archive.getnames()
    assert not any("Private/" in name or "TestGames/" in name or "Contact.json" in name for name in names)
    assert "EmuDenSource/Scripts/patch-azahar.py" in names
    assert "EmuDenSource/Scripts/prepare-mii-fallback.py" in names
    assert "EmuDenSource/Scripts/generate-menu-audio.py" in names
    assert sum(name.startswith("EmuDenSource/Resources/MenuAudio/") and name.endswith(".wav") for name in names) == 9
print(f"Source package verified: {output.name}, {len(names)} files, {output.stat().st_size:,} bytes")
