# Growing 3DS backgrounds

**Paused for legal review, 11 November 2026.** The owner prioritized legal/App Store clearance. Do not resume generation or publication of game-character art without documented rights or a revised original-generic-art scope. Accepted/blocked below describe visual generation outcomes, not copyright permissions. Existing assets and signed releases remain preserved; the existing public site is still live. See `Docs/Legal/REVIEW-2026-11-11.md` and the paused automation's legal-review hold.

Collection 01's historical first 25 selections are preserved in the build-13 design folder. `selection.json` is now the active catalog selection and keeps that ranking unchanged. Later entries are unranked additions. `queue.json` tracks requested candidates, pinned release IDs and generation status; skip accepted or blocked entries. A missing ID must be resolved from the checked-in title-ID table or primary documentation before publishing. Do not guess it or include demos as a retail release.

For each pending title, use the imagegen skill and built-in image_gen tool to create one original 1536×1024 landscape scene. Use a cinematic environmental composition with the subject on the right and calm left/lower areas for white UI. No text, logos, borders, interface or fake screenshots. Inspect the actual generated image. Copy accepted unchanged PNGs to `ArtworkMasters/3ds/<key>/scene.png`, retain prompt/provenance here, and add that entry to selection with `rank: null` and `bonus: true`. Set queue status to accepted. If a generation is rejected, record blocked and retain the console fallback; do not automatically retry. Covers are optional for this background expansion.

Increment `ArtworkCatalog/catalog-config.json`'s version before changing published content. Run `python3 Scripts/build-artwork-catalog.py --allow-fallbacks --report build/artwork-pack-validation.json`. The strict decoder and tests verify names/IDs, paths, dimensions, digests and cache behavior. Run `swift test --filter RemoteArtworkTests` after an index change. The client downloads needed images only, verifies their digest, preserves cached imagery offline, and suspends fetching while playing.

Use the Sites skill to open/synchronize, package and publish the existing public ArtworkCatalog site. Publish only the gallery, generated delivery JPEGs and title/ID metadata. Never add app source, games, system/Mii files, saves, accounts, contacts, credentials or signing assets to this site. Preserve its audience and all previously published digest URLs. Do not upload app builds or alter the signed build-14 archive/source snapshot during background catalog work.

## 2026-11-11 accepted expansion

- Kirby Planet Robobot: built-in image_gen, original cinematic fan illustration of Kirby's pink-and-brass armor beside a mechanized green planet; master `ArtworkMasters/3ds/kirby-planet-robobot/scene.png`. 1536×1024. Visually checked for clean geometry, calm left region and no logos/text.
- Pilotwings Resort: built-in image_gen, original cinematic fan illustration of a sport plane above Wuhu Island at sunset; master `ArtworkMasters/3ds/pilotwings-resort/scene.png`. 1536×1024. Visually checked for recognizable flight setting, legible overlay areas and no logos/text.

Mario Kart 7, Detective Pikachu and Star Fox 64 3D generation returned image-tool output rejections. They remain explicit blocked queue items and retain their existing artwork/console fallback. The accepted illustrations are fan art, not official screenshots or box art; no compatibility or gameplay claim is implied.

## 2026-11-11 12:52 UTC expansion

Four additional scene masters were generated with built-in image_gen and visually accepted: Kirby: Triple Deluxe, Ever Oasis, Pokémon X / Pokémon Y and Pokémon Ultra Sun / Pokémon Ultra Moon. Exact prompts, unchanged PNG paths, hashes, dimensions and inspection notes are in `batch-2026-11-11-1252.json`. Paired Pokémon releases have explicit aliases and verified IDs for both versions. Existing cover fallbacks remain. Delivery/publication status is tracked in that batch file.

## 2026-11-11 13:47 UTC expansion

Monster Hunter Generations and Rhythm Heaven Megamix were generated with built-in image_gen, visually inspected and accepted as unchanged 1536×1024 PNG scene masters. Their exact prompts, verified title-ID evidence, hashes, dimensions and inspection notes are in `batch-2026-11-11-1347.json`. Existing cover fallbacks remain. Mario & Luigi: Dream Team and Paper Mario: Sticker Star received image-tool output rejections and are blocked without retries or bypasses. Delivery/publication status is recorded in the batch file. Signed app/source snapshots remain unchanged; the public artwork catalog updates independently.

## 2026-11-11 16:56 UTC expansion

SteamWorld Dig, SteamWorld Heist, Bravely Second: End Layer and Dragon Quest VII: Fragments of the Forgotten Past have visually accepted original 1536×1024 scene masters. Exact built-in image_gen prompts, unchanged PNG hashes, pinned title-ID evidence, inspection and publication status are in `batch-2026-11-11-1656.json`. Existing cover fallbacks remain.

## 2026-11-11 18:13 UTC expansion

Professor Layton and the Azran Legacy and Professor Layton and the Miracle Mask have visually accepted original 1536×1024 PNG scene masters. Exact built-in image_gen prompts, unchanged master hashes, verified title-ID matches and publication status are in `batch-2026-11-11-1813.json`. Luigi’s Mansion (3DS remake) and Mario Tennis Open received output rejections and remain blocked without retries; their existing fallbacks remain. No gameplay, UI or signed release artifacts are changed.
