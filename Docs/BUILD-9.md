# Build 9: faster 3DS CPU, clearer setup and modern library

The Release device archive is validated and the simulator checks passed. Exact distributable paths are recorded in `TestFlight/STATUS.md`. No build-9 upload, IPA export or phone install was performed.

## 3DS engine

The core moves from Azahar 2126.2 to the pinned **2127.0-rc1** unified source, published November 6, 2026. Its FastInterp CPU interpreter runs without JIT; GPU rendering continues through Vulkan/MoltenVK to Metal. CPU clock stays at 100%, rendering stays at native 1×, and multiplication accuracy remains controlled by the game's normal profile. The old local DynCom cache modifications are retired in favor of upstream FastInterp. Existing queue-lifetime, simulator-buffer, shader-stack and state-cache fixes are retained and ported. Supported null-descriptor features are queried/enabled consistently with the new renderer; unsupported features remain off.

This is an upstream release candidate, not a claim of universal game compatibility. The source archive is verified against GitHub's immutable release asset SHA-256 `4c966d8344da9a95c2c9ccfc6671991ba3bf36d82157c7d0a64ca25f1d30ed24`. Both simulator/device binaries are optimized Release builds with real matching debug symbols. Upstream's license is now GPL-3.0-or-later; the exact license and complete matching source are included in preparation artifacts.

### Measured result

The same 1,560 delivered-frame Mario Golf menu/character/course sequence, with asynchronous shaders **off** in both runs, went from **21.78 to 59.98 FPS** in the dedicated iOS Simulator. Median core-and-display time across 13 blocks decreased from **45.61 to 12.23 ms/frame** (73.2% less time). Median GPU readback changed from 1.80 to 1.39 ms. These measurements use the Mac's CPU/GPU and do not establish a physical iPhone frame rate or a result for every course/effect.

Evidence: `build/build9-performance-comparison.json`, `build/Build9-Performance-Before`, and `build/Build9-Performance-After`. The new session log confirms FastInterp creation on all four emulated cores. The new core invalidates the old generated shader cache; first visits may still compile effects.

## Donkey Kong crash

The owner reported a full-power swing crash with Reduce shader pauses off, and a successful repeat with it on. The paired phone's existing build-8 report was copied read-only: `build/build9-phone-donkey-kong-crash.ips`, dated November 8 at 22:51:56. It is `EXC_BAD_ACCESS`/`SIGSEGV`, reading address `0x58` in `MVKImage::applyImageMemoryBarrier` during the Azahar scheduler's queue submission. Register x0 is zero; matching real MoltenVK symbols resolve the fault to `MVKImage.mm:932`. This identifies an invalid null image reaching a driver barrier; it is not evidence of an out-of-memory or simple slow-frame termination.

The previous phone log confirms asynchronous shaders off; the subsequent log confirms on. Their timings cover different user sessions and are not a controlled performance comparison. No phone install or new on-device benchmark was performed. A simulator-only opt-in (`EMUDEN_VALIDATE_GPU=1`) captures the recording stack if a null image barrier appears, before calling Metal. It is absent from physical-device builds.

Reduce shader pauses defaults on for fresh preferences; existing explicit preferences are retained. The setting explains that newly encountered objects can briefly appear late and that changing it requires restarting the game. The simulator completed normal and Power Shot drives with shaders off, and a Power Shot with shaders on. No null-image barrier was detected in any run. Observed distances were 200.63, 226.88 and 224.92 yards. These runs do not establish exact perfect-impact timing or a phone fix: the physical phone enables fragment shader interlock, while the simulator does not. Keep Reduce shader pauses on for the next phone check. Evidence: `build/Build9-DK` and `build/build9-dk-regression-report.json`.

## Saved progress and Mii setup

Before first use, existing `Saves/Azahar` is copied to `Saves/Backups/Before-FastInterp`. The backup is staged and marked complete before the new core is allowed to start. Failure leaves active data in place and blocks the upgrade until retry succeeds. Native in-game saves remain at their existing paths. Old quick/resume files remain on disk; new snapshots use a separate core generation. A contextual game-menu note explains why old snapshots are not offered.

Mii setup accepts a decrypted `.app` archive or a user-selected resource installer such as `errfix.3dsx`. It validates title, encryption flag and declared NCCH/RomFS bounds, extracts only the unique matching Mii resource container, and installs it atomically. It does not run the installer. Wrong, truncated, oversized or ambiguous files do not replace existing resources. The local real-file test extracts bytes identical to the previously verified 1,106,432-byte archive. Downloaded Nintendo data remains test-only and is not bundled or included in source packages.

Successful system import changes the snapshot compatibility revision. Games therefore start normally after a new Mii import, instead of silently restoring the previous face from RAM; older snapshots and native game saves are preserved. Face models and the user's personal Mii database are explained separately.

## Interface

Calmer focus styling, readable labels, a frosted action dock, explicit Library entry and Play game action replace ambiguous icon-only navigation and a misleading Continue label. Library shows its game count and sorting. Mii setup is available directly from game details and from Settings; it has a dedicated file picker and an optional advanced NAND-folder section. Settings groups menu sound, 3DS performance/controls and troubleshooting. A Share emulator log action lets the owner export diagnostics through the system share sheet. The original menu chimes and fold-aware player layouts are retained.

Required-reason manifests declare elapsed-time/timer use (`SystemBootTime`, `35F9.1`) alongside existing file/defaults uses. No tracking or analytics collection is added.


## Final validation

25/25 domain tests passed, including extraction from the actual local installer, rejection of malformed/ambiguous files, native-save backup and snapshot isolation. 7/7 Release UI tests passed in `build/EmuDen-Build9-Final.xcresult`, covering real-game browse/search/launch/return, both Duo fixtures, Mii setup, sound/shader preferences, future-system gating and Quick Save/Load/relaunch/resume. The initial Mii-screen test had an ambiguous Done selector; distinct accessibility identifiers corrected it. The compact dock follow-up passed in `build/EmuDen-Build9-Duo-Final.xcresult`.

Narrow Duo book panels stack the dock actions as readable rows with 44-point targets; wide panels retain the horizontal dock. The final archive passed identity, manifests, signatures, private-data exclusion and all three matching real dSYMs. The complete matching source package includes the pinned GPL-3.0-or-later release and every local change.

[Home](Preview/Build9-Console-Home.png) · [Settings](Preview/Build9-Settings.png) · [Mii setup](Preview/Build9-Mii-Setup.png) · [Duo book](Preview/Build9-Duo-Book.png).
