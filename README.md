# EmuDen for iPhone and iPad

Native SwiftUI emulator app on the Samsung T7 SSD. Open `EmulatorApp.xcodeproj`, choose the **Emulator** scheme and **Emulator - iPhone Duo (iOS 27.1)**, then Run. A separate simulator core is bundled for Apple Silicon Macs; the physical-device core is also included. The simulator is independent of your physical **B Duo** and of the original Duo simulator used by GameProject. The existing Xcode team is configured; change the bundle ID/team if needed.

**Build 17:** Per-game graphics profiles, live resolution/texture changes, optional automatic quality, known-shader preparation, a frame-time graph, screen balance and per-game shader-cache management. Native Continue Playing/Recent Games widgets use cached artwork and save before switching sessions. Settings also offers a local profile-picture chooser; Mii resource archives contain shared models rather than a personal avatar. See [build 17 notes](Docs/BUILD-17.md) and [actual previews](Docs/Preview/Build17-README.md). Phone performance gains remain unmeasured.

**Build 16:** Player Settings → Duo layout → **Fill display** now uses the full outer display instead of the old insets. Async-eligible Apple graphics pipelines go directly to the background compiler, with slow construction diagnostics retained. This targets shader stalls; Dark Moon's exact phone improvement remains unverified. See [build 16 notes](Docs/BUILD-16.md).

**Build 15:** Known custom artwork loads against dark ambience and fades in without flashing the console illustration. Existing artwork stays visible during refresh, and unknown games retain their console fallback. See [build 15 notes](Docs/BUILD-15.md).

**Build 14:** Asynchronous frame transfers, native 1×/2×/3× resolution choices, a fading player header and an optional FPS counter. The final matched Mario Golf Simulator comparison reduced median emulation-thread frame cost from 15.07 to 12.01 ms; this is not a phone FPS result. Higher resolutions improve clarity, while 1× remains the fastest default. Tap the top screen to restore controls after they fade. The core and save formats remain unchanged. A new glass app icon and growing artwork catalog match the theme. See [build notes](Docs/BUILD-14.md) and [artifact status](TestFlight/STATUS.md).

