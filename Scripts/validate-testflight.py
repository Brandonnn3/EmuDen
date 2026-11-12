#!/usr/bin/env python3
"""Validate EmuDen release metadata, an optional Xcode archive and signed export."""
from pathlib import Path
import argparse
import json
import plistlib
import re
import struct
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def load_plist(path):
    return plistlib.loads(path.read_bytes())


def check_manifest(path, reasons):
    data = load_plist(path)
    assert data["NSPrivacyTracking"] is False, path
    expected_collection = []
    if path.name == "PrivacyInfo.xcprivacy" and (path.parent == ROOT / "Resources" or path.parent.name == "EmuDen.app") and int(json.loads((ROOT / "TestFlight/AppInformation.json").read_text())["build"]) >= 19:
        expected_collection = [{"NSPrivacyCollectedDataType": name, "NSPrivacyCollectedDataTypeLinked": True,
            "NSPrivacyCollectedDataTypeTracking": False, "NSPrivacyCollectedDataTypePurposes": ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]}
            for name in ["NSPrivacyCollectedDataTypeProductInteraction", "NSPrivacyCollectedDataTypeOtherDataTypes"]]
    assert data["NSPrivacyCollectedDataTypes"] == expected_collection, path
    assert data["NSPrivacyTrackingDomains"] == [], path
    actual = {entry["NSPrivacyAccessedAPIType"]: set(entry["NSPrivacyAccessedAPITypeReasons"])
              for entry in data["NSPrivacyAccessedAPITypes"]}
    assert actual == reasons, (path, actual)


