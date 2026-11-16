# Build34 — controls, settings and console presentation

Isolated EmuDenControls34 / controls-settings-build34 from c9e6bf4. Preserve33
signed archive and source SHA7ff395ab1928b5101f4a63b43911f44bfbc3eda9c2b6e455631413fea3654ec1
and every older release/source/artwork/owner file. No active builds at start.

Owner scope: rename Player settings→Graphics settings; clearer bento settings;
original solid3D PS1/GC controller previews; fix folded/portrait drag capture,
correct colored/proportioned GC touch controls, add functional PS1 sticks;
movable controls for all consoles; GC default background; confirmed delete-game
option. No owner files/phone use or binary upload, public release, JIT/private
brokers/proprietary downloads/automation. New background explicitly authorized;
no game-cover expansion or public URL/audience change.

Root cause inspected: playStationFolded embeds all controls inside ScrollView;
SwiftUI pan cancellation competes with UIKit immediate touch surfaces. Need
fixed control canvas and per-touch ownership, bounded persisted editing. PS1
core supports DualShock port selection/right analog; current bridge only reads
left axes and mirrors PS1 left stick to digital D-pad. Preserve digital default.
Next implement fixes,3D presentation, settings organization, safe app-copy
removal, native/domain tests, signed34 archive and exact source.

Implementation checkpoint: fixed control canvas replaces the legacy control stacks
and removes touch input from the folded quick-settings ScrollView. UIKit targets
own each touch outside bounds; layout editing pauses/releases input and stores
bounded normalized positions by3 consoles ×4 poses. GC colored/proportioned A/B/X/Y/Z,
main/C sticks; PS1 genuine dual-stick callback + pinned exported port/analog-mode
functions, digital default/backward profiles preserved. Pause/disconnect clear
both axes. SceneKit procedural solid controllers keep the tiny header glyph and
existing3DS opening; original GC console background renderer is under native QA.
Settings grouped and console/category graphics page; confirmed delete stages only
canonical imported assets, atomically updates metadata, preserves original Files,
saves/snapshots/artwork and shared assets. Metadata updated34, cores remain exact33.

Domain:109 tests, zero failures, existing private-resource skip (domain-2.log).
Simulator compile1 failed SCNShape.chamferSegmentCount (removed nonexistent member),
compile3 failed XCUICoordinate/element test overload (corrected to coordinate drag).
Compile4/5 build-for-testing pass; actual presentation/settings/delete QA currently
running in build/Build34/presentation-1.xcresult/log. No owner-device or ROM access.
Four new required native cases added; all latest failures must be corrected before
archive. No signed34 archive yet. Preserved33 static archives reused via local
build/Build33-Core symlink for exact core audit, not claimed as a fresh34 rebuild.

Presentation-1: console-specific previews pass67.812s. Settings/GC background
opened and delete confirmation appeared; cancel test failed because Apple's
popover-style confirmationDialog omits a visible Cancel in this presentation.
Use explicit destructive Alert with Cancel so dismissal is clear on every size.
Visual review also caught small/overlit/faceted controller bodies. Fix housing
Bezier tessellation by modeling at100× then scaling the solid mesh, increase
camera framing and lower lighting. Retain both the actual failure and rerun.

Controls-1: updated smooth solid preview case passes57.847s. First native touch
lookups failed because SwiftUI propagated an outer container identifier to every
control (actual AX hierarchy confirms ps1QuickPanel on all leaves). Add explicit
accessibility containment; keep per-control identities. Alert Cancel now passes;
confirm test hit duplicate SwiftUI/native Alert nodes, corrected to firstMatch.
110 domain tests now pass (one existing private-resource skip), including staged
import rollback when atomic metadata writes fail. No owner data used/deleted.

Owner-requested missing default GC background generated once with built-in image_gen,
visually inspected and saved unchanged to Resources/CinematicArt/Console-gamecube.png
and Docs/Design/Build34-Console-Art/Console-gamecube-master.png. Exact prompt/provenance
and asset register34 retain all12 previous asset hashes. No API fallback, custom
game cover, provider/catalog/publication. Earlier procedural scene is unselected QA
prototype only; its unused runtime renderer/export flag removed. Interactive
controllers stay code-native3D. Recompile8 and rerun actual touch/settings cases next.

Compile9 is the current app/test binary with bundled generated GC scene and shared
CinematicScene/widget console selection corrected. Artwork source check passes13
hashes; metadata/privacy/export drafts validate, source diff has no whitespace
errors. Controls-2 is running actual four new native scenarios. Initial GC direct
stick excursion and neutral SI check plus A press/release now pass; layout drag
and relaunch sequence is in progress. All earlier failed bundles remain preserved.
Core-reuse-audit separately verifies exact preserved33 source/static archives,
Device/Simulator binary metadata and real matching symbols; no new core build claim.

