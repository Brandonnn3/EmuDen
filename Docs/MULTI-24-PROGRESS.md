# Multi-emulator checkpoint — build24

Owner scope: resume PS1/GameCube testing after verifying the live artwork collection. Active worktree `/Volumes/SamsungT7/EmuDenMultiEmulator`, branch `multi-emulator-build24`, based on frozen23. All older releases, artwork and main research work remain preserved. Automations remain paused, App Store release remains held, and physical B Duo is never used.

## Completed

- Catalog version9: all43 covers and43 scenes were fetched anonymously using the unmodified production URLSession/loader/hash path and checked for byte count, SHA256 and actual decoded dimensions. Evidence: `/Volumes/SamsungT7/EmulatorApp/build/Artwork-Catalog-Repair/all-live-verification.json` and its log. The existing public URL/audience and older image URLs are unchanged.
- Ported the PS1/platform/player/save/input changes from original main20 using common build19 as a three-way base. Resolved conflicts in favor of23's legal/resource and user-selected-artwork behavior. No old default gallery/service was restored. The active source compiles with no conflict markers.
- Reused pinned interpreter-only PS1 Device/Simulator binaries and genuine dSYMs, unchanged. Safe3DS/MoltenVK/OpenSSL dependencies resolve to frozen23, not main20's older binaries. Packaged original PS1 demo and original generic console illustration. No GameCube framework/demo in24.
- 91 domain tests pass, one private-resource skip, zero failures: `build/Build24-Preparation/domain-tests.log`.
- Simulator build-for-testing succeeds: `build/Build24-Preparation/simulator-build.log`, products in `build/Build24Simulator`.
- Metadata field/privacy/icon/export preflight, original12 asset checks, four tooling tests and Python tooling compile checks pass. Notice generation preserves95 full texts. Public metadata remains an unsubmitted draft.

## Native verification and archive

Owned Simulator `A63EE573-51BD-4D1B-91B7-97F1422227DE` (EmuDen Multi24 QA). Native PS1 suite checks actual pixels, Apple virtual-controller PAD/stick/release/disconnect, save history/older load/relaunch,3DS switching and both landscape presentations. Log `build/Build24-Preparation/native-ps1.log`, result `PS1-Native.xcresult`. The save/history/relaunch/3DS-switch case passed185.403seconds. Controller landscape fill passed25.614seconds; touch side-space passed24.117seconds. One first cold Simulator launch failed in XCTest before acquiring a process ID; that failure is retained and its virtual-controller case is being rerun alongside artwork bulk/offline and95-notice regression checks in PS1-Regression.xcresult / ps1-regression.log. Current screenshot Native24-player.png shows the actual PS1 rendering/control layout. iOS27 XCTest landscape screenshot attachments are cropped/stale; those are not valid final product previews. Geometry assertions pass, and the corresponding old main20 native simctl captures remain preserved for the unchanged layout.

## Next

Resolve any actual native failures, then produce/validate the signed development24 archive and exact local source package without overwriting older outputs. Record source/archive input hashes and Organizer registration. No upload/submission. Next separate GameCube target25 should build from this repaired baseline, retaining the prototype gate until meaningful actual3D/audio/disc/save checks are met. PS1 phase-one old homebrew evidence lives in main `Docs/PS1-PROGRESS.md`; GC limits/evidence are in main `Docs/GAMECUBE-PROGRESS.md`. Do not repeat unchanged core checks or resurrect the old unsanitized archive recipe.

Signed development archive: build/TestFlight/EmuDen-0.1.0-24.xcarchive. Scripts/archive-testflight.sh finished successfully, including all five genuine app/widget/core dSYMs, actual device platform tags,95 notices, no GameCube binary, original asset scope, privacy, signed entitlement/profile checks and deep signatures. It is registered in Xcode Organizer under November13; actual bytes stay on the SSD. This is not a distribution IPA or upload.
