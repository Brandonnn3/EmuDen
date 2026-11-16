# Build27 — owner player fixes and3DS motion

Active checkout `/Volumes/SamsungT7/EmuDenPS1Polish27`, branch
`ps1-polish-build27`, based on preserved25 implementation e05b515.
3DS and PS1 only. GameCube26 research remains isolated and unfinished.
The owner reports testing25 on the phone; old pending-upload assumptions do
not override that report. The signed local development archive is validated; matching source packaging
is the final local preparation step. No27 upload or public submission exists.
Public release remains held. Only owned QA Simulators were used, never B Duo,
owner phones, or owner games/saves/system data.

## Implemented and verified

- Portrait cover tiles use0.71 width/height in both orientations. Shared image
  drawing preserves aspect;3DS case strips are cropped without altering source
  bytes. Catalog selection/cache/portrait priority and artwork URLs stay intact.
- Pinned PCSX NEON enhanced rendering is selectable at1x/2x, initially and live.
  Actual homebrew framebuffers change320x240 ->640x480 ->320x240. Most2D/high-
  resolution modes retain original detail. No resolution speed hack or JIT.
- PS1 playback1x/1.5x/2x uses real core pacing and public AVAudioUnitVarispeed;
  audio pitch rises. Each new session begins at1x.
- Active system fold divisions place PS1 video above/beside the fold with
  optional speed, FPS, quick saves and touch controls in the other panel.
  All four off leaves a blank panel and survives relaunch. Controllers hide
  touch controls; flat landscape controller play still fills the display.
- CoreMotion supplies3DS gyroscope and gravity-inclusive acceleration at60Hz.
  Motion was previously forced off and no libretro sensor interface existed.
  New callbacks preserve g/radians units and pinned Azahar's orientation axes,
  validate/clamp samples and neutralize/stop on pause/background/close.
  Motion defaults on; global/per-game switches and usage-purpose text are added.
  Samples stay transient/local. PS1 does not start sensor sampling.
- Old per-game3DS profile values migrate intact with defaults for new fields.

## Current evidence

All under `build/Build27` unless noted:

- `domain-motion-tests.log`:102 tests, one private-resource skip, zero failures.
- `tooling-final.log`:7 tooling checks pass, including MotionInput C++ checks.
- `host-ps1-render.log`: actual resolution1/2/1, input, audio, state and native
  memory-card write/reopen pass on the original demo.
- `Native-27-1.xcresult`: native1/2/1 resolution passes49.308seconds; Duo outer-
  display portrait geometry passes. This is not an inner-display pose check.
- `Native-27-2.xcresult`: real3DS core requests both sensor channels; pause/
  resume gates MotionQA3 ->1 ->3 (30.458seconds). Flat PS1 controller landscape
  and touch side-space pass82.938/42.027seconds.
- `PS1-Fold-Persistence.xcresult`: fold/speed/blank/relaunch passes84.634seconds,
  including actual1.5x/2x/1x core-rate thresholds and persisted blank settings.
- `Native-Screen-Posters-Switching.xcresult`: both tests pass137.780seconds total.
  Full portrait cover geometry in actual portrait/landscape passes23.153seconds;
  PS1 history/resume ->3DS ->PS1 passes114.627seconds. Final full-screen captures
  are exported under Final-Native-Screenshots and visually checked. Landscape
  covers are DFA4F28B-2499-4E68-AB92-CBA9EC3B0092.png.
- `device-current.log`: current-source unsigned Release arm64 iOS build passes,
  including the actual device CoreMotion branch. GameCube is not embedded.
- `license-source-check.json`:24 declared license-source hashes verified;
 95 complete offline notices are unchanged. `metadata-final-validation.log`
  passes the strict local metadata/privacy draft checks.

Simulator's --motion-interface-test supplies bounded synthetic samples only;
it is excluded from device builds. It proves the actual core interface and
pause lifecycle, not physical gyro calibration or WarioWare gameplay. Those
remain phone checks, together with real Duo bend/inner-display behavior,
retail-game2x performance/audio and signed regional age-service/widget behavior.

## Exact previous failures, preserved

PS1-Resolution.xcresult initially tapped a disabled per-game setting without
turning Customize on; corrected setup passes. Native-27-1's fold rotation check
ran on Duo's outer display; regular-phone rotation passes. The old segmented
speed picker intermittently missed short taps (diagnostic Speed1.0); explicit
48-point buttons pass actual pacing. Fold-settings attempts used incorrect
scroll/switch coordinates; helpers now target playerSettingsScroll and the
standard switch activation point. Their original result bundles remain intact.

