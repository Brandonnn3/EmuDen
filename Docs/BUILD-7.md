# Build 7: console home

The library is now a console-style home screen inspired by the PSP's flowing atmosphere and the Switch's focused game shelf.

## Interface

- Midnight-blue native Canvas waves, restrained particles, cyan selection glow and coral quick actions. The 24 fps background stops when the library is inactive, a sheet/import is open or a game is running. Reduce Motion produces a static background. The launch background matches the home screen.
- A snapping horizontal shelf centers the selected real cover. Swipe or tap a neighboring cover to select; tap the selected cover or Start/Continue to launch. Title, system and recent-play status follow selection. DAT-style titles are cleaned for display without changing their stored names or artwork matching.
- Collection switches to a compact grid. Search works in either view. Long-press a cover retains Find game artwork.
- The quick-action dock opens controls, game import and settings. Existing system-data import, Mii setup, save states, resume choices and core launch arguments remain wired to the same storage/session code.
- Duo fold regions place title/art atmosphere on one panel and browsing/actions on the other. Narrow panels use icon tabs and compact controls. When space is short, the selected cover remains the launch button. Simulator pose fixtures are `--library-tabletop-preview` and `--library-book-preview`.
- Connected extended controllers use D-pad/stick left/right to select, the primary button to start, secondary to return home/close search, and the top button for settings. Glyphs come from the controller's mapped SF Symbols. Element handlers are released while the player owns the profile handler. Hardware keyboard arrows/Return/Escape are also wired; physical controller feel and haptics still require a phone check.

No emulator-core or graphics/performance settings were changed in this UI pass. Nintendo game covers and Mii resources remain user/runtime data, excluded from the app and source bundle.

## Validation

The flat-home simulator check exercised swiping between real games, collection, search, launching Mario Golf through the new Start button, and returning to the library. Duo fixtures check actual interactive controls and their positions across the fold; accessibility container frames can include clipped offscreen scroll content. The existing library/Mii and Quick Save/Load/relaunch/resume regressions also run.

Earlier checks exposed narrow-panel overflow; responsive tabs, constrained panels and the compact dock fixed it. The launch check explicitly handles a previously saved resume point and waits for actual colored game pixels, rather than assuming the first 60 frames are past a game's black startup fade. Exact final results are recorded in TestFlight/STATUS.md.

Final result: all four Release UI regressions passed in `build/EmuDen-Build7-Console4.xcresult`. The device archive passed local packaging/signing/privacy checks and has real matching app/Azahar/MoltenVK symbols. The emulator framework UUIDs are unchanged from build 6. Build 7 was not uploaded, exported as an IPA or installed on the phone.