def check_ipa(path, metadata, reasons, public_export=False):
    with tempfile.TemporaryDirectory(prefix="emuden-ipa-", dir=ROOT / "build/TestFlight") as temp:
        with zipfile.ZipFile(path) as archive:
            for entry in archive.infolist():
                assert not entry.filename.startswith("/") and ".." not in Path(entry.filename).parts
                assert entry.external_attr >> 28 != 0xA, "Unexpected symbolic link in IPA"
            archive.extractall(temp)
        apps = list((Path(temp) / "Payload").glob("*.app"))
        assert len(apps) == 1
        app = apps[0]
        info = load_plist(app / "Info.plist")
        assert info["CFBundleDisplayName"] == metadata["name"]
        assert info["CFBundleIdentifier"] == metadata["bundleId"]
        assert info["CFBundleVersion"] == metadata["build"]
        assert info["CFBundleShortVersionString"] == metadata["version"]
        assert info.get("TFInternalTestingOnly") is not True if public_export else info.get("TFInternalTestingOnly") is True
        check_manifest(app / "PrivacyInfo.xcprivacy", reasons["app"])
        for framework in ("Azahar", "MoltenVK"):
            check_manifest(app / f"Frameworks/{framework}.framework/PrivacyInfo.xcprivacy", reasons[framework])
        subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
        output = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(app)], capture_output=True, check=True)
        entitlements = plistlib.loads(output.stdout)
        assert entitlements["get-task-allow"] is False
        assert entitlements["beta-reports-active"] is True
        assert entitlements["application-identifier"] == "NKC9X96J5A." + metadata["bundleId"]
        profile = plistlib.loads(subprocess.run(["security", "cms", "-D", "-i", str(app / "embedded.mobileprovision")], capture_output=True, check=True).stdout)
        assert not profile.get("ProvisionedDevices") and not profile.get("ProvisionsAllDevices")
        assert profile["Entitlements"]["application-identifier"] == entitlements["application-identifier"]
        assert not (app / "Contact.json").exists()
    print("IPA distribution signatures, Store profile, entitlements, identity, privacy and requested export audience passed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", nargs="?", type=Path)
    parser.add_argument("--ipa", type=Path)
    parser.add_argument("--public-export", action="store_true", help="Check an IPA exported for public App Store eligibility rather than internal testing only")
    args = parser.parse_args()
    metadata = json.loads((ROOT / "TestFlight/AppInformation.json").read_text())
    assert metadata["name"] == "EmuDen" and len(metadata["name"]) <= 30
    assert len(metadata["subtitle"]) <= 30
    assert metadata["bundleId"] == "com.brandonaleman.Emulator"
    assert metadata["currentEmulation"] == ["Nintendo 3DS"]
    limits = {"description.txt": 4000, "beta-description.txt": 4000,
              "what-to-test.txt": 4000, "review-notes.txt": 4000,
              "promotional-text.txt": 170, "keywords.txt": 100}
    for name, limit in limits.items():
        text = (ROOT / "TestFlight/en-US" / name).read_text().strip()
        assert 0 < len(text) <= limit, (name, len(text), limit)
        assert not re.search(r"\b(TODO|TBD|PLACEHOLDER)\b", text), name
    contact = json.loads((ROOT / "TestFlight/Private/Contact.json").read_text())
    assert re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", contact["feedbackEmail"])
    assert re.fullmatch(r"\+[1-9][0-9]{7,14}", contact["betaReviewContact"]["phone"])
    export = load_plist(ROOT / "TestFlight/ExportOptions.plist")
    assert export["method"] == "app-store-connect" and export["destination"] == "export"
    assert export["testFlightInternalTestingOnly"] is True
    assert export["manageAppVersionAndBuildNumber"] is False
    if int(metadata["build"]) >= 19:
        public_export = load_plist(ROOT / "TestFlight/AppStoreExportOptions.plist")
        assert public_export["method"] == "app-store-connect" and public_export["destination"] == "export"
        assert public_export.get("testFlightInternalTestingOnly") is not True
        assert public_export["manageAppVersionAndBuildNumber"] is False
        plan = json.loads((ROOT / "TestFlight/Submission/StoreListing.json").read_text())
        assert plan["price"] == 0 and plan["territories"] == ["USA"] and plan["release"] == "MANUAL"
        assert plan["build"] == metadata["build"] and plan["publicSubmissionReady"] is False
    icon = (ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png").read_bytes()
    assert icon[:8] == b"\x89PNG\r\n\x1a\n"
    width, height, _, color_type = struct.unpack_from(">IIBB", icon, 16)
    assert (width, height) == (1024, 1024) and color_type in (0, 2), "Icon must be opaque RGB/grayscale"
    reasons = {
        "app": {"NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1"},
                "NSPrivacyAccessedAPICategoryFileTimestamp": {"C617.1", "3B52.1"},
                "NSPrivacyAccessedAPICategoryUserDefaults": {"CA92.1"}},
        "Azahar": {"NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1"},
                   "NSPrivacyAccessedAPICategoryFileTimestamp": {"C617.1"}},
        "MoltenVK": {"NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1"}},
    }
    check_manifest(ROOT / "Resources/PrivacyInfo.xcprivacy", reasons["app"])
    for framework in ("Azahar", "MoltenVK"):
        check_manifest(ROOT / f"Resources/Privacy/{framework}.xcprivacy", reasons[framework])
    print("Metadata, field limits, private contact, internal-only export, icon and privacy checks passed")
    print("Technical internal-beta packaging only; this does not clear copyright, licensing, export classification or public App Review. See TestFlight/AppStoreReadiness.json.")
    if args.ipa:
        check_ipa(args.ipa, metadata, reasons, args.public_export)
    if not args.archive:
        return
    archive = args.archive.resolve()
    apps = list((archive / "Products/Applications").glob("*.app"))
    assert len(apps) == 1
    app = apps[0]
    info = load_plist(app / "Info.plist")
    for key, value in {"CFBundleDisplayName": "EmuDen", "CFBundleIdentifier": metadata["bundleId"],
                       "CFBundleShortVersionString": metadata["version"], "CFBundleVersion": metadata["build"]}.items():
        assert info.get(key) == value, (key, info.get(key), value)
    assert set(info["UIDeviceFamily"]) == {1, 2}
    if int(metadata["build"]) >= 19:
        export_assessment = json.loads((ROOT / "Docs/Legal/EXPORT-ASSESSMENT-19.json").read_text())
        assert export_assessment["build"] == metadata["build"] and export_assessment["territories"] == ["USA"]
        assert export_assessment["usesEncryption"] is True and export_assessment["usesNonExemptEncryption"] is False
        assert info.get("ITSAppUsesNonExemptEncryption") is False
        assert "ITSEncryptionExportComplianceCode" not in info
    else:
        assert "ITSAppUsesNonExemptEncryption" not in info, "Older build retains its original export declaration"
    check_manifest(app / "PrivacyInfo.xcprivacy", reasons["app"])
    for framework in ("Azahar", "MoltenVK"):
        folder = app / f"Frameworks/{framework}.framework"
        check_manifest(folder / "PrivacyInfo.xcprivacy", reasons[framework])
        result = subprocess.run(["xcrun", "vtool", "-show-build", str(folder / framework)],
                                capture_output=True, text=True, check=True)
        assert re.search(r"platform\s+IOS\b", result.stdout) and "IOSSIMULATOR" not in result.stdout
        subprocess.run([sys.executable, str(ROOT / "Scripts/check-debug-symbols.py"),
                        str(folder / framework), str(archive / f"dSYMs/{framework}.framework.dSYM")], check=True)
    if int(metadata["build"]) >= 17:
        widget = app / "PlugIns/EmuDenWidgets.appex"
        widget_info = load_plist(widget / "Info.plist")
        assert widget_info["CFBundleIdentifier"] == metadata["bundleId"] + ".Widgets"
        assert widget_info["CFBundleVersion"] == metadata["build"]
        assert widget_info["CFBundleShortVersionString"] == metadata["version"]
        assert widget_info["NSExtension"]["NSExtensionPointIdentifier"] == "com.apple.widgetkit-extension"
        check_manifest(widget / "PrivacyInfo.xcprivacy", {"NSPrivacyAccessedAPICategoryFileTimestamp": {"C617.1"}})
        for bundle in [app, widget]:
            signed = plistlib.loads(subprocess.run(["codesign", "-d", "--entitlements", ":-", str(bundle)], capture_output=True, check=True).stdout)
            profile = plistlib.loads(subprocess.run(["security", "cms", "-D", "-i", str(bundle / "embedded.mobileprovision")], capture_output=True, check=True).stdout)
            if int(metadata["build"]) >= 19:
                if bundle == app:
                    domains = ["applinks:emuden-support.headyopossum2.chatgpt.site"]
                    assert signed["com.apple.developer.associated-domains"] == domains
                    assert signed["com.apple.developer.declared-age-range"] is True
                    allowed = profile["Entitlements"].get("com.apple.developer.associated-domains", [])
                    assert "*" in allowed or all(domain in allowed for domain in domains)
                    assert profile["Entitlements"]["com.apple.developer.declared-age-range"] is True
                else:
                    assert "com.apple.developer.associated-domains" not in signed
                    assert "com.apple.developer.declared-age-range" not in signed
            assert signed["com.apple.security.application-groups"] == ["group.com.brandonaleman.Emulator"]
            assert "group.com.brandonaleman.Emulator" in profile["Entitlements"]["com.apple.security.application-groups"]
        subprocess.run([sys.executable, str(ROOT / "Scripts/check-debug-symbols.py"),
                        str(widget / widget_info["CFBundleExecutable"]), str(archive / "dSYMs/EmuDenWidgets.appex.dSYM")], check=True)
        print("Widget extension identity, privacy, shared App Group profiles/signatures and real matching dSYM passed")
    for path in app.rglob("*"):
        assert path.name != "Contact.json", "Private review contact must not ship in the app"
        assert path.suffix.lower() not in {".3ds", ".cci", ".cxi", ".cia", ".elf", ".axf", ".p8", ".p12", ".storekit"}, path
    assert (app / "boot.3dsx").is_file()
    assert (app / "Azahar-LICENSE.txt").is_file() and (app / "MoltenVK-LICENSE.txt").is_file()
    if int(metadata["build"]) >= 18:
        assert (app / "ThirdPartyNotices.txt").read_bytes() == (ROOT / "Resources/ThirdPartyNotices.txt").read_bytes()
        print("Complete dependency notices match the bundled offline copy")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    subprocess.run([sys.executable, str(ROOT / "Scripts/check-debug-symbols.py"),
                    str(app / info["CFBundleExecutable"]), str(archive / f"dSYMs/{app.name}.dSYM")], check=True)
    print("Archive identity, device frameworks, manifests, licensed demo, private-data exclusion and signatures passed")
    print("Apple processing and export-compliance answers are not checked by this local validator")


if __name__ == "__main__":
    main()
