# Validation

This is an early native SwiftUI 3DS test build on the Samsung T7 SSD. iPhone Duo is the primary layout and hardware target.

**EmuDen 0.1.0 (3)** is prepared for internal TestFlight. The renamed Release archive, distribution-signed IPA, icon, app/framework privacy manifests and local metadata passed packaging checks. Two Release UI regressions passed after the branding/privacy changes: homebrew GPU boot/close/reopen and library/system setup (`build/EmuDen-Branding.xcresult`). The exported app has `TFInternalTestingOnly=true`, beta reporting enabled and debugging disabled. Xcode created the live app record and exported locally; no build was uploaded. [Handoff and exact status](../TestFlight/STATUS.md).

## Passed

- **12 domain tests:** import/persistence, invalid files, corrupt catalogs, system-data staging/rollback, Mii archive detection, both fold axes, inactive folds and controller-driven screen expansion. `build/duo-domain-tests.log`.
- **7 build-2 Duo simulator UI tests:** actual GPU rendering after startup, closing/reopening emulation, book/tabletop layout fixtures, touch controls, pause/return, controller expansion with working lower-screen touch, the console library/system setup, and local Mario Golf/Ocarina startup. `build/Duo-Build2-Validation.xcresult`. All seven passed in Release configuration.
- **Signed Release iPhone build 2 and B Duo installation:** `build/b-duo-build2.log` and `build/b-duo-build2-install.json`. The existing signed-in Xcode account refreshed the provisioning profile to include B Duo. The device-specific build passed deep, strict code-signature verification and installed successfully as `com.brandonaleman.Emulator`. Existing saves were backed up to `build/B-Duo-Before-Build2/Saves` before the update.
- **Simulator and device core rebuilds:** pinned Azahar 2126.2 with Vulkan and software rendering enabled, OpenGL disabled. MoltenVK 1.4.2 is checksum-pinned and embedded per platform.
- **Local Mario Golf native UI test:** at least 600 displayed frames with colored output and a clean return to the library. `build/Mario-Golf-Native.xcresult`. The later GPU core revision also passed the homebrew/reopen regression (`build/Duo-GPU-Regression.xcresult`).
- **Mario Golf desktop core test:** first-run save/profile setup and a rendered golf scene; reopening the same save directory also reached the golf scene. [Detailed evidence and limits](MARIO-GOLF-VALIDATION.md).

The native rendering test waits for at least 60 delivered frames and verifies colored pixels inside the emulated screen, then closes and reopens the core. It does not accept an initial blank frame as the result.

## Core changes

`Scripts/patch-azahar.py` and `Scripts/azahar-simulator-buffers.patch` make the local source changes reproducible:

- Submit GPU work before the frontend reads its output.
- Join the fence worker before destroying its resources.
- Return control after a fatal emulation error.
- On iOS Simulator, use private texel buffers with explicit uploads, and rebase indices so indexed draws use a zero base vertex. These two restrictions do not change the physical-device draw path.
- Share decoded interpreter blocks consistently with the existing shared buffer, preserve them within the same address space, separate ARM/Thumb keys and recycle the cache before it fills.
- Filter debug logging before formatting. The frontend buffers routine logs, retains the previous session, uses interactive scheduling and consumes the GPU's native pixel layout without channel-swizzling or an intermediate frame copy.

`Scripts/prepare-mii-fallback.py` replaces only the built-in archive's error-glyph textures with an original guest face. Its structure/metadata preservation and repeatability checks pass. Imported console resources retain precedence. This is a fallback appearance change, not original Mii model support.

The frontend renders through Vulkan/MoltenVK and synchronously reads output into the native image views. CPU JIT is disabled. [Duo design and benchmark procedure](DUO.md).

## Remaining limits

The owner confirmed physical Mario Golf startup with lag and an X-shaped fallback head; Ocarina felt smoother. A brief physical Mario Golf baseline is recorded in [the performance notes](PERFORMANCE.md). Build-2 physical speed gains, long sessions, live hinge transitions, inner/outer display migration and physical-controller hardware remain unverified. UI fold/controller fixtures are explicitly diagnostic fixtures.

