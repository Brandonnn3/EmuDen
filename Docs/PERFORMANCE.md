# Current performance work — build 17

Per-game profiles now isolate graphics choices. Resolution and texture sampling update when play resumes from settings, with transfer draining before the core's existing live update. Optional automatic quality lowers only the rendering scale after sustained poor/heat samples and recovers conservatively; it never goes below native 1× or above the selected ceiling. Single shader hitches are ignored. Known-shader preparation can move cached compilation into startup, with progress, but cannot precompile effects the game has never encountered. Per-game cache reset is confirmed and available only while that game is closed.

The optional frame-time overlay shows one-second samples of mean/worst core time, video FPS, speed, resolution and system heat severity. The final actual Mario Golf renderer starts at 3×, switches to 1×, then 2× with Smooth sampling, then 3× with Game default, and completes 841 frames including capture/restore. Captured image dimensions verify the live scale changes. This is correctness evidence rather than a paired performance comparison or a phone FPS result. [Build 17 details](BUILD-17.md) describe settings, safety boundaries and remaining checks.

Dark Moon was already at 1× in the owner's reported problem route, so lowering resolution cannot solve that particular hitch. The build-16 asynchronous pipeline change remains. Exact outdoor/window measurements, sustained thermals and the benefit of startup shader preparation on B Duo remain phone checks; no new percentage is claimed.

# Prior performance work — build 16

The owner's latest B Duo report has Mario Golf mostly at 60 FPS even at 3× with subtle drops. Dark Moon is mostly 60 FPS at 1× with Reduce shader pauses on, with approximately 1.5-second drops to 8 FPS outdoors and 24 FPS at the early ghost window. Resolution is already native in the problem case; shader/pipeline work is a plausible cause of transient stalls, not a confirmed diagnosis of that phone session.

Build 16 sends async-eligible Apple pipeline creation directly to the existing background worker instead of first probing the driver cache synchronously. Required draws still wait. Slow driver-construction logs supplement pipeline-wait logs. Both optimized cores build successfully, and the Mario Golf 3× rendering/state round trip passes in Simulator. A required post-restore wait of roughly 1.14 seconds remains in that test. New objects may appear late with asynchronous compilation.

Dark Moon again stops near frame 540 in the Mac's Simulator graphics service, with local SimMetalHost crash reports. The outside/window route and any new phone gain remain unverified. No percentage is claimed. [Build 16 details](BUILD-16.md) describe the patch and evidence. The historical measurements below apply to their named builds, not a new physical comparison.

# Duo performance pass — build 2

## Physical baseline

The owner confirmed that Mario Golf starts on B Duo but feels laggy, while Ocarina of Time feels smoother. The Mario Golf session log was copied from the installed app to `build/b-duo-performance-before.log` before replacing the build.

The log identifies physical model `iPhone19,4` and the Apple A20 Pro GPU through MoltenVK. Five 120-frame samples averaged **21.77 ms per core frame**, including **2.31 ms of GPU readback**. Thermal state was 0 throughout those samples. These are early-session measurements, not a sustained gameplay benchmark. The log also contained 8,317 lines in about 20 seconds of wall time, including large bursts of debug GPU-register messages.

## Changes

- The interpreter now shares decoded blocks consistently with its existing single shared translation buffer. Switching emulated CPUs within the same address space retains decoded instructions. Switching address spaces or explicitly invalidating code clears the shared cache. ARM and Thumb entries use distinct keys. The cache recycles before exhausting its fixed buffer. Guest CPU execution remains serial, as required by the existing global translation buffer.
- The core filters debug messages before formatting them. The frontend also rejects debug callbacks and buffers routine log writes. Warnings, errors and timing samples are flushed for diagnosis.
- GPU frames retain their native RGBA/BGRA layout. Core Graphics copies directly from the completed mapped readback buffer, avoiding a CPU channel-swizzle loop and an intermediate full-frame copy. The image owns its data before the next frame can reuse that buffer.
- The emulation queue uses interactive quality of service. Hardware test builds use the optimized Release configuration.
- The current and previous session logs are retained in `Files → Emulator → Saves` so two games can be compared without losing the first log.

The emulated CPU clock, guest frame pacing, native resolution and shader accuracy are unchanged. CPU and shader JIT remain disabled. These changes do not establish a particular frame-rate gain on the phone.

