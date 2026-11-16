# Build28 —3DS, PS1 and GameCube internal candidate

Owner explicitly requested one new build with all three emulators. Continue
this manual task until the concrete local candidate is complete or a real
external blocker occurs. The recurring automation was deleted; never recreate it.

Active worktree /Volumes/SamsungT7/EmuDenAll28, branch all-emulators-build28,
based on frozen27 commit817f610. Frozen25/27 and all earlier signed/source
releases, main20 research, artwork/URLs/masters and owner data remain intact.
Only owned QA Simulator F8B53262-5995-49D8-976A-EFE4BAD728C7 (iOS27.0) is used.
Never B Duo, owner phones, games or saves. No28 upload/public release/third-party
contact/agreement/spending is authorized. Public-release hold remains.

## Actual native verification

Under build/Build28:
- Analog-Sanitized-1.xcresult passes33.780s: Main/C-stick, partial analog triggers
  without digital clicks, full presses, NaN/clamp, pause/disconnect neutral,
  public GCVirtualController mapping and state restoration through actual SI.
- GX-Native-Card-3.xcresult passes38.474s: real CP/XF/BP GX triangles, near red
  occludes far blue with visible outer blue; native screenshot verifies output.
  Guest EXI PageProgram writes454d4338cafebabe to a fresh QA raw card. Teardown
  flushes and a fresh no-resume relaunch reads it through guest ReadArray.
  This proves raw-sector persistence, not an allocated retail game save-file.
- ThreeConsole-Regressions-1.xcresult passes six cases: actual uncompressed
  ISO/GCM validation/import/boot/audio/input/state; DOL history/preview/resume/
  relaunch; full-display hidden-touch controller landscape; side-space touch
  landscape; actual GameCube→PS1→3DS switching and three-console menu selection.
-10 Python tooling checks pass;102 domain tests pass with1 private-resource skip.
  GameCube-Settings-2.xcresult passes42.292s: ordinary per-game settings show
  single-screen GameCube options and omit3DS shaders/motion/dual-screen controls.
  The first settings attempt failed on the test querying OtherElement instead
  of the existing ScrollView; correcting only that query passed. Failure kept.
  Current tooling/domain checks pass again; strict candidate-gate-1.log passes.

The XFB black-output defect is fixed by explicit real XFB copies to RAM,
not a fake screenshot or GPU/JIT bypass. Final original GX scissor is corrected.
Both complete sanitized CMake core/dependency builds pass for Simulator/iOS,
then normal CMake frontend rebuild applies that compatibility setting. Matching
real DWARF dSYMs, raw framework hashes,8-pattern and15 omitted-resource
absence are recorded in
Docs/Legal/GAMECUBE-CORE-BUILD-28.json. Public CoreServices exists in the actual
iPhoneOS27.2 SDK; Device link uses Apple/platform libraries. No private JIT
broker/executable allocation is added. New binaries remain local Vendor/Dolphin.

## Corresponding source/resources

The initial unsanitized core had8 unused Wii factory key/identity patterns;
all initial binaries are quarantined in Build28-Initial-Core/older build dirs.
The isolated Source now zeroes those defaults and removes GC DSP ROM/coefficients,
console fonts and Wii resources. Original shared source/prototype is untouched.
Derived portable Dolphin archive f0481bdf455d4039ea6177b9c6a9f149e56b2df11699c00e477d0045898f095f
has23182 regular files,49735351bytes; no.git/owner files or omitted key bytes.
Source raw/C++-literal key screening passes. Complete initialized dependencies,
patches, licenses and resource policy are included.148 verbatim offline notices
are generated/checked; upstream notice whitespace is intentionally preserved.
PortableGCSourceQA extracted without Git, compared every file to the verified
archive, and genuinely configured arm64 iOS CMake successfully. See
portable-source-check.json/log. A redundant full second core build was skipped.

## Implementation

27 portrait covers, PS1 resolution/speed/fold panel and3DS CoreMotion remain.
GameCube adds corrected shaped X/Y Main Stick, full C-stick and separate partial
trigger/full-click C ABI/bridge/Swift/touch/controller paths. Pause/load/disconnect
release all input. Native card/state/audio lifecycle is platform/game-separated.
Internal28 explicitly enables GameCube and ordinary imports/demo/settings;
no3DS shader/upscaler options are presented as GameCube settings. Formats are
validated GameCube MEM1 DOL and complete uncompressed ISO/GCM; RVZ/Wii rejected.
The archive script now requires real current native/source/hash/symbol evidence,
plus matching framework privacy, rather than deleting the development guard.

## Signed archive and final source preparation

Signed development archive: build/TestFlight/EmuDen-0.1.0-28.xcarchive.
Development-archive.log succeeds. Archive-validation-2.log passes app/widget
identity/profiles/entitlements, all six genuine matching dSYMs, deep signatures,
148 notices, optional artwork scope, exact four original GameCube diagnostics,
privacy and resource/private-data exclusions. All pre-signature executable/load
command bytes match the validated Device core; only code-signature fields and
derived LINKEDIT sizes are normalized. The first validator's remove-signature
comparison failed on Apple's envelope sizes; the minimal replacement has actual
signature-change/code-tamper tests. No app/core/archive code changed or rearchive
occurred for that tooling correction. Failed validation remains preserved.

