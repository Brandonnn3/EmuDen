# EmuDen 0.1.0 (11) — Option A reference match

This build corrects the visual drift from the approved Option A concepts. The wide home uses the golf-course composition, large landscape cover cards, white Play capsule, circular search/controller controls and a floating clear-glass dock. The extra platform rail and Mii-status line have been removed from Home. Console selection remains available from the Nintendo 3DS filter and Library.

The Library uses the approved portrait illustrations and a simple filter/search row, with four columns on the inner display and two on normal phone widths. Settings remains in the dock navigation, with performance and appearance cards beside Mii setup on the inner display. Pause is a centered floating panel with Resume, Quick save, Quick load, Screen layout and Return to library. Additional player options remain under its ellipsis menu. The pause overlay blocks underlying game controls and accessibility elements.

Duo layout opens across the display. The graphite console unfolds on entry, with side-by-side Console skin / Fill Duo panels choices and controller status. Search expansion, cover selection, page entrance, button feedback and the existing nine original sound cues remain. Resume/save cues finish before gameplay audio resumes. Reduce Motion and Reduce Transparency retain their established fallbacks. Full-screen Duo, Mii and player settings hide system status chrome consistently with Home.

## Artwork

Approved concept sheets supply illustration regions only. The complete mockup is never rendered as the interface; all controls and navigation are native. Clean scenic assets were made using the built-in image generation tool. These are menu illustrations rather than live gameplay previews. Asset paths and provenance: [CinematicArt](../Resources/CinematicArt/PROVENANCE.md). Recorded generation prompts: [prompt set](Design/Option-A-Assets/prompts.json).

Curated illustrations apply to Mario Golf: World Tour, Ocarina of Time 3D, Animal Crossing: New Leaf and Dark Moon. A manually chosen scene takes priority and is protected from automatic captures. Other games retain the existing cover/scene download and local gameplay-preview cache.

Artwork regions are drawn inside bounded native canvases. An initial oversized image implementation exposed hit regions outside the visible cards, obstructing compact browsing and the console filter. The corrected implementation passed both fold fixtures, card selection, console selection and real-game launch.

## Compatibility and distribution

The Azahar FastInterp and MoltenVK device binaries, rendering settings and native/quick/resume save formats are unchanged from build 10. This is a design update; it does not establish a new phone FPS result or resolve the earlier physical-device GPU failure. Keep Reduce shader pauses enabled for the owner's Mario Golf retest.

Only Nintendo 3DS is playable. PSP, PS1 and GameCube remain clearly marked Coming soon. No commercial game files, downloaded Nintendo system archives, personal Miis, user saves, crash reports or signing credentials are packaged.

Build 10 and its source/archive remain preserved. Build 11 uses separate archive and source-package filenames. Phone installation and TestFlight upload are separate from this local preparation.

## Verification

Validation evidence is stored in `build/Build11-Reference-UI.xcresult`, `build/Build11-Regression-UI.xcresult`, `build/Build11-Final-UI.xcresult`, `build/Build11-Compact-UI.xcresult`, `build/Build11-Portrait-Final-UI.xcresult`, `build/Build11-Modal-Chrome-UI.xcresult` and `build/build11-domain-tests.log`. The earlier regression bundle retains the three failures corrected by the final runs. Final results and reviewed screenshots are listed in [artifact status](../TestFlight/STATUS.md).

The last live comparison on the inner display is deferred until the owner returns to unlock the Mac. Physical phone sound/haptics, continuous fold transitions and game performance still require device testing. Simulator results use the Mac's CPU/GPU.
