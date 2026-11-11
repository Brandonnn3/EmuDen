# Build 6: Mii resources, shader pauses and game covers

## Mii download and test

At the owner's request, `errfix.3dsx` was downloaded from https://archive.org/download/errfix.3dsx_202405/errfix.3dsx into `build/Downloads/MiiTest`. It is 7,243,584 bytes, SHA-256 `8e4a462d48c74ea4a0b4059b16aa2ea4481072b5f42f8a2b6101b4dde107c745`.

It ran through the app's normal bridge/core in a separate simulator app (`com.brandonaleman.Emulator.MiiTest`). It installed seven system titles, including Mii resource title `0004009B00010202`. That installed archive exactly matches the 1,106,432-byte decrypted archive extracted from the download at `build/MiiTest/downloaded-mii.app`. Its RomFS contains a 1,083,400-byte `CFL_Res.dat` with the expected twenty component sections.

Mario Golf's character selector then displayed the selected Mii with a normal three-dimensional head, face and hair. Quick Save/Load completed and rendered another 120 frames with the head intact. Evidence: `build/MiiTest/SelectedMii`, `build/MiiTest/selected-mii.log`, `build/MiiTest/result.json` and `Docs/Preview/Build6-Imported-Mii.png`. This establishes that scene in Mario Golf, not every Mii game or mode. The extracted archive alone also passed the app's direct importer in the canonical simulator container, with no other Nintendo system archives installed. Its Mii rendered normally with asynchronous shaders enabled and survived another state restore plus 120 frames (`build/MiiTest/Standalone`, 1,261 frames total). After importing new system resources, choose Start normally; old resume/quick states may retain the previous resources in memory.

These downloaded system resources are local test data, excluded from the app and source packages. The app retains its original generic guest fallback when nothing is imported. To use the extracted file, transfer it to the phone and choose System → Mii resource archive; a personal Mii database is separate.

## Performance changes

`azahar-shader-stutter.patch` exposes the existing asynchronous Vulkan shader option in the libretro parser. Player settings → Reduce shader pauses enables it for the next game launch. It defaults off to preserve the existing rendering behavior: when on, new objects can briefly appear late while compiling. Shader disk caching stays enabled in either mode.

The state-cache patch now restores per-game shader settings before loading the recreated renderer's caches. Previously, the restored accurate-multiplication profile differed from the saved cache, causing unnecessary regeneration. The real Mario Golf round trip no longer logs that mismatch. Pipeline waits of at least 20 ms are logged separately; the simulator recorded a 1,903 ms wait in the earlier scene check.

CPU/shader JIT remain disabled, native resolution remains 1x, and no emulated clock or accuracy reduction is introduced. Neither simulator FPS nor compilation-wait duration predicts phone FPS. The owner reports Mario Golf feels substantially better; no measured physical comparison is available for these new changes.

Luigi's Mansion: Dark Moon is unavailable on the Mac because its iCloud upload failed, as confirmed by the owner. Its exact freezing scene and sustained FPS remain unverified. A complete local copy is needed to distinguish shader stalls from sustained CPU/rendering load in that game.

## Game artwork

The app automatically matches full game names against a bundled index of 2,148 Libretro 3DS cover names (Git tree `a1e242aca9d194ba7c168e38e14c637ff206189f`). Actual covers download from https://thumbnails.libretro.com/ and are cached under Documents/Artwork. That server resolves the shared-cover links used by revisions; raw GitHub URLs returned link text for Ocarina Rev 1 during testing.

Matching stays on the device and keeps sequels distinct, prefers the requested region/revision, and tolerates punctuation, accents, DAT articles and the standard filename substitutions. Unknown games keep the original illustration. Long-press a game → Find game artwork retries lookup. The source receives cover requests, not ROM contents, saves or personal Mii data; privacy notes are updated.

Downloads are capped at 4 MiB, decoded dimensions at 2,048, thumbnails at 512 pixels, and the shared in-memory cache at 24 MiB/48 images. Failed requests preserve existing covers. No artwork account or API key is required.

## Validation status

Twenty-one domain tests passed, including exact artwork matching, revisions, sequels, accents, unsafe/unknown paths, original import checks, save integrity and Duo layout. Simulator/device cores and the Release simulator app rebuilt with matching core dSYMs. The standalone-Mii check, both real-cover downloads/displays, the shader switch/persistence UI test and library/state/resume UI tests passed. The final Release device archive and all three matching real dSYMs passed local validation. See TestFlight/STATUS.md for exact artifacts and the corrected Form-switch test target. No phone install, IPA export or upload was performed.
