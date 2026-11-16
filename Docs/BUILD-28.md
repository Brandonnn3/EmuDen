# EmuDen0.1.0 build28 — internal three-console candidate

This isolated candidate combines preserved27's3DS/PS1 player work with pinned
Dolphin2609, revisionf84df02055ab9610feec48e65648cac5a3c098fa. GameCube uses
Cached Interpreter, native Metal, public PCM audio, Main/C-stick, partial analog
triggers and separate full clicks, local per-game raw cards and snapshots/history.
No CPU JIT, executable allocation workaround, private broker or firmware is used.

GameCube imports: validated MEM1 DOL, complete uncompressed GameCube ISO/GCM.
RVZ, Wii discs, ELF and compressed archives are unsupported. PS1 accepts CHD v5,
CUE with every referenced BIN track and PS-X EXE.3DS requires supported decrypted
3ds/cci/cxi/app/3dsx/elf/axf files. Only import files/data you may use.

Verified original homebrew covers native GX color/depth, SI axes/triggers and
release, audio, import/state/history/relaunch, raw EXI card write/flush/fresh
relaunch, console switching and controller/touch landscape. The card diagnostic
writes an unused sector of its newly generated QA card; allocated retail game
save-files, retail compatibility and phone speed are not established by it.
Physical3DS gyro/WarioWare, Duo folding, signed regional services/widgets and
retail behavior remain device tests. Existing27 enhancements are retained.

Landscape controller play fills the display and hides touch controls. Touch
play reserves side space. Correct portrait library geometry, optional selected
artwork sources, age-timeout/import/privacy safeguards and source/default-key
remediation from22–27 remain. No default artwork provider is enabled.

Rebuilding corresponding source on an Apple silicon Mac requires Xcode with
an iOS18+ SDK, Python3, CMake3.31.6 and Ninja1.11.1 (compatible later tools may
change output). Rebuild preserved dependencies using their included scripts/
manifests. Scripts/build-gamecube-core.py verifies/extracts the complete pinned
sanitized Dolphin archive and initialized dependencies without Git/network:

    python3 Scripts/build-gamecube-core.py --verify-source
    python3 Scripts/build-gamecube-core.py --target all

The local candidate used a fresh full core/dependency build for each iOS slice,
then normal CMake rebuilt the frontend for the explicit XFB-to-RAM compatibility
setting. No iterative26 archive/prototype was substituted. Clean-build and final
frontend-update hashes are in Docs/Legal/GAMECUBE-CORE-BUILD-28.json. Raw source
omissions are recorded without key bytes in Vendor/Dolphin/source-manifest.json.
No .git history or removed key/resource defaults enter portable source archives.

App build28 explicitly enables EMUDEN_EXPERIMENTAL_GAMECUBE=YES. The embed step
requires current native evidence, source/binary/resource hashes and genuine
matching symbols before archiving. Rebuilders must repeat native checks for
changed inputs and record new actual binary/evidence hashes; no bit-for-bit
binary identity across toolchains is promised. Use owned QA Simulators and
original included diagnostics, never owner's devices or saves. The archive
validator verifies all six matching app/widget/core symbol bundles.

148 verbatim offline notices include upstream dependency terms. Preserved
license whitespace is intentional. Exact source packaging excludes private
review contacts, signing data, owner files and build evidence artifacts.

This is a local internal candidate, not an App Store release. No28 upload is
authorized. Free/US/manual public-release drafts and all existing legal/source/
Apple/name/export/provider review holds remain. No legal clearance, Apple
acceptance, broad retail compatibility or phone performance claim is made.
The old continuation automation was deleted and must not be recreated.
