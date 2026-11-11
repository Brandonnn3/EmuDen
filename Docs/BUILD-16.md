# Build 16 — full outer display and shader-stall work

The owner's B Duo test reports Mario Golf mostly at 60 FPS even at 3×, with subtle dips. Dark Moon is mostly 60 FPS at 1× with Reduce shader pauses enabled, but drops to about 8 FPS on the first outdoor route and 24 FPS at the early ghost window, recovering after roughly 1.5 seconds. These are owner reports; the new core has not been measured in those exact scenes on the phone.

## Fill display

The existing controller panel preference only expanded fold-aware inner layouts. The standard outer layout still centered two aspect-fitted screens inside padding and safe-area margins. Player Settings → Duo layout → **Fill display** now expands across the active display, including its container safe areas. In portrait, the screens occupy equal-height full-width regions. In landscape, they occupy the full height with a 5:4 width split. The floating toolbar stays inside the safe area and retains its auto-hide behavior. Lower-screen touch uses the displayed region's normalized coordinates.

The stored preference remains `panels`, so existing selections carry over. This mode stretches the picture to fill its regions; **Console skin** retains original screen proportions and the shell. Touch controls hide for a connected controller, and the inner split continues to respect the fold. No new layout mode is introduced.

## Shader pipeline work

`Scripts/azahar-async-pipeline-probe.patch` changes Apple's asynchronous path. Previously, even an async-eligible draw could first attempt a synchronous driver-cache lookup through `Build(true)`. Pipeline creation may do work inside the Metal/Vulkan driver. These draws now go directly to the existing background worker; required draws retain their waits. Turning Reduce shader pauses off still uses the synchronous path. As with the existing async option, newly encountered objects may appear late while their pipelines compile.

Driver pipeline-construction calls taking at least 20 ms log their duration and whether they were cache probes, alongside the existing pipeline-wait diagnostics. This helps distinguish compilation from routine emulation cost. The change is a targeted stutter candidate, not a measured Dark Moon phone improvement. Some required waits remain: the Simulator Mario Golf state test logged a roughly 1.14-second wait after restoring the renderer. No CPU clock, CPU/shader JIT, multiplication accuracy, frame skipping, save format or resolution default changes.

Both optimized device and Simulator cores are rebuilt with matching real dSYMs. The deterministic patch driver includes the new patch. Shader-cache version inputs and snapshot-generation identifiers remain unchanged.

## Checks and limits

- 45 domain tests passed, including full-bounds outer-screen partitions in both orientations.
- The actual Mario Golf 3× renderer completed 841 frames, captured/restored a state and continued rendering. The post-restore captures are 1200×720 and 960×720 and were visually inspected, including the imported Mii's face. This is a Mac correctness check, not a phone FPS benchmark.
- The outer UI check measures both screen regions against the entire app bounds and checks lower-screen touch coordinates (80, 180). It passed in portrait, including after a landscape orientation request; capture inspection shows that this Duo Simulator kept the app in portrait. Landscape geometry passes domain tests, but its live appearance remains unverified. Capture names now use the actual app bounds. Existing inner panel, shell, book and tabletop scenarios are retained. Final results and earlier failures are recorded in `build/TestFlight/Build16-PreparationReport.json`.
- Dark Moon stopped around frame 540 during startup with a crash in Apple's Simulator `SimMetalHost` graphics service. Two local crash reports and the partial session/captures are retained under `build/Build16-Dark-Moon-Startup`. This also affected the earlier baseline. The exact outdoor/window scene is unverified; no new performance percentage is claimed.

The live public artwork catalog is now version 4 with **34 scenes and 24 covers**. This pass added Kirby: Triple Deluxe, Ever Oasis, Pokémon X/Y, and Pokémon Ultra Sun/Ultra Moon. Prompts, unchanged-master hashes, verified IDs and anonymous/offline checks are in `Docs/Design/ArtworkCatalog/batch-2026-11-11-1252.json`. Previous image URLs remain. The icon, menu sounds and approved Option A artwork transition remain unchanged.

Builds 14 and 15 retain their signed archives and matching source packages. Build 16 is prepared separately for the owner's internal TestFlight upload. No phone installation, TestFlight upload or distribution IPA export is performed. Live landscape layout, physical folding, controller hardware, temperatures and the exact Dark Moon route remain phone checks.