## Next physical comparison

Use the same Mario Golf save, camera and scene as build 1. Compare steady game speed, sound and the FPS counter after initial shader compilation. Then repeat Ocarina of Time to check for regressions. Record a 10-minute session and inspect thermal state, the current log and the previous log. Keep Castle Club and original Mii-resource compatibility as separate checks.

## Build 5

The owner's later report describes approximately 49 FPS with dips to 10–15 FPS in Mario Golf gameplay. The backed-up Mario session includes 120-frame averages of roughly 18–29 ms, with about 1–1.6 ms of readback; these averages do not resolve individual long frames. Animal Crossing's separate captured session is faster. New logs therefore also report the worst frame and count frames over 33 ms.

The libretro device negotiation omitted extended dynamic state and pipeline creation cache control even though the renderer detected the device's support. `azahar-moltenvk-features.patch` queries and enables these features on Apple platforms. The simulator log confirms dynamic_state=1 and pipeline_cache_control=1. Dynamic state avoids baking additional changing render state into pipeline variants; no resolution, emulated clock or multiplication-accuracy reduction was introduced. Physical FPS improvement is not established by this finding.

Core save restoration also recreated a renderer without its live shader cache, producing a reproducible `ShaderDiskCache::UseProgrammableVertexShader` null dereference. `azahar-save-state-cache.patch` initializes those caches before drawing. This is a correctness fix required for quick/resume states, separate from the gameplay-speed question.

The software shader interpreter also constructed three heap-backed circular stacks per run. The fixed stack keeps the same capacity, overwrite-oldest, mutation and pop behavior using inline storage. 400,000 randomized operations matched the original Boost containers, and AddressSanitizer/UndefinedBehaviorSanitizer passed. Disassembly of the optimized release interpreter confirms three `operator new` call sites before the change and none afterward (`build/build5-shader-allocation-report.json`). This removes temporary allocation work on CPU shader fallback paths; a microbenchmark or allocation count is not a device FPS result.

## Build 6

The owner reports a substantial Mario Golf improvement and repeated first-visit freezes in Luigi’s Mansion: Dark Moon. Dark Moon’s file has an iCloud upload error and is unavailable on the Mac; its exact scene cannot be profiled locally. No percentage gain or full-speed claim is established.

The existing asynchronous Vulkan shader mode was not exposed by the libretro settings parser. It is now wired to Player settings → Reduce shader pauses, with an explicit restart requirement and the late-object tradeoff. It defaults off. Disk caches remain enabled in both modes. The new pipeline-wait log identified a 1,903 ms wait in Mario Golf on the simulator; this is a Mac-side diagnostic, not a phone measurement.

A state-restore regression also revealed that caches were loaded before restoring per-game accurate-multiplication settings. This produced a driver/user shader-profile mismatch and regeneration after every restore. The state-cache patch now applies the loader’s per-game settings first. The repeated Mario Golf character-selector restore completed without the previous mismatch, then delivered another 120 frames.

The current CPU runs in the interpreter. Further gains depend on the game’s CPU workload, shader variety, renderer synchronization and sustained thermals. Simulator FPS cannot predict physical Duo performance. Compare the same Dark Moon room and route with the setting off/on, and compare first visit with a repeat visit before estimating a gain.

## Owner Dark Moon test on build 18 — November 11, 2026

The owner reports initially smooth play at1× with the new settings enabled, followed by sustained slowdown after a longer session. Their supplied photograph shows46.8FPS,77% speed,21.4ms average/26ms peak and Hot. This is owner device evidence, not an agent phone benchmark. The thermal warning supports investigating heat alongside shader compilation; it does not by itself identify the CPU/GPU bottleneck or prove thermal throttling.

The existing prepare-known-shaders option rebuilds previously encountered transferable shaders/pipelines before play. Import alone cannot enumerate every shader/render-state combination used at runtime; a new title has no learned cache until it runs. Core vk_pipeline_cache.cpp LoadCache/LoadDiskCache builds from recorded entries, and its workers capture newly observed states. Import-time ROM scanning is not a complete replacement. Startup preparation does not eliminate sustained thermal slowdown. Automatic quality is already at its1× floor in this report. Keep first-encounter stutters, warmed-repeat behavior and steady heat-related slowdown separate in future measurements. No new phone FPS gain is claimed for build19.
