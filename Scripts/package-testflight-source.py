#!/usr/bin/env python3
"""Package the matching source using a strict allowlist; never include user games or contacts."""
from pathlib import Path
import hashlib
import json
import re
import tarfile

ROOT = Path(__file__).resolve().parent.parent
resource_policy = json.loads((ROOT / "Docs/Legal/SANITIZED-UPSTREAM-21.json").read_text())
upstream = ROOT / resource_policy["derivedArchive"]
assert hashlib.sha256(upstream.read_bytes()).hexdigest() == resource_policy["derivedArchiveSHA256"]
extra_sources = []
tls = json.loads((ROOT / "Docs/Legal/OPENSSL-PROVENANCE-22.json").read_text())
extra_sources.append((ROOT / "Upstream/openssl-3.5.9.tar.gz", tls["sha256"]))
font = json.loads((ROOT / "Docs/Legal/FONT-PROVENANCE-22.json").read_text())["unifontSource"]
extra_sources.append((ROOT / "Upstream/unifont-10.0.05.tar.gz", font["sha256"]))
for item in json.loads((ROOT / "Docs/Legal/FALLBACK-RESOURCE-SOURCES-22.json").read_text())["records"]:
    extra_sources.append((ROOT / item["sourceArchive"], item["sha256"]))
ps1 = json.loads((ROOT / "Vendor/PCSX-ReARMed/source-manifest.json").read_text())
extra_sources.append((ROOT / "Upstream" / ps1["archive"], ps1["archiveSHA256"]))
dolphin = json.loads((ROOT/'Vendor/Dolphin/source-manifest.json').read_text())
extra_sources.append((ROOT/'Upstream'/dolphin['archive'],dolphin['archiveSHA256']))
for path, digest in extra_sources:
    assert path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == digest, path
metadata = json.loads((ROOT / "TestFlight/AppInformation.json").read_text())
project_versions = set(re.findall(r"CURRENT_PROJECT_VERSION = (\d+);", (ROOT / "EmulatorApp.xcodeproj/project.pbxproj").read_text()))
assert project_versions == {metadata["build"]}, "Project and source-package build must match; prepare metadata before packaging"
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
             "Docs/PERFORMANCE.md", "Docs/DEBUG-SYMBOLS.md", "Docs/VALIDATION.md", "Docs/Legal/REVIEW-2026-11-11.md"):
    files.append(ROOT / name)
for name in ("Docs/BUILD-21.md", "Docs/RELEASE-21-PROGRESS.md", "Docs/Legal/ASSET-REGISTER-21.json", "Docs/Legal/SANITIZED-UPSTREAM-21.json", "Docs/Legal/CORE-RESOURCE-POLICY-21.json", "Docs/Legal/TECHNICAL-VALIDATION-21.json", "Docs/Legal/RELEASE-21-REVIEW.md", "Docs/Legal/EXPORT-ASSESSMENT-21.json"):
    files.append(ROOT / name)
for name in ("Docs/BUILD-22.md", "Docs/Legal/OPENSSL-PROVENANCE-22.json", "Docs/Legal/TLS-REPLACEMENT-VERIFICATION-22.json", "Docs/Legal/FONT-PROVENANCE-22.json", "Docs/Legal/FALLBACK-RESOURCE-SOURCES-22.json", "Docs/Legal/LEGAL-REVIEW-PROGRESS-2026-11-12.md", "Docs/Legal/RELEASE-22-LEGAL-DECISION.md", "Docs/Legal/EXPORT-ASSESSMENT-22.json", "Docs/Legal/CORE-RESOURCE-POLICY-22.json", "Docs/Legal/APP-RESOURCE-VERIFICATION-22.json", "Docs/Legal/DEPENDENCY-INVENTORY-22.json", "Docs/Legal/DELTA-COMPARISON-2026-11-12.md", "Docs/Legal/DELTA-COMPARISON-2026-11-12.json"):
    files.append(ROOT / name)
files += [ROOT / "Docs/BUILD-23.md", ROOT / "Docs/ARTWORK-CATALOG-PROGRESS.md", ROOT / "Docs/Legal/EXPORT-ASSESSMENT-23.json"]
files += [ROOT / name for name in (
    "Docs/BUILD-24.md", "Docs/MULTI-24-PROGRESS.md", "Docs/Legal/ASSET-REGISTER-24.json",
    "Docs/Legal/EXPORT-ASSESSMENT-24.json", "Docs/Legal/DEPENDENCY-INVENTORY-24.json", "Vendor/PCSX-ReARMed/PROVENANCE.md",
    "Vendor/PCSX-ReARMed/source-manifest.json")]
