# Build34 — graphics, touch controls and console presentation

A new isolated controls-settings-build34 worktree from complete preserved33.
All prior signed/source releases, owner data, artwork/catalog URLs and automation
state are preserved. This is a local three-console candidate, with public release
held and no binary upload. The four core binaries and genuine symbols are exact33.

“Player settings” is renamed “Graphics settings.” Settings retains bento cards but
separates Graphics & display, Controls & Duo, Appearance, Console setup, Library &
artwork, and Privacy & access. Graphics settings selects the console for app
defaults and separates Graphics, Controls, and Saves & system; existing per-game
profiles still override app defaults. Mii imports/profile pictures, widget and
sound settings remain available.

PS1/GameCube Duo previews use original solid SceneKit meshes: rounded extruded
housings, raised shoulder controls, colored face buttons, stemmed analog sticks,
physical depth, lighting and responsive drag tilt. Existing spring connection,
replay and Reduce Motion behavior remain. The tiny header glyph remains light;
3DS keeps its clamshell opening. No external models/dependencies are downloaded.

Touch controls use one fixed canvas, with independent UIKit touch ownership per
button/stick. Folded quick settings scroll separately; controls never belong to
that scroll view. A stick retains its touch outside its border, clamps radially
and releases to neutral. GC uses large green A, small red B, gray X/Y, purple Z,
yellow C-stick and the correct asymmetric arrangement. PS1 has two genuine sticks;
Analog controller in Controls selects the pinned core’s dual-analog port/mode and
polls left/right axes separately. The original digital-controller default remains;
in digital mode the left stick maps to D-pad. Pause/disconnect clear both sticks.
Physical controller stick clicks map to PS1 L3/R3.

Game menu → More → Customize controls pauses play. Every touch button and stick
can move independently, with bounds preserving the full hit target. Positions
are normalized and stored separately for3 consoles ×4 flat/folded orientations.
Done resumes the previous pause state; Reset affects only the current layout.
Storage rejects invalid keys, nonfinite/out-of-range positions and oversized data.
The3DS touch screen remains available outside the control targets.

GameCube now has a bundled original unbranded studio background, generated once
with the built-in image_gen tool. The unchanged master, exact prompt and provenance
are in Docs/Design/Build34-Console-Art; ASSET-REGISTER-34 retains all12 earlier hashes
and adds this13th asset. No game-cover expansion, remote provider/catalog/publication
or audience change. Shared scenes/settings/widgets choose the actual game console
instead of falling back to3DS for GC.

Long-press any cover → Delete game presents explicit Cancel/destructive confirmation.
Only the canonical imported asset (including PS1 companion tracks/GC folder) and
library entry are removed. Original Files, saves, snapshots and saved artwork stay.
The operation stages the copy, writes metadata atomically and restores the copy if
metadata fails; shared assets still referenced by another entry are retained.
Saves are preserved but a later import may receive a different game identifier.

110 domain tests pass, with one existing private-resource skip. 19 distinct latest native/UI checks pass, including actual both-stick callbacks,
fixed folded input, edit/restart/rotation, confirmed deletion, graphics/card/disc
and3-console switching. Actual bundles, failed attempts/corrections, staged exact
source hashes and archive checks are recorded in BUILD-34-PROGRESS.md,
VERIFICATION.json, NATIVE-STAGES.json and INPUTS.json.
Only generated original/licensed homebrew and an owned QA Simulator are used. Real
Duo folding, simultaneous phone touches, gyro and device performance remain owner
checks. Existing Godzilla freeze is unresolved; this build changes no game-specific
compatibility profile or core renderer. Engineering checks do not establish broad
retail compatibility, Apple processing, legal clearance or public release approval.
