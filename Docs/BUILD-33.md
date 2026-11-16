# Build33 — a console-aware Home, Library and Duo

New isolated33 branch/worktree from5af921b. All prior signed archives and exact
source packages, all artwork/public URLs and owner data remain preserved.
Godzilla still freezes in the owner's32 check; this build does not claim a fix.

Home gains a third header console menu and a console-specific controller icon.
Settings has a persisted Favorite console; startup and the Home button open it.
Unavailable/unknown favorite values fall back to3DS. Selecting a console while
in Library changes only its filter and stays in Library, including empty
collections. Sort persists Recently Added (import timestamp, not last played)
or natural A–Z with deterministic ties. Home's recently played shelf remains.

PS1 retains the actual NEON1×/2× internal renderer. Adds smooth/crisp final
display scaling, emulated color dithering and the existing2× texture-alignment
fix. No fictitious higher internal multipliers. GC gains real1–4× EFB scale,
game-default/crisp/smooth texture filtering, and default/1/2/4/8/16× anisotropy.
Settings use the existing defaults/per-game profile store with backward decode
and bounds. Original defaults remain native resolution, game filtering, PS1
dithering/texture-fix on and final display smoothing off.

The GC graphics C ABI holds requested options before boot and applies them to
Dolphin's CurrentRun configuration. Live changes use the existing CPU/GPU pause
guard and refresh/check the video configuration even if the scene emits no new
GX frame. Native diagnostics expose actual EFB texture dimensions plus active
configuration in owned Simulator; labels alone are not rendering evidence.
Higher resolution can cost performance and does not fix unsupported game code,
create extra source-image detail or establish phone speed.

Duo uses the selected console from Home, Settings and the player.3DS keeps its
clamshell opening. Original code-drawn PS1 and GC controllers ease into a screen
connection, with metallic shading, distinct buttons/sticks, drag tilt/spring
return and replay. No new bitmap artwork/generation/remote source. Reduce Motion
uses a static pose. Single-screen choices use existing picture-size/fold settings;
per-game Player settings override defaults. Touch controls still hide for a
controller, and landscape input/video geometry remains the existing behavior.

Both iOS cores were fully built from fresh pinned sanitized Dolphin source and
dependencies. A final normal CMake frontend update fixes static/paused graphics
application against those exact unchanged static archives. Genuine new symbols,
metadata and resource/key-policy audits accompany both slices. No source/CPU JIT,
private broker, executable allocation bypass, proprietary game/BIOS download or
new dependency was added. Complete corresponding source/notices remain required.

104 domain tests pass (one existing private-resource skip). Initial native/UI
failures and corrections are recorded in BUILD-33-PROGRESS.md. Final actual
result bundles, hashes and signed archive checks are recorded separately when
complete. Only original/licensed software in an owned QA Simulator is used;
owner games, phone, saves and accounts are untouched. Physical Duo/phone speed,
retail compatibility, actual Apple processing and legal/distribution clearance
remain outside these engineering checks. No upload/public submission or new
automation is authorized/performed.

Pinned primary renderer definitions:
https://github.com/libretro/pcsx_rearmed/blob/7b0e8f8fadfbce3d170d195b9d9eecaabfa08c8e/frontend/libretro_core_options.h
https://github.com/dolphin-emu/dolphin/blob/f84df02055ab9610feec48e65648cac5a3c098fa/Source/Core/Core/Config/GraphicsSettings.cpp
