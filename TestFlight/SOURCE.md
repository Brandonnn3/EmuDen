# Corresponding source — EmuDen 0.1.0 build 17

`build/TestFlight/EmuDen-0.1.0-17-source.tar.gz` contains the app/frontend and WidgetKit extension sources, project, tests, resources, build scripts, component notices and the complete pinned Azahar 2127.0-rc1 unified source release. The deterministic local patches, guest-face generator, MoltenVK source-build recipe and symbol checks are included. Private contact details, signing credentials, provisioning profiles, user ROMs, saves and simulator data are excluded.

The source package is local for the internal team. It has not been published to a public repository or website. Provide the matching source package to any internal recipient who receives a binary incorporating the GPL-based core. Before wider distribution, arrange appropriate ongoing source access rather than linking only to an unmodified upstream tree.

## Rebuild from the package

1. Install Xcode and its iOS SDK on an Apple Silicon Mac. This build used Xcode 27.2 (27B52). System SDKs/toolchains are not redistributed.
2. Extract `Upstream/azahar-unified-source-2127.0-rc1.tar.xz` into `Vendor/Azahar/Source`, removing its single top-level source-directory prefix. Verify SHA-256 `4c966d8344da9a95c2c9ccfc6671991ba3bf36d82157c7d0a64ca25f1d30ed24` before extracting. Keep its bundled dependencies. `prepare-simulator-core.py` downloads and verifies this exact source if needed.
3. Create a local Python virtual environment: `python3 -m venv .tools`. Install build tools using `.tools/bin/python -m pip install cmake==3.31.6 ninja==1.11.1.4`.
4. Run `python3 Scripts/prepare-moltenvk.py` to fetch/checksum the unmodified MoltenVK 1.4.2 SDK for headers and simulator use. Run `Scripts/build-moltenvk-device.sh` to build the same pinned release and dependencies with real dSYMs for iOS. Its version, commit and license are recorded in `Vendor/MoltenVK/PROVENANCE.md`.
5. Run `CORE_PCH=ON Scripts/build-simulator-core.sh device`. This applies all pinned Azahar changes and generates the original guest-face fallback before building the arm64 device core and matching dSYM, retaining Release optimization. For the simulator, run `Scripts/build-simulator-core.sh`.
6. Select your own signing team if rebuilding independently. Configure your own app/extension identifiers and the same registered App Group for both targets, updating `WidgetLibrary.groupID` and the shared entitlements consistently. Archive using the Emulator scheme in Release configuration. Product and visible name: EmuDen. No signing key, developer login or App Store credential is included.

The owner-specific `TestFlight/Private/Contact.json` is intentionally omitted. The metadata validator and convenience TestFlight archive script require your own contact configuration. Building/archiving directly through the Xcode project does not depend on that private file.

The current Azahar core is GPL-3.0-or-later; its exact license and complete upstream release are included. MoltenVK is Apache-2.0. Homebrew Menu provenance/credits are in `Resources/Homebrew-NOTICE.txt` and `Docs/HOMEBREW.md`. Source links and exact upstream versions remain available for components. The bundled demo is licensed homebrew, not a Nintendo game.

Build 5 includes the local MoltenVK feature-negotiation and save-state-cache patches, original 3D guest geometry generator, immediate UIKit touch surfaces, input latch, per-game quick/resume state store, controller presentation and haptic preferences. Rebuild scripts apply and check every core patch before compiling.

Build 6 also includes the artwork matcher/downloader and a 2,148-name index, shader-pause preference, profile-aware state-cache restoration and pipeline wait diagnostics. Downloaded Mii system archives, commercial covers, personal databases and game files used in testing are not bundled in the source or app. Artwork is fetched by the running app from Libretro’s public thumbnail server.

Build 7 adds the native console home, wave backdrop, fold-aware menu, focus shelf, controller menu input and matching launch color. Emulator core binaries/settings are unchanged from build 6. The UI and launch resource sources are included.

Build 8 adds system preview pages, console styling, persistent menu audio settings and five original procedurally synthesized cues. Their generator, PCM assets and provenance notice are included. Run `python3 Scripts/generate-menu-audio.py --check` to verify them. Only the 3DS core is playable.

Build 9 upgrades to FastInterp, ports the local renderer fixes, preserves native data before migration, separates incompatible snapshots and accepts embedded Mii resource archives from user-selected installers without executing them. The simpler library/settings/Mii screens, regression hooks and matching tests are included. Downloaded Nintendo archives, user crash reports and benchmark/gameplay images remain excluded.

Build 11 aligns the native interface with the approved Option A references. Curated menu illustrations and their provenance are included in Resources/CinematicArt. Complete mockups are sampled only for their artwork; the interface remains native. The emulator core and save formats are unchanged.

Build 12 adds the bounded artwork editor/cache workflow, metadata-only program-ID parsing and lookup, retail-cover framing, HD scene gate and original console scenes. The dock hides throughout search, including after keyboard dismissal, and returns when search closes. Sources, fixtures/tests, artwork prompts, metadata attribution and new PNG masters are included. A hosted HD catalog is not configured.

Build 13 adds the original artwork collection and static host source/delivery images, validated versioned HTTPS downloader, offline/update fallback cache, artwork lookup and QA. Exact generation prompts, selected asset hashes, archived ranking selection, and documented cover-generation failures are included. The seed contains public metadata, not games, system resources or user data. Native core/Bridge/save formats remain unchanged. The read-only art host is public by the owner’s explicit audience choice. Git source credentials and local PNG master variants are excluded from this package; accepted JPEG delivery files and their metadata are included.

Build 14 adds the shared-image completion guard and asynchronous transfer worker, state/teardown draining, session lifetime cleanup, internal-resolution settings, fading player controls and optional FPS display. App/frontend sources, UI tests and build-14 notes are included. Azahar and MoltenVK source versions and save-state formats remain unchanged; no game, personal save or Nintendo system archive is included.

Build 14 also includes the original glass icon master/exporter, active artwork selection/queue and public catalog-v3 delivery images. The active catalog can grow independently of this release snapshot. No game/system resources or signing data are in the public artwork host.

Build 15 adds lightweight known-artwork metadata checks and a dark-to-scene transition, preserving cached imagery during same-game refreshes and guarding cancelled selections. Availability and visual UI regressions are included. Core/Bridge/save formats, icon and catalog assets remain as build 14.

Build 16 expands the controller Fill display layout across the outer display and retains inner fold regions. It includes the Apple asynchronous pipeline-probe patch, slow driver-construction diagnostics, layout/touch regressions and catalog-v4 delivery assets/provenance. Core source versions and snapshot formats remain unchanged. Signed build-14 and build-15 archives and their source packages are preserved separately.

Build 17 adds per-game settings, live resolution/texture options, conservative adaptive quality, cached-shader preparation with progress, per-title shader-cache management, frame timing and screen balance. `azahar-player-settings.patch` reproduces the libretro live-setting/progress changes and the opt-in cached-pipeline completion wait. Both optimized cores and real dSYMs are rebuilt. The native WidgetKit extension, shared models/views, App Group entitlements, URL routes and avatar image chooser are included. Catalog-v6 metadata, delivery images and generation provenance are included; private PNG masters and user resources are excluded. Core source versions and native-save/snapshot formats remain unchanged. Signed builds 14–16 and their matching source packages remain preserved.
