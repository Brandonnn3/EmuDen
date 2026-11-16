# Build33 — console navigation, graphics and Duo presentations

Base5af921b in isolated EmuDenConsole33 / console-experience-build33.32 and
all older signed/source releases remain frozen. Godzilla32 owner test still
freezes after Start; profile was not a confirmed remedy. Sonic Riders owner
report is positive, not broad retail compatibility. Stop Godzilla tuning.

Authorized scope: header console menu; favorite console for Home; Library
console filter stays in Library plus Recently Added/A–Z; actual supported
PS1/GameCube graphics controls; responsive native controller/screen connection
animations for PS1 and GC, preserving the3DS clamshell. No artwork generation
or publication. Automation stays deleted. No binary upload/public release,
owner phone/ROM/save access, JIT/private brokers or proprietary downloads.

No active compiler/emulator processes at start. Private dependencies linked;
Dolphin frameworks/dSYMs copied into33 before any frontend build so earlier
binaries cannot be overwritten. Next inspect core option limits and implement.

Implemented header console picker, favorite Home/start destination, Library
console-preserving filter, empty-console grid and persisted Recently Added/A–Z
sort. New graphics settings migrate old profiles/defaults. PS1 uses existing
2× NEON renderer, real dithering/texture-fix core options and crisp/smooth final
sampling. GC native C ABI configures1–4× EFB, Default/Nearest/Linear textures
and default/1/2/4/8/16× anisotropy. PS1/GC original vector controllers animate
into a screen connection and tilt with drag;3DS clamshell is retained. Header
controller thumbnail and preview follow selected console. No extra image assets.

Full Device and Simulator pinned sanitized CMake builds completed with genuine
symbols. First original-native check caught Config2× with actual640×528 EFB in
a static GX scene: no subsequent GX frame applied the renderer update. Fixed by
refreshing/checking video config under the existing CPU/GPU pause guard. Normal
CMake frontend updates followed against each fresh33 build; every static archive
hash stayed identical. Initial binaries/symbols and failures preserved. Both final
binaries pass the existing resource/default-key screen.104 domain tests pass,
one existing private-resource skip; no owner ROM/phone/save data accessed.

Initial Simulator invocation selected unwanted x86_64 too; interrupted only that
own build. An early arm64 retry encountered the still-active database lock, then
completed after the old invocation exited. One compile type mismatch between
ConsoleSystem and GamePlatform in the scene fallback was corrected. Final arm64
build-for-testing passes. Original native/UI run: controller presentations passed
portrait/landscape/drag/replay; navigation assertion read stale AX menu value;
PS1 exact2× framebuffer succeeded but its restore toggle wait timed out despite
value reaching expected1. Replaced immediate menu-value assertions with bounded
state waits and allowed cold AX toggle latency. Corrected4-case run in progress.
Six original/licensed fixtures were added only to owned All28 QA (existing5
records preserved); backup/hashes under build/Build33. Next verify corrected
behavior, run the9 core integration scenarios, then signed33/source packaging.

Final experience checks: console Home/favorite/filter/sort, PS1/GC/3DS Duo
portrait/landscape/drag/replay, GC actual EFB2×1280×1056,4×2560×2112 and1×640×528,
and PS1 actual640×480/320×240 with new persisted graphics controls all pass.
Full13 run passed12; the switching test correctly hit the unavailable Apple
regional age service while trying imported QA copies. Preserved its failure and
raw result. Temporarily hid only six QA fixture records (not files or existing
records), restored the original bundled-demo path, and reran that exact switching
case: passed84.256s for GC→PS1→3DS. App/native input digests and the Debug app
executable stayed identical through this test-only rebuild. Both actual bundles
are retained; validation uses result timestamps and requires every latest case
to pass. Older builds keep their all-pass-bundles rule. Four guard regression
checks prevent accepting a later failure, missing required case or silently
changing old policy. No runtime/age-gate bypass was introduced.

All13 distinct latest native cases and104 domain tests (one private skip) pass.
Exact input/core/source/resource/symbol gate passes. Signed33 archive and source
packaging are next. No binary upload, public release or automation restart.

Signed arm64 development archive33 succeeded. Local archive validation passes:
four Device framework deployment/version/platform metadata, all signatures,
six real matching dSYMs, widget identity/capabilities, privacy/notices/resources,
exact GZD profile and native evidence/source/core gates. Organizer33 registered
under November15. Every older signed/source artifact remains preserved. Six QA
fixture records restored without deleting files or existing records; owned QA
Simulator shut down. No owner phone/ROM/save access or export/upload. Next exact
source package and external delivery receipt; all101 compiled/build inputs frozen.

Delivery complete: signed0.1.0(33) registered in Xcode Archives and preserved
with exact matching source:344 files, 203067134 bytes, SHA256
7ff395ab1928b5101f4a63b43911f44bfbc3eda9c2b6e455631413fea3654ec1.
All101 frozen inputs and four core hashes still match. External receipt under
build/Build33-Distribution; four unchanged actual UI screenshots under
build/Build33/Previews. No active build, binary export/upload, owner phone access,
public submission or automation restart. Physical Duo/controller/fold behavior
and higher-resolution phone performance remain owner checks. Godzilla is still
unresolved. This post-package addendum modifies no frozen compiled input.
