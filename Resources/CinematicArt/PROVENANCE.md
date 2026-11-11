# Option A illustration assets

These are illustrative menu textures, not emulator screenshots or game/system files. They never start emulation or produce preview audio.

- `Approved-A-Wide.png`: unmodified copy of the owner-approved `Docs/Mockups/Duo-Inner-v1/A-Cinematic-Inner-Home.png` concept.
- `Approved-A-Portrait.png`: unmodified copy of the owner-approved `Docs/Mockups/Liquid-Glass-v1/A-Cinematic.png` concept.
- `Golf-Scene-Wide.png`: clean scenic background produced with the built-in image generation tool using the approved wide concept as the edit target. The exact prompt is the `Hero-Wide` job in `Docs/Design/Option-A-Assets/prompts.json`.
- `Forest-Scene-Wide.png`: original forest-village illustration produced with the built-in image generation tool. Brief: a lush stylized forest village with tree houses, a stream, warm sunlight and open space for native controls; no characters, text or UI. This brief records the asset's purpose rather than a verbatim prompt transcript.

`App/CinematicArt.swift` samples only illustration regions from the approved sheets for game-cover cards and a portrait scenic detail. The complete mockup is never presented as the app interface. Text, search, navigation, buttons, focus, panels, transitions and the opening console are native SwiftUI views. The clean wide backgrounds allow the native layout to adapt to different screen sizes.

Manual scene imports take precedence over curated scenes. Other game covers and available thumbnails still use the app's existing artwork cache. The original nine sound cues and their synthesis recipe are recorded separately in `Resources/MenuAudio/` and `Scripts/generate-menu-audio.py`.

## Build 12 console scenes

Original generic 3DS, PSP, PlayStation and GameCube illustrations are saved as Console-3ds.png, Console-psp.png, Console-ps1.png and Console-gamecube.png. Exact built-in image_gen prompts and source output paths are recorded in Docs/Design/Build12-Console-Art/prompts.json. Masters are 1,254 × 1,254 pixels.

Title-IDs.json retains only title names and release IDs from the pinned Azahar compatibility data. Its source checksum and attribution are in Docs/Design/Build12-Console-Art/PROVENANCE.md. No console keys, games or system resources are included.

## Build 13 downloadable collection

`Artwork-Pack.json` is the small versioned metadata seed for the public EmuDen artwork feed. The 52 delivery images remain on the artwork host and download on demand; they are not bundled into the app. The first collection has 28 scenes and 24 covers, covering 25 ranked game families and three library extras. Four covers continue to use existing fallbacks. Exact built-in image_gen prompts, accepted master paths, revisions and missing coverage are recorded in `Docs/Design/Build13-Artwork/PROVENANCE.md`, the three linked generation ledgers and `final-assets.json`. Downloaded images are original fan illustrations, not gameplay captures or official box scans.

The owner authorized public access to the gallery, generated JPEGs and game-title/ID metadata at https://emuden-artwork-catalog.headyopossum2.chatgpt.site. No app source, games, saves, console system resources, signing data or contact details are part of that public host. Explicitly imported images continue to take priority over catalog images; console backgrounds remain available offline.