Controls-2: native GC fixed-panel excursion/neutral/A and saved-layout/restart/Reset
pass90.665s; actual PS1 both-axis callbacks/neutral/mode switch pass54.783s;
organized settings/background/Cancel/confirmed delete pass33.172s. Actual copied
ROM/metadata removed while original SHA and native-save marker plus all6 other QA
records remain intact (delete-after-native.json).3DS drag/press/relaunch passed,
but its immediate post-rotation AX frame was transiently negative0.23s after
rotation. Test now waits up to10s for settled in-display saved portrait geometry
and resets this QA layout initially so previous failed edits cannot bias defaults.
Final review tightened touch cancellation to release only the owned UITouch and
avoids clearing a connected physical controller’s axes merely on rotation. Recompile
and revalidate affected touch cases plus existing playback/graphics/controller
and3DS motion cases before archive. Recreated only the disposable original QA
import for the final Delete rerun; its source/save markers remain unchanged.

Final visual review of actual folded-control screenshot showed a small A/X target
overlap. Stop the owned native-final run before distribution, retain its log/bundle
and completed results; improve default GC A/B/X spacing so face targets are separate,
and assert nonoverlap in the actual folded UI. Layout JSON is now decoded once per
body, instead of once per target. No core/save/source/provider scope changes.
Native-final had passed navigation,3D previews, full physical-controller inputs,
folded sticks/edit persistence and GCM import/state before the deliberate stop.
Compile11 then rerun final native cases with the final app/bridge source; older
failures and intentional interruption remain recorded, not called a clean pass.

Native-final2 completed18 cases:17 pass, one GC-settings return helper races the
asynchronous Resume chime/dismissal (settings assertions themselves pass). Correct
the test helper to wait for a closing menu to disappear, or a persistent menu's
back button to become enabled/hittable.3DS movement/restart/rotation/Reset passes
60.336s;3DS sensor request/pause/resume27.273s; PS1 actual resolution changes77.759s
and folded1/1.5/2×/blank89.887s pass. All remaining GC render/card/disc/state/
controller/landscape cases pass. Full actual logs/results retained.

Final narrowly scoped runtime correction: PS1 Customize controls temporarily shows
hidden folded touch controls while editing, restoring the user's hidden preference
on Done. Only App/PlayerView.swift changes one boolean expression from compile11;
new native PS1 case checks this exact edge plus both sticks/mode/release. Test-only
helper/setup changes accompany it. Recompile12, rerun affected PS1 customization
and GC settings plus final GC→PS1→3DS teardown. Other17 compile11 native passes remain
relevant; compile11-inputs.json records exact source and debug binary hashes. Native
stage hashes/delta will accompany the final corresponding-source verification.

Final compile12 native3: GC settings55.866s, actual GC→PS1→3DS83.397s and PS1
both-stick/neutral/mode plus hidden-panel editor/restore91.432s all pass. Combined
history has19 distinct latest passes (earlier failures preserved). Actual summary
finish times select latest results; no guard weakened. BUILD-34-NATIVE-STAGES.json
records compile11/12 source/executable hashes and exact one-expression runtime
delta with relevant renewed validation.110 domain checks (1 private-resource skip)
and4 native-evidence guard tests pass. Device Release unsigned build passes.

All6 original/licensed QA metadata rows restored after demo switching, every source
fixture file and save retained, disposable imported copy alone deleted. Its original
SHA and native-save marker remain intact. Source/core/metadata/real-symbol checks
and13 bundled asset hashes pass. No binary upload, public release, owner-phone use
or automation. Next freeze inputs, sign local34 archive, validate, package exact
portable source, add Organizer entry and shut down only the owned QA Simulator.

DELIVERY COMPLETE — signed local0.1.0(34) archive:
/Volumes/SamsungT7/EmuDenControls34/build/TestFlight/EmuDen-0.1.0-34.xcarchive
Organizer symlink: /Users/brandonaleman/Library/Developer/Xcode/Archives/2026-11-15/EmuDen0.1.0(34).xcarchive
Deep strict signatures, app/widget capabilities/profiles, all4 Device frameworks,
MinimumOSVersion18.0 metadata,6 genuine matching app/widget/core dSYMs, original
allowed homebrew payloads,148 offline notices and13 asset hashes pass. Actual
candidate gate preserves failures and requires19 latest native passes. No upload,
exported IPA or public submission performed; public release stays held.

Exact portable source: /Volumes/SamsungT7/EmuDenControls34/build/TestFlight/EmuDen-0.1.0-34-source.tar.gz
SHA256 b2aaebd585d19d9e684ac083cba957cbe817e1092bba5212e58ba6b08d952987
361 regular files /206272549 bytes. Every126 frozen input was checked inside the
actual tar,4 Device core hashes match33, no private contact/signing/owner data/build
tree or symlink dependency. Implementation3ed36f5; freeze9ced066. The immutable source
package captures the pre-delivery progress snapshot; this post-package receipt is
separate, with no compiled/frozen input changed. Final actual screenshots inspected:
final-gamecube-duo.png, final-gamecube-controls.png, final-ps1-controls.png under
build/Build34. All6 QA fixture entries restored, sources/saves retained. Owned QA
Simulator is being shut down; no task build/test process remains. Automation was
already deleted and remains off. Owner checks: physical Duo fold/simultaneous
phone touches, real gyro/performance/retail compatibility and any future TestFlight
export/upload. No further work or automatic continuation scheduled.