PS1-3DS-Regression.xcresult used the empty-library demo button in a populated
staged library. It now opens the real Settings help/demo action. The first
Final-Posters-Switching.xcresult exposed test screenshot cropping in landscape:
XCUIApplication's capture cut the rotated window, while direct simctl output
was correct. Helpers now use XCUIScreen; the same save/platform check passes.
Landscape cover checks wait for orientation and scroll the row into view.
No production renderer was changed to satisfy the screenshot issue.

The first device attempt failed with internal-disk ENOSPC. Task-only fresh QA
5B84C606 was backed up/retired; unrelated caches/owner files were preserved.
Existing Xcode/ModuleCache caches were relocated intact to SSD and original
paths symlinked; see cache-relocation.json. Current device build now passes.

## Preservation and next step

All78 frozen25 inputs and its source SHA
659c775c115e1c8cb96acd9d02760aed07f1abe36ad89d07e386a3c88fd1ceb5 remain unchanged
(build25-preservation.json). All older releases/artwork remain preserved.
QA24173E09 and67C8F120 metadata/artwork/settings were restored from their
before-backups and shut down; qa-restoration.json records original library
hashes. Only four known512-byte non-executable metadata fixtures were moved
out of QA Games after byte comparison. Original game/save directories were
preserved. Test-after metadata and fixtures are backed up on SSD.

Compiled inputs are frozen at1e44a9d (80 app/resource inputs). The signed
archive is build/TestFlight/EmuDen-0.1.0-27.xcarchive. Cached development
signing succeeds without opening accounts or changing signing credentials.
The strict archive validator passes app/widget identity, all five genuine
matching dSYMs, signatures,95 notices, optional-artwork scope and resource/
private-data guards; see development-archive.log.

Next: package exact portable source and write its external SHA256 receipt
under build/Build27-Distribution. Docs/BUILD-27-INPUTS.json records frozen
compiled inputs and preserved raw core hashes.
Do not export/upload27, retry unchanged signing failures, ask again for unlock,
create accounts, accept agreements or publish anything. Never weaken archive/
source/resource guards. Once independent27 preparation is exhausted, resume26
from its own checkpoint; do not copy unfinished GameCube code into27.

Apple primary documentation checked14November2026:
https://developer.apple.com/documentation/coremotion/cmdevicemotion/gravity
https://developer.apple.com/documentation/coremotion/cmdevicemotion/useracceleration
https://developer.apple.com/documentation/coremotion/cmdevicemotion/rotationrate
https://developer.apple.com/documentation/bundleresources/information-property-list/nsmotionusagedescription
Pinned Azahar input_factory.cpp consumes g/radians and converts gyro to degrees
once; ndk_motion.cpp provides the orientation transform. This engineering
record is not legal clearance, Apple acceptance or phone performance evidence.

## Final delivery checkpoint —14November2026

The local candidate is complete and frozen. Source packaging succeeds:
`build/TestFlight/EmuDen-0.1.0-27-source.tar.gz`,286 files,153546165 bytes,
SHA2567a265332571328dcc0f1ece7ef17f599c0b1897ba2cf2ecb3a06d573ea1000fe,
source-tree commit c9c2c27. All80 frozen compiled inputs match both the current
checkout and tar members. The80-input manifest and preserved core hashes are
inside the package. No private contacts, build/QA files or owner data are
included. Build25's78 inputs and exact source SHA were reverified unchanged.
The signed27 archive is registered with Organizer through a new link under
Xcode/Archives/2026-11-14; older archives remain untouched.

`build/Build27-Distribution/distribution.json` is the external hash/delivery
receipt. This post-packaging addendum is a delivery record, not a change to the
frozen package or compiled source. No27 export, upload or public submission
occurred. No physical phone, gyro/WarioWare or actual Duo-fold test occurred.
Those remain owner testing, together with signed regional services/widgets
and retail-game resolution/audio behavior. Do not silently mark them passed.

The existing hourly continuation task is updated to preserve27 and25, avoid
repeating completed checks and resume the separate26 GameCube checkpoint.
No builds/tests remain active. The next independent development work is26's
actual player Main Stick/C-stick/partial-trigger, GX and native-card evidence;
keep its menus/archive blocked and full-clean-core/source-package gates intact.
