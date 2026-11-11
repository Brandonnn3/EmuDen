# Build 5 gameplay fixes

The owner reported Mario Golf at about 49 FPS with 10–15 FPS dips, flat guest Mii heads, Detective Pikachu stuck on saving, missing quick saves, slow touch response, and a request for a realistic dual-screen skin.

## Implementation

- Brief button/touch presses are retained until a core input poll. UIKit touch-down, move, release and cancellation replace drag recognition on buttons, the circle pad and the lower screen. Button haptics have an on-device preference.
- Separate per-game Quick Save and Resume files use atomic writes and SHA-256 integrity checks. Resume is captured on normal exit/background; relaunch offers to resume or start normally. The game's native save folders are preserved.
- A round-trip test exposed a core shader-cache null dereference after deserializing/recreating the renderer. A reproducible source patch initializes the new renderer's caches before another draw.
- MoltenVK negotiation now enables queried extended dynamic state and pipeline creation cache control. The previous core detected these capabilities without enabling them. No CPU clock, shader accuracy or internal resolution was reduced.
- An original graphite shell has bezels, a camera, speakers, hinge detail and physical-looking buttons. Controller connection hides touch controls; settings choose the shell with original proportions or screens filling each Duo panel. Full panels intentionally changes picture proportions; touch mapping remains normalized to the displayed screen.
- The built-in guest head uses closed 3D geometry, a hair cap and a curved face canvas. It is generic. The Mii resource status is now a direct import button, validating the decrypted console archive's title and RomFS bounds. Nintendo assets are not included.
- Current/previous logs are retained, and closed sessions also keep a per-game log. Frame samples include the worst frame and the number exceeding 33 ms.

## Evidence and remaining checks

Phone saves and logs were backed up read-only before development. Mario Golf, Ocarina and Detective Pikachu have nonempty game-save files in the backup. Animal Crossing's captured timing samples are faster; file existence does not prove progress was committed at the moment a game was closed.

Sixteen domain checks cover imports, save integrity/slots, preservation, and fold geometry. The input-latch self-check verifies short press/release capture and clearing. Both optimized arm64 cores rebuilt with real matching dSYMs. Final simulator results and archive readiness are recorded in TestFlight/STATUS.md.

Detective Pikachu's 2 GB file could not be copied completely from the phone. The partial test copy is not used as a valid game. At the owner's direction, testing continues on the dedicated Duo simulator and the physical phone is left alone. Detective Pikachu's saving hang remains unverified; no compatibility fix is claimed for it.

Simulator timings use the Mac CPU/GPU and may be affected by other work on this 8 GB Mac. The Mario Golf course slowdown, authentic console Mii resources, physical haptics/controller hardware and sustained thermal behavior require a device comparison. The changes do not establish a full-speed gameplay claim.

## Direct simulator regression

Because iOS 27.1's UI test runner also aborted before some scene attempts, the simulator build has a `--golf-regression` fixture (excluded from physical-device compilation). Launch together with `--boot-test-game --fresh-start` and `SIMCTL_CHILD_EMULATOR_TEST_ROM_PATH` pointing to the owner's local Mario Golf file. It advances menus, captures raw top/bottom frames under `Documents/Saves/GolfRegression`, captures/restores a quick state, then requires another 120 displayed frames before writing `result.json` and pausing. This uses the app's real bridge/core and normal state store. It does not claim a physical-hardware performance result.

The first direct run passed with 1,321 delivered frames, a successful state capture/restore and continuing course-selection rendering. The emulator simulator used copies of the backed-up Mario save and Mii database; no phone data was changed.

The final direct checks reached Forest Course loading and selected the Mii through lower-screen pointer input. The frame at 750 shows a rounded generic head and hair cap from an angle, replacing the old flat billboard. Another quick-state round trip passed with at least 120 post-restore frames. This does not establish original console Mii resource compatibility or sustained course speed on the phone.

The CPU shader interpreter's temporary circular stacks now use inline storage. Four hundred thousand randomized operations matched the old Boost behavior; sanitizer checks passed. Optimized binary inspection confirms three allocation calls before and zero after. The shader math, 3DS CPU clock, accuracy settings and native resolution are unchanged.