files += [ROOT / name for name in (
    "Docs/BUILD-25.md", "Docs/Legal/EXPORT-ASSESSMENT-25.json",
    "Docs/Legal/DEPENDENCY-INVENTORY-25.json")]
files += [ROOT / name for name in ("Docs/BUILD-27.md", "Docs/BUILD-27-INPUTS.json", "Docs/BUILD-27-PROGRESS.md", "Docs/Legal/EXPORT-ASSESSMENT-27.json", "Docs/Legal/DEPENDENCY-INVENTORY-27.json")]
files += [ROOT/name for name in ('Docs/BUILD-28.md','Docs/BUILD-28-INPUTS.json','Docs/BUILD-28-VERIFICATION.json',
    'Docs/BUILD-28-PROGRESS.md','Docs/Legal/EXPORT-ASSESSMENT-28.json','Docs/Legal/DEPENDENCY-INVENTORY-28.json',
    'Docs/Legal/GAMECUBE-CORE-BUILD-28.json','Vendor/Dolphin/source-manifest.json','Vendor/Dolphin/PROVENANCE.md')]
frozen = json.loads((ROOT/'Docs/BUILD-28-INPUTS.json').read_text())
if metadata['build'] in ['29','30','31','32','33','34','35','36','37']:
    files += [ROOT/name for name in ['Docs/BUILD-29.md','Docs/BUILD-29-PROGRESS.md','Docs/BUILD-29-INPUTS.json',
        'Docs/BUILD-29-VERIFICATION.json','Docs/Legal/GAMECUBE-CORE-BUILD-29.json','Docs/Legal/EXPORT-ASSESSMENT-29.json','Docs/Legal/DEPENDENCY-INVENTORY-29.json']]
    frozen=json.loads((ROOT/'Docs/BUILD-29-INPUTS.json').read_text())
if metadata['build'] in ['30','31','32','33','34','35','36','37']:
    files += [ROOT/name for name in ['Docs/BUILD-30.md','Docs/BUILD-30-PROGRESS.md','Docs/BUILD-30-INPUTS.json',
        'Docs/BUILD-30-VERIFICATION.json','Docs/Legal/GAMECUBE-CORE-BUILD-30.json','Docs/Legal/EXPORT-ASSESSMENT-30.json','Docs/Legal/DEPENDENCY-INVENTORY-30.json']]
    frozen=json.loads((ROOT/'Docs/BUILD-30-INPUTS.json').read_text())
if metadata['build'] in ['31','32','33','34','35','36','37']:
    files += [ROOT/name for name in ['Docs/BUILD-31.md','Docs/BUILD-31-PROGRESS.md','Docs/BUILD-31-INPUTS.json',
        'Docs/BUILD-31-VERIFICATION.json','Docs/Legal/GAMECUBE-CORE-BUILD-31.json','Docs/Legal/EXPORT-ASSESSMENT-31.json','Docs/Legal/DEPENDENCY-INVENTORY-31.json']]
    frozen=json.loads((ROOT/'Docs/BUILD-31-INPUTS.json').read_text())
if metadata['build'] in ['32','33','34','35','36','37']:
    files += [ROOT/name for name in ['Docs/BUILD-32.md','Docs/BUILD-32-PROGRESS.md','Docs/BUILD-32-INPUTS.json',
        'Docs/BUILD-32-VERIFICATION.json','Docs/Legal/GAMECUBE-CORE-BUILD-32.json','Docs/Legal/EXPORT-ASSESSMENT-32.json','Docs/Legal/DEPENDENCY-INVENTORY-32.json']]
    frozen=json.loads((ROOT/'Docs/BUILD-32-INPUTS.json').read_text())
if metadata['build'] in ['33','34','35','36','37']:
    files += [ROOT/name for name in ['Docs/BUILD-33.md','Docs/BUILD-33-PROGRESS.md','Docs/BUILD-33-INPUTS.json',
        'Docs/BUILD-33-VERIFICATION.json','Docs/Legal/GAMECUBE-CORE-BUILD-33.json','Docs/Legal/EXPORT-ASSESSMENT-33.json','Docs/Legal/DEPENDENCY-INVENTORY-33.json']]
    frozen=json.loads((ROOT/'Docs/BUILD-33-INPUTS.json').read_text())
