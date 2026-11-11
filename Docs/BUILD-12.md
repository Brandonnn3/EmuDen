# EmuDen 0.1.0 (12) — automatic artwork and console backgrounds

This is the first working artwork rollout. Games without a suitable scene now use a bundled, original background for their console. 3DS, PSP, PlayStation and GameCube each have an illustration; only 3DS remains playable. Existing Mario Golf and Zelda hero art remains available. Animal Crossing and Dark Moon retain their illustrated covers and use the 3DS scene until a separate hero image is chosen.

The Liquid Glass dock hides for the entire library search session in both ordinary and fold-aware layouts. Dismissing the keyboard keeps it hidden; closing search restores it. This keeps navigation from lifting over the game results with the keyboard.

Long-press a game → Change artwork opens a native editor. Choose a cover or background from Files, match another game from the existing cover catalog, force the console background, or restore automatic artwork. Matching affects artwork only; the game title, ROM path, library UUID and save identity remain unchanged. Explicitly imported images take priority over automatic artwork. Resetting keeps user image copies and never touches ROMs or saves.

Automatic 3DS covers fill the cards. Standard retail scans have their right-hand case strip removed before framing; wide cards align at the top to retain their title area. User-imported images bypass the retail-scan trim. Tight portrait crops can still crop part of a wide logo; a purpose-made portrait cover can be chosen in the editor.

## Identification and offline behavior

NCCH and NCSD headers provide the program ID without reading the complete game. The app uses a pinned lookup of 1,289 release IDs, then falls back to the existing filename matcher. An explicit artwork match takes priority. Existing libraries remain readable; missing IDs are discovered from their local headers without moving game files. Bounds checks and symbolic-link rejection apply to metadata reads.

The 2,148-entry cover catalog is indexed once. Matching avoids scanning and normalizing the full list on each view update. Artwork downloads remain bounded, cached locally and paused while emulation runs. Cached files, user-selected images and bundled console scenes remain usable offline.

Automatic gameplay images need a short side of at least 720 pixels and a long side of at least 1,280. The native-resolution Libretro snapshots and low-resolution captured frames are no longer enlarged into hero backgrounds. Explicitly chosen images remain available at the user's chosen quality.

## Artwork assets

Four console illustrations were generated with the built-in image_gen tool and saved in `Resources/CinematicArt/Console-{3ds,psp,ps1,gamecube}.png`. They are static illustrations, not gameplay or additional emulator cores. The saved masters are 1,254 × 1,254 pixels. The native layout fits them on portrait screens and crops them for wide displays.

[Exact generation prompts](Design/Build12-Console-Art/prompts.json) · [Metadata and artwork provenance](Design/Build12-Console-Art/PROVENANCE.md).

The title-ID lookup contains names and identifiers only, derived from the pinned Azahar compatibility data already included in the corresponding upstream source. It contains no keys, ROMs or system data. Downloaded retail covers stay in device caches and are excluded from the release/source package.

## Verification and limits

Domain checks cover direct/cartridge ID extraction, invalid/truncated headers, renamed ROM matching, manual overrides, old-library decoding, search, scene quality and retail-cover framing. Isolated simulators named EmuDen Artwork QA and EmuDen Artwork Files QA contain metadata-only fixtures for UI artwork tests. Their tiny NCCH/3DSX files are not executable games and never establish gameplay compatibility. `Scripts/stage-artwork-qa.py` refuses to replace a non-fixture library or target a differently named simulator.

See [current preparation status](../TestFlight/STATUS.md) for completed tests and artifacts. Real-game launch/save regression checks use the existing simulator and user-provided games separately. The core, shaders and save-state format are unchanged from build 11.

A hosted HD artwork catalog and server credentials are not configured in this build. Automatic standard-cover lookup works now; custom HD packs still ship with the app or can be imported locally. A shared, independently updated HD feed is the next rollout stage. Full-catalog image generation remains deferred.

The owner is away from the locked Mac, so the final live inner-display comparison, continuous physical folding review, phone haptics and sustained phone performance remain pending.
