# Build29 — distribution framework metadata repair

Active isolated worktree /Volumes/SamsungT7/EmuDenDistribution29,
branch distribution-fix-build29, parent44631c2. Owner asked to continue fixing
Apple's28 upload rejection. Preserve28/all older artifacts and owner data.
Automation remains deleted. No binary upload or public release is authorized.

Implemented custom CMake framework plist: MinimumOSVersion18.0, proper platform,
name and valid version fields. Generic framework checks now compare these fields
to each Mach-O's compiled platform/minimum OS in archives and exported IPAs.
Copied Device/Simulator frameworks are corrected/re-signed only in29; normalized
executable hashes and genuine dSYMs remain exactly28.8 removed key/identity
patterns and15 omitted resource payloads are re-screened absent. Full core clean
build/dependencies/source pin and28 gameplay evidence are retained explicitly.
No App/Bridge/Resources/Widgets/UI-test source changes are allowed by the29 gate.

Next: finish packaging tests/CMake-template configuration, relevant native load/
console-switch checks in the owned QA Simulator, current-source signed archive,
export/IPA metadata checks, exact source freeze/package and Organizer registration.
Inspect actual processes/logs before duplicating anything. Never B Duo/owner phone.
All outputs/logs remain under build/Build29 and build/TestFlight on the T7.

## Verified before archive

12 tooling tests pass (missing/blank metadata, platform and minimum mismatch
covered). The actual rejected28 framework fails the new checker, while both29
slices pass. Fresh Device/Simulator CMake configurations produce the same
correct18.0/platform/name/version fields; no unchanged core rebuild was done.
Metadata-Load-Switch.xcresult passes two new native29 scenarios: GX depth/raw
card relaunch71.289s and GameCube→PS1→3DS switching88.762s. Prior28 full-input,
ISO/GCM/state/history/layout evidence is retained and re-read, explicitly
inherited because all runtime sources and normalized core bytes are identical.

Internal disk became tight during SDK/test work. An inactive shared clang SDK
module cache was verified/copied intact to the T7 with its original-path link;
no project source/archive, owner data or saved game was deleted. Evidence is
sdk-cache-relocation.json. No active compiler held the cache during the move.
Next is the current-source signed29 archive/export and exact source package.

## Signed candidate checkpoint

Signed build/TestFlight/EmuDen-0.1.0-29.xcarchive exists. The extended archive
validator checks every embedded framework's declared MinimumOSVersion against
its actual Mach-O minimum/platform, nonempty names/versions, six genuine dSYMs,
identities/privacy/signatures and preserved resource/demo/artwork safeguards.
All four frameworks now have valid18.0 metadata; the GameCube wrapper has the
correct device platform/name/version. See archive-validation.log.

Current input hashes are frozen in BUILD-29-INPUTS.json. Source packaging and
local internal-only IPA validation are next. Never overwrite/rearchive28 or29.
No binary upload, phone use, site publication or automation restart occurred.

## Final local29 checkpoint —15November2026

The corrected signed development archive is complete and registered at
~/Library/Developer/Xcode/Archives/2026-11-15/EmuDen0.1.0(29).xcarchive, linking
to this worktree's build/TestFlight/EmuDen-0.1.0-29.xcarchive. Extended archive
checks pass all four framework deployment/name/version fields, six genuine
matching dSYMs, signatures, identities/privacy and original payload/resource
checks. Both CMake-generated platform plists are correct. Original28 correctly
fails the new checker.12 tooling tests and two fresh native29 scenarios pass;
unchanged gameplay inherits the prior nine28 native scenarios explicitly.

Exact corresponding source:314 files,203030034bytes, SHA256
914ceb884be4bf4692e34c7efc8550df97635329213fb92d9495a3659fc81335.
All97 current/package input hashes match; public support email remains only
under the existing authorization, and private review file/unpublished phone,
credentials, profiles, owner files, .git and build artifacts are excluded.
The original28 source-package SHA and all95 frozen inputs are unchanged.
Receipt: build/Build29-Distribution/distribution.json. Source package/archive
are frozen; this post-packaging delivery addendum does not modify either.

Local internal-only export was attempted once and failed before distribution
signing: Xcode cannot load account credentials (missing Xcode-Username) and
reports no iOS Distribution certificate/private key. Read-only identity checks
find0 accessible distribution identities and2 development identities; actual
CGSSession screen-lock flag is Yes. Do not claim29 has a validated Store IPA
or that Apple accepted it. The corrected framework fields are directly verified
in the real signed archive, so the owner's reported metadata defect is fixed.
No account/certificate was created, no agreement accepted, no upload performed,
and no repeated unlock request made. The existing owner signing-access step
is now the only distribution blocker. Select29 rather than rejected28 when
signing/export is next available; recheck the exported IPA with the new tool.

The owned QA Simulator is shut down, data intact on T7. No builds/tests remain
active. No owner phone/ROM/save or public site/artwork was used/modified, and
the canceled automation remains deleted. Public legal/Apple/source/export
release hold and physical performance/compatibility/motion/fold limitations
remain. No further independent code change is required for this rejection.
