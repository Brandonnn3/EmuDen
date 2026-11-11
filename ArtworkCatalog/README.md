# EmuDen artwork catalog

This checkout contains only the read-only artwork gallery, original fan illustrations and title-ID catalog. The Swift app and game/system/save files live outside this checkout.

`dist/catalog.json` is the versioned index. Image URLs contain their content digest; the native client verifies the complete SHA-256, byte count and dimensions before display. Only images needed for a selected game or visible cover are downloaded. The client preserves its previous image when an update fails, and pauses network tasks during emulation.

The first selection uses the first 25 ranked entries of the archived [GameFAQs community poll](https://gamefaqs.gamespot.com/boards/997614-nintendo-3ds/76853179), plus three current-library titles. Paired Pokémon versions and Fire Emblem Fates share their ranked family entry. Illustrations are generated fan art, not screenshots or official box scans. Asset availability is explicit; missing images use existing app artwork or a console background.

To update: generate and visually inspect new PNG masters in the parent workspace, increment `catalog-config.json`'s version, and run `python3 Scripts/build-artwork-catalog.py` from the parent workspace. Use `--allow-fallbacks` only when documented unavailable images should use the existing fallback. The app's catalog seed is updated by that script. Validate and publish the exact static checkout through Sites. No dependency installation or frontend build is needed.

Later background expansion uses `Docs/Design/ArtworkCatalog/selection.json` and its queue in the parent workspace. Catalog v3 adds Kirby Planet Robobot and Pilotwings Resort scenes; the first 25 ranked entries remain unchanged. Follow that folder’s README for acceptance, validation and publishing.

Catalog v4 expands to 34 scene backgrounds with Kirby: Triple Deluxe, Ever Oasis, Pokémon X / Pokémon Y and Pokémon Ultra Sun / Pokémon Ultra Moon. Existing cover artwork and all earlier content-addressed image URLs are retained.

Catalog v5 adds Monster Hunter Generations and Rhythm Heaven Megamix, bringing the collection to 36 scene backgrounds and 24 covers. Prior image URLs remain unchanged. These are original fan illustrations; no compatibility claim or game/system data is included.

Catalog v6 adds SteamWorld Dig, SteamWorld Heist, Bravely Second and Dragon Quest VII, bringing the collection to 40 scene backgrounds and 24 covers. Prior image URLs remain unchanged.