95 current app/resource/core-build inputs and four Device core hashes are in
BUILD-28-INPUTS.json. Exact portable corresponding-source packaging and external
SHA receipt are the final pending steps. Compiled source implementation is at
3613603; later manifest/tool/delivery commits do not change app/runtime code.
Do not overwrite/rearchive this candidate. No export/upload/public submission.

Preservation check:25 and27 source-package SHA values and both archive signatures
are unchanged/valid.27 current/package inputs match all80 old manifest entries.
The existing25 input manifest is stale relative to14 current artwork/source
files and some members of its already-preserved exact-hash package; see
preserved-releases.json for exact names. Do not repeat the older blanket claim
that all25 manifest members match, roll back its working tree or overwrite any
old artifact. No old artifact/working-tree file was modified by28. The new28
source package receives its own strict per-member hash check.

Native landscape screenshots were visually inspected after frame assertions:
controller video fills the display without touch controls; touch has Main Stick/
D-pad left and face buttons/C-stick right, without video overlap. Portable
source extraction/exact file verification and actual arm64 iOS CMake configure
pass without Git. Physical phone speed/retail save-file allocation/compatibility,
gyro/WarioWare/Duo folding, signed regional services/widgets, legal clearance
and Apple acceptance remain unverified. No public site/artwork change occurred.

## Environment/failure evidence preserved

New QA device hit internal ENOSPC. Only that new device's complete data was
moved intact to build/SimulatorData with an original-path symlink. No other
apps/caches/user data were removed. iOS26/27.1 creation attempts incompatible;
actual27.0 works. Initial black GX/installation tests and stopped partial initial
Device build remain in logs. Never overwrite evidence or recreate the QA device.

## Final local delivery —14November2026

Build28 is complete as a local signed development candidate with all three
emulators. The archive passed the strict validator and is registered through
a new Xcode Organizer archive link; no older link/artifact was replaced.

Exact source: build/TestFlight/EmuDen-0.1.0-28-source.tar.gz,304 files,
203019629bytes, SHA256
4a6bde255bc69db44f18158e5dc092648eac650c8af0ac13e87902fd3f16636b.
All95 frozen current/source-package input hashes match. Source tree at packaging
is6adcfc8; the input/source implementation record is42a20a3. All four Device
core hashes and six real matching symbol bundles are retained. Receipt:
build/Build28-Distribution/distribution.json and source.sha256. This addendum
is an external delivery record after packaging; it does not alter the frozen
archive, package or compiled inputs. Never overwrite them.

Private Contact.json, unpublished review phone/contact, credentials, profiles,
owner ROMs/saves/system data and build/QA artifacts are excluded. The initial
contact-byte scan was overly broad: the support email is expressly authorized
public in OWNER-AUTHORIZATION-2026-11-11.json and also reused for review. Only
that already-authorized public contact remains in support/privacy/history
documents. No private phone or unpublished contact entered the package.

QA Simulator was shut down after all checks; its data remains preserved on
SSD. No builds/tests remain active. No owner phone/files were used. The old
automation remains deleted and must not be recreated. No export, TestFlight
upload, site/artwork publication, public submission, agreement or spending
occurred. Physical GameCube speed/retail save-file allocation/compatibility,
3DS gyro/WarioWare/Duo folding and signed regional/widget behavior remain
owner-device checks. Public legal/Apple/source/export review hold remains.

Next external step, if the owner requests it: distribution-sign/export this
specific28 for internal TestFlight once account/signing access is available.
Only25 had earlier explicit upload authorization; do not infer public release
or a28 upload from this local-build request. Do not repeat unlock requests.

## Distribution disk-space recovery —14November2026 evening

Owner supplied Organizer's failed-to-write-symbols screenshot. Actual GUI
distribution logs show NSCocoaError640 / POSIX28: Macintosh HD out of space
while creating Azahar UUID C0D0C452-1111-3FD9-9DB0-C803792A51E9.symbols.
It was a storage failure, not evidence of missing/mismatched DWARF. Internal
free space was123MiB; T7 had542GiB available.

Only inactive temporary distribution folders positively identified as EmuDen
were copied to build/Distribution-Recovery-2026-11-14/Preserved-Xcode-Temporary,
verified file by file, then relocated with original-path symlinks. Other
projects, owner files, archives, artwork and all existing saves were untouched.
Roughly1.9GiB was recovered before retry. Original logs and per-file inventories
are retained in the same ignored recovery directory. No data was discarded.

The exact28 archive then exported successfully using the existing internal-only
export options, destination=export, without provisioning-update permission.
Xcode completed IDEDistributionSymbolsStep. Internal-Export/EmuDen.ipa passes
validate-testflight.py --ipa: distribution signatures, Store profiles, internal
audience, entitlements, identity, framework privacy and original demo payloads.
No upload occurred. The source package SHA and all95 frozen inputs are unchanged.
See export.log, ipa-validation.log and recovery.json for actual evidence/IPA hash.
The first28 delivery receipt remains an accurate record as of its earlier time;
this local export is a later explicitly prompted troubleshooting operation.

The owner can cancel the failed dialog and retry Distribute App in Organizer.
No28 binary upload/public release, agreement, purchase, owner-phone operation or
automation restart was performed. Public release remains held.