Original Mii face rendering and Mario Golf Castle Club remain unverified. Replacement archive use and archive-header detection alone do not establish compatibility. No normal-speed or finished-release claim is made. Additional console cores and network play are not implemented. Build 5 adds save states; see the current build-5 notes below.

The iOS 27.1 simulator intermittently failed before test-runner launch with SpringBoard/Mach errors. Later Duo runs passed; no OS security settings or runtime files were modified.

## First phone test

Build 2 is installed on B Duo. Compare Mario Golf in the same scene/save as build 1, including steady speed, sound and FPS. Check the guest-face fallback, Castle Club and saved-session reopening, then repeat Ocarina. Check partially folded tabletop mode and lower-screen expansion after connecting a controller. The current and previous session logs are under Files → Emulator → Saves. Installation is verified; a physical build-2 performance result is still required.

## Build 4 distribution symbols

The Release archive and internal-only signed IPA passed `validate-testflight.py`, including real DWARF and matching UUIDs for EmuDen, Azahar and MoltenVK. Missing and wrong-UUID symbols were rejected by negative checks; all 515 prior Vulkan/MoltenVK exports remain. This does not verify Apple processing or phone performance. No build 4 upload was performed.

## Build 5 validation

Sixteen domain checks and the C++ input-latch check passed. The four Release Duo simulator tests in `build/EmuDen-Build5-Validation2.xcresult` passed: controller skin/full-panel preferences, actionable Mii setup, 600-frame Mario Golf startup, and Quick Save/Load followed by close/relaunch/resume. The latter failed on the old core with a null shader-cache dereference, then passed after the renderer-cache restoration fix.

`build/TestFlight/EmuDen-0.1.0-5.xcarchive` passed strict signing, identity, privacy, user-data exclusion and all three real matching dSYM checks. No build 5 upload or phone installation was performed. The extra automated runner aborted while preparing tests. Direct in-app simulator regression runs then passed at 1,321 frames with quick capture/restore and continued rendering. Captures show Forest Course loading and a touch-selected Mii with the new generic 3D head. The software-shader stack matched 400,000 reference operations and passed address/undefined-behavior sanitizers; optimized binaries confirm three allocator sites removed. See TestFlight/STATUS.md for artifacts. Physical FPS gains, haptics/controller hardware and original Mii resources remain unverified. Detective Pikachu has no complete local test file.

## Build 6 validation

Twenty-one domain tests passed. Library/Mii setup and Quick Save/Load/relaunch/resume passed in `build/EmuDen-Build6-Validation.xcresult`; the shader preference/persistence test passed in `build/EmuDen-Build6-Shader-Preference.xcresult` after correcting the test's switch tap target. Real Mario Golf and Ocarina Rev 1 covers downloaded and displayed. A downloaded Mii package, then its extracted archive alone, rendered a normal selected Mii before/after state restoration; the standalone test ran 1,261 frames with asynchronous shaders enabled. There was no restored shader-profile mismatch.

The final build-6 archive passed signing, packaging, privacy and all three matching real dSYMs. Nintendo resources used in local testing are excluded from the app/source. Dark Moon's file has an iCloud upload error, so its exact scene and phone FPS remain unverified. The current app's physical performance, haptics and controller hardware need device checks; simulator timing is not an A20 benchmark. See `Docs/BUILD-6.md` and `TestFlight/STATUS.md`.

## Build 7 console UI

All four Release Duo UI checks passed in `build/EmuDen-Build7-Console4.xcresult`: new shelf/collection/search with a real Mario Golf launch/return; usable controls and separated content in tabletop/book fixtures; library/Mii setup; and Quick Save/Load/relaunch/resume. Narrow-panel layout was corrected after the first checks. The tests compare interactive content rather than accessibility container unions containing offscreen scroll items, handle existing resume prompts and wait for colored game frames past startup fades. The Release archive and its three real matching dSYMs passed validation. Live phone fold transitions, haptics and controller feel remain unverified; the emulator core is unchanged.