The live [artwork collection](https://emuden-artwork-catalog.headyopossum2.chatgpt.site) provides 40 original scene backgrounds and 24 new covers, keyed by retail ID and exact title aliases. Images download on demand, remain cached offline, and stop downloading during emulation. User-selected images keep priority. The approved Option A layout and search dock fix remain.

The owner's previous phone testing reached Mario Golf's Castle Club with the generic fallback, with severe gameplay frame drops; Animal Crossing was smoother. The build-6 Mario Golf character-selector check verifies the downloaded Mii resources in that scene. Sustained phone performance and other Mii-dependent modes remain unverified. [Performance notes](Docs/PERFORMANCE.md) · [Player previews](Docs/Preview/Build14-README.md).

iPhone Duo is the primary design and hardware target. See [Duo layout and benchmark notes](Docs/DUO.md).

## What runs

- A dark, controller-oriented game library with file import, search and recent play history.
- Azahar **2127.0-rc1** iOS arm64 core with FastInterp, bundled and signed as a framework, with reproducible local rendering and shutdown fixes.
- Actual 3DS execution with Vulkan-to-Metal GPU rendering through MoltenVK, CPU interpretation, stereo audio, Circle Pad, D-pad, buttons, lower-screen touch, and Game Controller input.
- iPhone Duo is the primary layout target. Public iOS 27.1 fold-region APIs keep screens on opposite sides of the hinge in book and tabletop orientations. A connected extended gamepad hides touch buttons. Duo layout settings choose the console shell with original screen proportions or screens filling each Duo panel; lower-screen touch remains available.
- **Launch 3DS test** boots the bundled open-source Homebrew Menu 2.4.4; **Test controls** opens a separate native input diagnostic. The latter is not emulation.
- Files → On My iPhone → EmuDen exposes imported games and `Saves/Azahar` for data/log inspection.

## Test the app

1. Run the app on the **Emulator - iPhone Duo** simulator, or an iPhone/iPad when hardware testing is desired.
2. Open **Settings → Help, tests & open-source notices → Launch 3DS test**. Verify both screens render; try A/B, D-pad, touch and a connected controller.
3. Import an extracted, decrypted `.3ds`, `.cci`, `.cxi`, `.app`, `.3dsx`, `.elf` or `.axf` file using **Add games**. CIA installation is not implemented.
4. Open **Settings → Import Mii file**. Select your decrypted Mii `.app` or `errfix.3dsx` directly. **Mii setup details** includes compatibility guidance and the advanced NAND-folder option, which accepts `nand` and/or `sysdata`. Face models and a personal Mii database are separate. After import, new snapshot slots apply the new faces; native saves remain.
5. Test Mario Golf through its title/menu and Castle Club, including player/Mii selection, gameplay, and save/relaunch. An archive-presence check alone does not verify game compatibility.

## Mii support and limits

The purpose of Mii system-data support is game compatibility: some games request it during startup or gameplay. A Mii creation feature is not required for this work. Mario Golf is the target regression case. Native Duo simulator startup now passes; a Mac core run also reached a golf scene. The owner reached Castle Club with the generic guest; the downloaded Mii resources now render normally in the build-6 character-selector check; complete mode compatibility remains unverified. Put its local test file in [TestGames](TestGames) without uploading it to chat; the [validation plan](Docs/MARIO-GOLF-VALIDATION.md) records how it will be checked.

The system importer places files at the core's actual user directory, `Documents/Saves/Azahar`. It stages and merges NAND/sysdata, rejects symbolic links, preserves SD-card game saves, and rolls back failed installs. Mii archive detection validates a decrypted NCCH container, title identity and RomFS bounds under NAND title `0004009b/00010202/content/*.app`. Personal database detection separately looks for `CFL_DB.dat`.

**Detected does not mean verified**: validated archive structure does not establish compatibility with every Mii-dependent game mode. There are no Nintendo system resources bundled. Mii rendering requires testing with your own system dump and game. A raw encrypted hardware NAND image is not an importable folder.

## Current limitations

This is an early test build. GPU rendering is integrated; CPU JIT remains disabled. No full-speed claim is made. Real Duo CPU/GPU performance, continuous physical hinge transitions, and controller hardware remain unverified. Simulator timings use the Mac hardware. The Apple Silicon iOS simulator uses a separate core built from Azahar’s verified source, so it can execute the included 3DS test as well as the UI. Physical-device performance remains unverified. Quick Save, Quick Load and separate resume states are available from the player menu. In-game saving is still recommended because states depend on the core version. Cheats, network play and additional console cores are not implemented. In-game saves use Azahar's normal persistent data directories.

## Checks

```sh
swift test --jobs 2 --scratch-path build/DomainTests
xcodebuild -project EmulatorApp.xcodeproj -scheme Emulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData build CODE_SIGNING_ALLOWED=NO
xcodebuild -project EmulatorApp.xcodeproj -scheme Emulator -destination 'platform=iOS Simulator,id=6F71722D-816E-4CFE-B1F3-4A507095CBEB' -derivedDataPath build/DerivedData test CODE_SIGNING_ALLOWED=NO
```

All local Xcode/Swift build products use `build/` on the SSD. Xcode still manages signing caches and device services in its normal locations.

## Rebuild the simulator core

The bundled simulator binary targets arm64/iOS Simulator with minimum iOS 18.0. Its source archive is pinned to SHA-256 `4c966d8344da9a95c2c9ccfc6671991ba3bf36d82157c7d0a64ca25f1d30ed24`. The build enables Vulkan and software rendering, disables OpenGL, and applies the small version-checked fixes in `Scripts/patch-azahar.py`. They order GPU submission before frontend readback, join the fence worker before freeing resources, return control after fatal emulation errors, and adapt texel-buffer storage and indexed draws to Metal on the simulator. Xcode selects the matching simulator or device binary during embedding.

```sh
python3 Scripts/prepare-simulator-core.py
python3 Scripts/prepare-moltenvk.py
Scripts/build-simulator-core.sh
Scripts/build-simulator-core.sh device
```

The dedicated simulator is **Emulator - iPhone Duo**, iOS 27.1, UDID `6F71722D-816E-4CFE-B1F3-4A507095CBEB`. Tests explicitly select this simulator to avoid interfering with the game project.

## Upstream source and licenses

- [Azahar 2127.0-rc1 source](https://github.com/azahar-emu/azahar/releases/tag/2127.0-rc1), GPL-3.0-or-later; exact release URL and archive SHA-256 in `Vendor/Azahar/PROVENANCE.md`.
- [3DS Homebrew Menu 2.4.4 source](https://github.com/devkitPro/3ds-hbmenu/tree/v2.4.4); original reuse/credit notice bundled in `Resources/Homebrew-NOTICE.txt`; release checksum in `Docs/HOMEBREW.md`.
- [MoltenVK 1.4.2](https://github.com/KhronosGroup/MoltenVK/releases/tag/v1.4.2), Apache-2.0; checksum and origin in `Vendor/MoltenVK/PROVENANCE.md`.
- libretro ABI headers from [libretro-common](https://github.com/libretro/libretro-common).

Preserve upstream notices and satisfy the core's GPL source/license obligations before distributing the app. This starter is not an App Store release.

## Latest validation

See [validation details](Docs/VALIDATION.md) for passed checks and remaining limits. Previews are in [Docs/Preview](Docs/Preview). This is an early prototype, not a normal-speed 3DS release.
