# EmuDen build 13 — downloadable artwork collection

Build 13 adds a versioned artwork catalog, original portrait covers and cinematic scenes. The first collection uses the first 25 ranked entries of an archived [GameFAQs community top-100 poll](https://gamefaqs.gamespot.com/boards/997614-nintendo-3ds/76853179), with normalized English release names. Paired Pokémon releases and Fire Emblem Fates editions share their ranked family entry. Donkey Kong Country Returns 3D, Tomodachi Life and Luigi’s Mansion: Dark Moon are included as current-library extras. This is a pinned community selection, not a current sales chart or emulator compatibility ranking.

The selection is recorded in [selection.json](Design/Build13-Artwork/selection.json). The selected collection contains **52 original fan illustrations: 28 landscape scenes and 24 portrait covers**. Four covers (A Link Between Worlds, Ocarina of Time 3D, Super Mario 3D Land and Donkey Kong Country Returns 3D) retain existing fallbacks after image-tool output-stage rejections; each has a new scene. Exact final prompts, built-in imagegen source paths, output dimensions, references and visual checks are recorded in the [generation provenance](Design/Build13-Artwork/PROVENANCE.md) and three linked artwork ledgers. Image masters live under `ArtworkMasters/3ds/<game-key>/`. JPEG delivery files are encoded from the accepted PNG masters without changing their composition. The PNGs are preserved.

## Native behavior

User-selected images have first priority. Available collection images follow, then existing curated artwork, standard downloaded covers, saved high-resolution scenes, and the bundled console background. Missing collection images do not make a game unavailable. No game, save or system-data file is used as an artwork asset. The approved Option A interface and the build-12 search dock fix remain.

Matching uses a known retail program ID, then exact normalized title aliases. An explicit artwork-title correction overrides the program ID. Known demo/trailer IDs are excluded. Regional spelling and paired editions are explicit; fuzzy matching cannot select a different sequel.

The app includes a small catalog seed and checks the hosted index at startup/foreground. Repeated checks while browsing are throttled for six hours; resuming from paused networking allows a fresh check. A newer valid index can update images without an app release. Catalog versions must increase. Index origin changes, invalid schema, ambiguous IDs/names, unsafe paths and oversized/low-resolution descriptors are rejected.

Images download on demand. HTTPS origin, byte count, full SHA-256 and decoded dimensions are checked. Automatic data is stored in the OS-managed cache directory and excluded from backup; the OS may reclaim it. Explicitly imported user images remain separate in Documents. A previous successful collection image stays available if its replacement cannot download. Network requests are cancelled and paused during emulation, while cached images remain usable.

## Artwork host

The [public artwork gallery](https://emuden-artwork-catalog.headyopossum2.chatgpt.site) and [catalog index](https://emuden-artwork-catalog.headyopossum2.chatgpt.site/catalog.json) are live. The owner explicitly selected public access for generated images and game-title/ID metadata. `ArtworkCatalog` is a separate Sites checkout; its `.openai/hosting.json` identifies the artwork Site. The native app, developer contact, signing information, ROMs, saves and system resources are outside that checkout. The verified deployed source commit is `4b6a0990c9c64da1106dbd82858241425f133bf8` (catalog revision 2).

`Scripts/build-artwork-catalog.py` validates the PNG shapes, transcodes delivery JPEGs, computes content-addressed URLs, writes `dist/catalog.json`, and updates the identical app seed at `Resources/CinematicArt/Artwork-Pack.json`. A changed published catalog requires a higher version. Explicit unavailable images may use fallbacks via `--allow-fallbacks`; missing coverage is recorded in `build/build13-artwork-pack-validation.json`.

## Verification

43 domain tests passed. They cover ID/name/override precedence, URL/path/geometry validation, ambiguous metadata, missing-art fallbacks, verified caching and offline relaunch, corrupt/oversized responses, new versions and previous-image preservation, disabled networking and in-flight cancellation. The actual Swift catalog client anonymously downloaded and hash-verified all 52 images (35,476,617 bytes), accepted a newer index, then reused every image with networking disabled. This is separate from the UI fixtures, which use the same verified images preseeded in cache for deterministic offline review.

Five Duo artwork/navigation scenarios passed, including artwork correction/reset, both fold layout fixtures, future-system gating, collection previews and search with the keyboard shown/dismissed/closed. Two separate real-game regression scenarios passed: Mario Golf launch and Homebrew Menu quick save/load/relaunch/resume. Metadata-only artwork fixtures do not establish game compatibility. Final captures, the shelf-selection polish check and archive/source verification are recorded in the preparation report and [preview notes](Preview/Build13-README.md).

The 3DS core, shaders, Bridge and save-state format are unchanged. The owner cannot test the phone now; true inner-display, continuous physical folding, phone haptics, thermal behavior and sustained gameplay performance remain unverified in this build.