if metadata['build'] in ['34','35','36','37']:
    files += [ROOT/name for name in ['Docs/BUILD-34.md','Docs/BUILD-34-PROGRESS.md','Docs/BUILD-34-INPUTS.json',
        'Docs/BUILD-34-VERIFICATION.json','Docs/BUILD-34-NATIVE-STAGES.json','Docs/Legal/GAMECUBE-CORE-BUILD-34.json','Docs/Legal/EXPORT-ASSESSMENT-34.json','Docs/Legal/DEPENDENCY-INVENTORY-34.json','Docs/Legal/ASSET-REGISTER-34.json','Docs/Design/Build34-Console-Art/prompt.json','Docs/Design/Build34-Console-Art/PROVENANCE.md','Docs/Design/Build34-Console-Art/Console-gamecube-master.png']]
    frozen=json.loads((ROOT/'Docs/BUILD-34-INPUTS.json').read_text())
if metadata['build'] in ['35','36','37']:
    files += [ROOT/name for name in ['Docs/BUILD-35.md','Docs/BUILD-35-PROGRESS.md','Docs/BUILD-35-INPUTS.json',
        'Docs/BUILD-35-VERIFICATION.json','Docs/BUILD-35-NATIVE-STAGES.json','Docs/Legal/GAMECUBE-CORE-BUILD-35.json','Docs/Legal/EXPORT-ASSESSMENT-35.json','Docs/Legal/DEPENDENCY-INVENTORY-35.json']]
    frozen=json.loads((ROOT/'Docs/BUILD-35-INPUTS.json').read_text())
if metadata['build'] in ['36','37']:
    files += [ROOT/name for name in ['Docs/BUILD-36.md','Docs/BUILD-36-PROGRESS.md','Docs/BUILD-36-INPUTS.json',
        'Docs/BUILD-36-VERIFICATION.json','Docs/BUILD-36-PERFORMANCE.json','Docs/BUILD-36-NATIVE-STAGES.json',
        'Docs/Legal/GAMECUBE-CORE-BUILD-36.json','Docs/Legal/EXPORT-ASSESSMENT-36.json','Docs/Legal/DEPENDENCY-INVENTORY-36.json']]
    frozen=json.loads((ROOT/'Docs/BUILD-36-INPUTS.json').read_text())
if metadata['build']=='37':
    files += [ROOT/name for name in ['Docs/BUILD-37.md','Docs/BUILD-37-PROGRESS.md','Docs/BUILD-37-INPUTS.json',
        'Docs/BUILD-37-VERIFICATION.json','Docs/BUILD-37-NATIVE-STAGES.json','Docs/BUILD-37-ARTWORK.json',
        'Docs/Legal/GAMECUBE-CORE-BUILD-37.json','Docs/Legal/EXPORT-ASSESSMENT-37.json','Docs/Legal/DEPENDENCY-INVENTORY-37.json']]
    frozen=json.loads((ROOT/'Docs/BUILD-37-INPUTS.json').read_text())
assert frozen['build']==metadata['build'] and metadata['build'] in ['28','29','30','31','32','33','34','35','36','37']
for name,sha in frozen['inputs'].items():
    assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==sha, name
with tarfile.open(output, "w:gz", compresslevel=6) as archive:
    for path in sorted(files):
        assert path.suffix.lower() not in {".3ds", ".cci", ".cxi", ".cia", ".p8", ".p12", ".mobileprovision"}, path
        archive.add(path, arcname="EmuDenSource/" + path.relative_to(ROOT).as_posix(), recursive=False)
    archive.add(upstream, arcname="EmuDenSource/Upstream/" + upstream.name, recursive=False)
    for path, _ in extra_sources:
        archive.add(path, arcname="EmuDenSource/Upstream/" + path.name, recursive=False)
with tarfile.open(output) as archive:
    names = archive.getnames()
    assert not any("Private/" in name or "TestGames/" in name or "Contact.json" in name for name in names)
    assert "EmuDenSource/Scripts/patch-azahar.py" in names
    assert "EmuDenSource/Scripts/prepare-mii-fallback.py" in names
    assert "EmuDenSource/Scripts/generate-menu-audio.py" in names
    assert "EmuDenSource/Scripts/build-ps1-core.py" in names
    assert "EmuDenSource/Upstream/" + ps1["archive"] in names
    assert "EmuDenSource/Tests/Fixtures/EmuDen-PS1-Demo.exe" in names
    assert 'EmuDenSource/Upstream/'+dolphin['archive'] in names
    for name,sha in frozen['inputs'].items():
        assert hashlib.sha256(archive.extractfile('EmuDenSource/'+name).read()).hexdigest()==sha, name
    assert sum(name.startswith("EmuDenSource/Resources/MenuAudio/") and name.endswith(".wav") for name in names) == 9
print(f"Source package verified: {output.name}, {len(names)} files, {output.stat().st_size:,} bytes")
