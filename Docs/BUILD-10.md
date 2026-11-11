# Build 10 — Cinematic Glass

EmuDen 0.1.0 (10) implements the owner's selected **Option A**, with a single consistent dark cinematic appearance throughout the app.

## Library and scenes

The selected game has a large scene backdrop, a fine pearl cover-focus border and an explicit Play action. Touch selects a cover; pointer hover selects after a short dwell; controller and keyboard navigation retain their launch action. Scrolling the shelf does not launch a game or force selection back to the first visible cover.

Available scene screenshots download from Libretro's `Named_Snaps` collection and cache locally. The bundled 2,009-name index comes from [the official thumbnail repository](https://github.com/libretro-thumbnails/Nintendo_-_Nintendo_3DS), tree `a1e242aca9d194ba7c168e38e14c637ff206189f`. Box art matching stays separate from scene matching. Unknown scenes fall back to cover artwork. The most recent gameplay frame can replace the preview after closing/backgrounding a game; a cover's context menu also accepts a user-selected scene image. Imports validate regular files, byte/pixel limits and decodability, then atomically write a thumbnail. No game data is uploaded.

Browsing never starts an emulator session. Previews are cached still images rather than background emulation or continuously playing video. The old repeating wave canvas is replaced by static ambience, leaving rendering time for native transitions and games.

## Glass and motion

The floating dock contains Home, Library, Add and Settings. The active selection travels within the dock; press and focus states use restrained springs. Search expands from its circular control into a glass text field. Scene/title changes crossfade, cards enter in short stages, and launch has a brief coordinated fade.

[Apple's native Liquid Glass APIs](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views) are used on iOS 26 and later, including a glass effect container/identity for search. Earlier supported systems use material chrome. Reduce Transparency uses an opaque high-contrast surface. Reduce Motion removes decorative movement and shows the console preview already open. System keyboard, document picker, sharing and sheet interactions retain native behavior.

Settings, Mii import, performance controls and the paused-game menu share the cinematic palette, translucent cards, readable labels and tactile button treatment. Existing Mii validation, native saves, quick/resume states, privacy disclosures and future-console gating remain in place.

## Opening console and controller layouts

Settings → Duo layout and Game menu → Screen layout open a graphite clamshell preview. Its lid rotates around the hinge from closed to open, with back/front faces, screen, speaker details, a metallic hinge and a soft shadow. It is composited from native views and animates only on entry; no continuously running 3D engine is introduced.

Console skin preserves 3DS display proportions; Fill Duo panels fills the available regions and changes the picture's proportions. A connected controller hides touch buttons and expands the lower screen, whose touch interaction remains available. The preview uses a stored/paused top frame when possible; its library-only bottom map is a decorative layout illustration, not a fabricated saved game. Actual in-game previews use the current lower-screen frame.

An unfolded library uses the full cinematic home. Active folds retain dedicated safe regions in book/tabletop orientations. The physical game's two-screen layout keeps the established fold handling.

## Original sound and haptics

Nine original synthesized stereo PCM cues cover focus, confirmation, back, launch, planned systems, search, sheet opening, console unfolding and successful save/load. Four new cues extend the five existing instruments; no commercial soundtrack or game sample is used. `Scripts/generate-menu-audio.py --check` verifies the bundled files against the deterministic source score.

Sound, volume and haptic preferences are retained. Haptics still work when sounds are muted. Focus sounds are debounced and new actions stop competing cues. On iOS 27, menu audio activation uses the asynchronous API. The menu's previous audio-session category/mode/options are restored before gameplay resumes; pending activation/cues are invalidated when the menu closes or the app becomes inactive. Paused-game menus may play cues, while active gameplay has no menu sounds.

## Core and saves

The optimized Azahar 2127.0-rc1/FastInterp and MoltenVK binaries are unchanged from build 9. The native save paths and quick/resume format are unchanged. Build 9 snapshots remain compatible; the build-9 migration rules for older cores and newly imported Mii resources still apply. No emulator FPS improvement is claimed for this design change.

## Validation

26/26 domain checks passed. The Release suite in `build/EmuDen-Build10-Final.xcresult` passed 10 UI scenarios, with one conditional accessibility scenario skipped because Reduce Motion and Reduce Transparency were not both enabled. The added paused-menu/direct-return check passed in `build/EmuDen-Build10-Pause.xcresult`, for 11 distinct passing UI scenarios. Final narrow-header/cover polish passed both focused checks in `build/EmuDen-Build10-Duo-Polish.xcresult`. Both real-game launch/return and save/load/relaunch/resume passed again after alert-presentation cleanup in `build/EmuDen-Build10-Resume-Final.xcresult`; that run reports no publishing-during-view-update warnings.

The final device archive passed identity, embedded framework slices, privacy manifests, private-data exclusion, deep signatures and all three matching real dSYMs. Archive: `build/TestFlight/EmuDen-0.1.0-10.xcarchive`. Matching source: `build/TestFlight/EmuDen-0.1.0-10-source.tar.gz`. No upload, IPA export or physical phone install was performed.

[Home](Preview/Build10-Console-Home.png) · [Search](Preview/Build10-Search.png) · [Settings](Preview/Build10-Settings.png) · [Mii setup](Preview/Build10-Mii-Setup.png) · [Duo console preview](Preview/Build10-Opening-Console.png) · [Game menu](Preview/Build10-Game-Menu.png) · [Duo book](Preview/Build10-Duo-Book.png) · [Original sound audition](Preview/Build10-Original-Sounds.wav).

Physical phone audio/haptics, continuous physical fold transitions and the exact Donkey Kong crash still require owner testing. The Mac remained locked, preventing a manual inner-display pose review. CLI app screenshots and automated layout/entry checks succeeded. The attempted `simctl` video captured the simulator Home Screen rather than the tested app window; it is retained only as a build diagnostic and is not an animation preview. The accessibility visual check remains conditional until the simulator settings are enabled. No emulator FPS improvement is claimed for this UI release.
