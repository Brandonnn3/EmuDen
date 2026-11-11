# Collection 01 — generation and delivery provenance

The collection selects the first 25 ranked entries from the archived [GameFAQs 3DS community top-100 poll](https://gamefaqs.gamespot.com/boards/997614-nintendo-3ds/76853179), normalized to English release titles. This is a historical community selection, not a new universal ranking or an emulator compatibility list. Paired Pokémon releases and the Fire Emblem Fates family share their ranked entry. Three current-library extras are Donkey Kong Country Returns 3D, Tomodachi Life and Luigi’s Mansion: Dark Moon.

All new game artwork used the **built-in image_gen tool**, not the API/CLI fallback. The final selection contains **52 original fan illustrations: 28 landscape scenes and 24 portrait covers**. Covers are 1,024 × 1,536 pixels. Scenes are either 1,536 × 1,024 or 1,659 × 948 pixels. Every accepted image was viewed and checked. These are illustrations, not gameplay captures or official box scans.

- [Selection and retail IDs](selection.json).
- [Ranks 1–9: exact prompts, sources, review and rejected attempts](artwork-a.json).
- [Ranks 10–18: exact prompts, sources and revisions](artwork-b.json).
- [Ranks 19–25 and library extras](artwork-c.json).
- [Authoritative selected master paths/hashes and delivery descriptors](final-assets.json).

The PNG masters remain at `ArtworkMasters/3ds/<game-key>/{cover,scene}.png` on the project SSD. Delivery JPEGs are encoded at quality 86 and stored by content hash under `ArtworkCatalog/dist/images/`. Transcoding changes file encoding only; visual revisions use imagegen. Earlier source images and tool-generated originals are retained.

The Pokémon scene was revised after independent review found that its original paired composition clipped a face in a narrow phone crop. The selected `scene-v2.png` is copied to canonical `scene.png`. The earlier scene is preserved as `scene-v1.png`, and both revision records remain in the B ledger. Both Pokémon faces remain recognizable in the checked center crop.

Four cover jobs returned image-tool output-stage rejection errors: A Link Between Worlds, Ocarina of Time 3D, Super Mario 3D Land, and Donkey Kong Country Returns 3D. Their cover fields are explicitly absent. The app keeps existing curated/standard covers, and all four have new scenes. The accepted Smash scene/cover, Mario scene and Donkey Kong scene use environmental compositions; no unavailable generated image is silently substituted with a scan.

The public read-only host contains generated JPEGs, gallery files and title/ID metadata. The owner explicitly selected public artwork access in this conversation. App source, commercial game files, saves, Nintendo system archives, signing data and developer contact files were not uploaded to that host. Exact local generation paths and prompts stay in the workspace/source package, outside the public gallery.

Known retail title IDs come from the pinned Azahar data already used by build 12. Existing upstream source/license provenance remains included in the matching app source. The gallery credits game names and characters to their respective owners; this document makes no claim that fan illustrations are official publisher assets.
